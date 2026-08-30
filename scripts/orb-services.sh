#!/usr/bin/env bash
set -euo pipefail

# Orb-native service manager for Iceberg analytics stack.
# Starts PostgreSQL, MinIO, Lakekeeper, and Trino as local processes — no Docker.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ORB_NATIVE_DIR="${ORB_NATIVE_DIR:-$HOME/.local/share/orb-native}"
PG_BIN="${PG_BIN:-/usr/lib/postgresql/15/bin}"
PGDATA="$ORB_NATIVE_DIR/pgdata"
MINIO_DATA="$ORB_NATIVE_DIR/minio-data"
LOGS_DIR="$ORB_NATIVE_DIR/logs"
PIDS_DIR="$ORB_NATIVE_DIR/pids"
TRINO_HOME="$ORB_NATIVE_DIR/trino"
LAKEKEEPER_HOME="$ORB_NATIVE_DIR/lakekeeper"
MINIO_BIN="$ORB_NATIVE_DIR/bin/minio"
MC_BIN="$ORB_NATIVE_DIR/bin/mc"
TRINO_CLI="$ORB_NATIVE_DIR/bin/trino"
JDK_HOME="$ORB_NATIVE_DIR/jdk17"

# Config values (must match docker-compose.yml semantics)
PG_PORT=5432
PG_USER=postgres
PG_PASSWORD=postgres
MINIO_PORT=9000
MINIO_CONSOLE_PORT=9001
MINIO_ROOT_USER=minio-root-user
MINIO_ROOT_PASSWORD=minio-root-password
MINIO_BUCKET=warehouse
LK_PORT=8181
LK_ENCRYPTION_KEY="This-is-NOT-Secure!"
TRINO_PORT=8080
TRINO_USER=sqlmesh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

log()  { printf "${GREEN}[orb]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[orb]${NC} %s\n" "$*"; }
err()  { printf "${RED}[orb]${NC} %s\n" "$*" >&2; }

# ─── Helpers ──────────────────────────────────────────────────────────────────

mkdir -p "$LOGS_DIR" "$PIDS_DIR"

pid_file()    { echo "$PIDS_DIR/$1.pid"; }
log_file()    { echo "$LOGS_DIR/$1.log"; }
pid_running() { local pid; pid=$(cat "$(pid_file "$1")" 2>/dev/null || echo ""); [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; }
write_pid()   { echo "$2" > "$(pid_file "$1")"; }
read_pid()    { cat "$(pid_file "$1")" 2>/dev/null || echo ""; }
rm_pid()      { rm -f "$(pid_file "$1")"; }

# Wait for a TCP port to accept connections (no fixed sleep)
wait_port() {
    local port="$1" timeout="${2:-60}" elapsed=0
    while ! nc -z localhost "$port" 2>/dev/null; do
        [ $elapsed -ge $timeout ] && return 1
        sleep 1; elapsed=$((elapsed + 1))
    done
    return 0
}

# Wait for an HTTP endpoint to return 200
wait_http() {
    local url="$1" timeout="${2:-60}" elapsed=0
    while ! curl -sf "$url" >/dev/null 2>&1; do
        [ $elapsed -ge $timeout ] && return 1
        sleep 1; elapsed=$((elapsed + 1))
    done
    return 0
}

# Check if a port is already in use
port_in_use() { nc -z localhost "$1" 2>/dev/null; }

# ─── PostgreSQL ───────────────────────────────────────────────────────────────

pg_start() {
    if pid_running postgres; then log "PostgreSQL already running (pid $(read_pid postgres))"; return 0; fi
    if port_in_use "$PG_PORT"; then err "Port $PG_PORT in use"; return 1; fi

    if [ ! -d "$PGDATA" ] || [ ! -s "$PGDATA/PG_VERSION" ]; then
        log "Initializing PostgreSQL data dir…"
        "$PG_BIN/initdb" -D "$PGDATA" -U "$PG_USER" --auth=trust --no-locale -E UTF8 >/dev/null 2>&1
        # Set listen_port and socket dir (avoid /var/run/postgresql permission issues)
        echo "listen_addresses = 'localhost'" >> "$PGDATA/postgresql.conf"
        echo "port = $PG_PORT" >> "$PGDATA/postgresql.conf"
        echo "unix_socket_directories = '$ORB_NATIVE_DIR'" >> "$PGDATA/postgresql.conf"
    fi

    log "Starting PostgreSQL…"
    "$PG_BIN/pg_ctl" -D "$PGDATA" -l "$(log_file postgres)" -w -t 30 start >/dev/null 2>&1
    local pg_pid; pg_pid=$(cat "$PGDATA/postmaster.pid" 2>/dev/null | head -1)
    write_pid postgres "$pg_pid"
    wait_port "$PG_PORT" 30 || { err "PostgreSQL not ready"; return 1; }
    log "PostgreSQL ready (pid $pg_pid, port $PG_PORT)"
}

pg_stop() {
    if ! pid_running postgres; then log "PostgreSQL not running"; rm_pid postgres; return 0; fi
    log "Stopping PostgreSQL…"
    "$PG_BIN/pg_ctl" -D "$PGDATA" -w -t 15 stop >/dev/null 2>&1 || kill "$(read_pid postgres)" 2>/dev/null || true
    rm_pid postgres
    log "PostgreSQL stopped"
}

# ─── MinIO ────────────────────────────────────────────────────────────────────

minio_start() {
    if pid_running minio; then log "MinIO already running (pid $(read_pid minio))"; return 0; fi
    if port_in_use "$MINIO_PORT"; then err "Port $MINIO_PORT in use"; return 1; fi

    mkdir -p "$MINIO_DATA"

    log "Starting MinIO…"
    MINIO_ROOT_USER="$MINIO_ROOT_USER" MINIO_ROOT_PASSWORD="$MINIO_ROOT_PASSWORD" \
        "$MINIO_BIN" server --address ":$MINIO_PORT" --console-address ":$MINIO_CONSOLE_PORT" \
        "$MINIO_DATA" > "$(log_file minio)" 2>&1 &
    local minio_pid=$!
    write_pid minio "$minio_pid"

    wait_http "http://localhost:$MINIO_PORT/minio/health/live" 30 || { err "MinIO not ready"; return 1; }

    # Create bucket
    "$MC_BIN" alias set orbminio "http://localhost:$MINIO_PORT" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null 2>&1
    "$MC_BIN" mb --ignore-existing "orbminio/$MINIO_BUCKET" >/dev/null 2>&1

    log "MinIO ready (pid $minio_pid, port $MINIO_PORT, bucket $MINIO_BUCKET created)"
}

minio_stop() {
    if ! pid_running minio; then log "MinIO not running"; rm_pid minio; return 0; fi
    log "Stopping MinIO…"
    kill "$(read_pid minio)" 2>/dev/null || true
    wait "$(read_pid minio)" 2>/dev/null || true
    rm_pid minio
    log "MinIO stopped"
}

# ─── Lakekeeper ───────────────────────────────────────────────────────────────

lk_env() {
    export LAKEKEEPER__PG_ENCRYPTION_KEY="$LK_ENCRYPTION_KEY"
    export LAKEKEEPER__PG_DATABASE_URL_READ="postgresql://${PG_USER}:${PG_PASSWORD}@localhost:${PG_PORT}/postgres"
    export LAKEKEEPER__PG_DATABASE_URL_WRITE="postgresql://${PG_USER}:${PG_PASSWORD}@localhost:${PG_PORT}/postgres"
    export LAKEKEEPER__METRICS_PORT="9100"
    export RUST_LOG="${RUST_LOG:-info}"
}

lk_migrate() {
    lk_env
    log "Running Lakekeeper migration…"
    "$LAKEKEEPER_HOME/lakekeeper" migrate > "$(log_file lakekeeper-migrate)" 2>&1
    log "Lakekeeper migration done"
}

lk_start() {
    if pid_running lakekeeper; then log "Lakekeeper already running (pid $(read_pid lakekeeper))"; return 0; fi
    if port_in_use "$LK_PORT"; then err "Port $LK_PORT in use"; return 1; fi

    lk_migrate

    log "Starting Lakekeeper…"
    lk_env
    "$LAKEKEEPER_HOME/lakekeeper" serve > "$(log_file lakekeeper)" 2>&1 &
    local lk_pid=$!
    write_pid lakekeeper "$lk_pid"

    wait_http "http://localhost:$LK_PORT/health" 60 || { err "Lakekeeper not ready"; return 1; }
    log "Lakekeeper ready (pid $lk_pid, port $LK_PORT)"
}

lk_stop() {
    if ! pid_running lakekeeper; then log "Lakekeeper not running"; rm_pid lakekeeper; return 0; fi
    log "Stopping Lakekeeper…"
    kill "$(read_pid lakekeeper)" 2>/dev/null || true
    wait "$(read_pid lakekeeper)" 2>/dev/null || true
    rm_pid lakekeeper
    log "Lakekeeper stopped"
}

lk_bootstrap() {
    log "Bootstrapping Lakekeeper (accept terms)…"
    local code
    code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "http://localhost:$LK_PORT/management/v1/bootstrap" \
        -H 'Content-Type: application/json' --data '{"accept-terms-of-use": true}' 2>/dev/null || echo "000")
    if [ "$code" = "200" ] || [ "$code" = "204" ] || [ "$code" = "409" ]; then
        log "Lakekeeper bootstrap done (HTTP $code)"
    else
        warn "Lakekeeper bootstrap returned HTTP $code (may already be bootstrapped)"
    fi
}

lk_create_warehouse() {
    log "Creating warehouse 'prod'…"
    # Generate warehouse payload with localhost endpoints (not Docker hostnames)
    local payload
    payload=$(cat <<JSON
{
  "warehouse-name": "prod",
  "project-id": "00000000-0000-0000-0000-000000000000",
  "storage-profile": {
    "type": "s3",
    "bucket": "$MINIO_BUCKET",
    "key-prefix": "",
    "assume-role-arn": null,
    "endpoint": "http://localhost:$MINIO_PORT",
    "region": "local-01",
    "path-style-access": true,
    "flavor": "minio",
    "sts-enabled": true
  },
  "storage-credential": {
    "type": "s3",
    "credential-type": "access-key",
    "access-key-id": "$MINIO_ROOT_USER",
    "secret-access-key": "$MINIO_ROOT_PASSWORD"
  }
}
JSON
)
    local code
    code=$(echo "$payload" | curl -s -o /dev/null -w '%{http_code}' -X POST "http://localhost:$LK_PORT/management/v1/warehouse" \
        -H 'Content-Type: application/json' --data @- 2>/dev/null || echo "000")
    if [ "$code" = "200" ] || [ "$code" = "201" ] || [ "$code" = "409" ]; then
        log "Warehouse 'prod' created (HTTP $code)"
    else
        warn "Warehouse creation returned HTTP $code (may already exist)"
    fi
}

# ─── Trino ────────────────────────────────────────────────────────────────────

trino_generate_config() {
    local etc_dir="$TRINO_HOME/etc"
    local catalog_dir="$etc_dir/catalog"
    mkdir -p "$catalog_dir"

    # config.properties — same as Docker plus dynamic catalog management
    cat > "$etc_dir/config.properties" << 'PROPS'
coordinator=true
node.environment=orbnative
http-server.http.port=8080
discovery.uri=http://localhost:8080
catalog.management=dynamic
PROPS

    # iceberg.properties — same as Docker but with localhost endpoints
    cat > "$catalog_dir/iceberg.properties" << PROPS
connector.name=iceberg
iceberg.catalog.type=rest
iceberg.rest-catalog.uri=http://localhost:$LK_PORT/catalog
iceberg.rest-catalog.warehouse=prod
iceberg.rest-catalog.nested-namespace-enabled=true
iceberg.unique-table-location=true
iceberg.rest-catalog.view-endpoints-enabled=true
iceberg.rest-catalog.vended-credentials-enabled=true
fs.native-s3.enabled=true
s3.endpoint=http://localhost:$MINIO_PORT
s3.region=local-01
s3.path-style-access=true
PROPS

    # JVM config — smaller memory for orb
    cat > "$etc_dir/jvm.config" << 'JVM'
-server
-Xmx1G
-XX:+UseG1GC
-XX:G1HeapRegionSize=32M
-XX:+ExplicitGCInvokesConcurrent
-XX:+ExitOnOutOfMemoryError
-XX:+HeapDumpOnOutOfMemoryError
-XX:-OmitStackTraceInFastThrow
-XX:ReservedCodeCacheSize=512M
-Djdk.attach.allowAttachSelf=true
-Djdk.nio.maxCachedBufferSize=2000000
-Dfile.encoding=UTF-8
-XX:+UnlockDiagnosticVMOptions
JVM
}

trino_start() {
    if pid_running trino; then log "Trino already running (pid $(read_pid trino))"; return 0; fi
    if port_in_use "$TRINO_PORT"; then err "Port $TRINO_PORT in use"; return 1; fi

    trino_generate_config

    export JAVA_HOME="$JDK_HOME"
    export PATH="$JDK_HOME/bin:$PATH"

    log "Starting Trino…"
    # Trino launcher creates its own PID file at data-dir/var/launcher.pid
    "$TRINO_HOME/bin/launcher" \
        --etc-dir "$TRINO_HOME/etc" \
        --data-dir "$ORB_NATIVE_DIR/trino-data" \
        --jvm-dir "$JDK_HOME" \
        start 2>>"$(log_file trino)"

    # Wait for Trino to serve actual SQL queries (not just HTTP health)
    local elapsed=0
    while [ $elapsed -lt 120 ]; do
        if "$TRINO_CLI" --server "http://localhost:$TRINO_PORT" --user "$TRINO_USER" --execute "SELECT 1" >/dev/null 2>&1; then
            # Read the launcher's PID file
            local tpid; tpid=$(cat "$ORB_NATIVE_DIR/trino-data/var/launcher.pid" 2>/dev/null || echo "")
            [ -n "$tpid" ] && write_pid trino "$tpid"
            log "Trino ready (port $TRINO_PORT)"
            return 0
        fi
        sleep 2; elapsed=$((elapsed + 2))
    done
    err "Trino not ready after 120s"
    return 1
}

trino_stop() {
    export JAVA_HOME="$JDK_HOME"
    export PATH="$JDK_HOME/bin:$PATH"

    # Try launcher stop first (uses its own PID file in data-dir/var/launcher.pid)
    if [ -f "$ORB_NATIVE_DIR/trino-data/var/launcher.pid" ]; then
        log "Stopping Trino via launcher…"
        "$TRINO_HOME/bin/launcher" \
            --etc-dir "$TRINO_HOME/etc" \
            --data-dir "$ORB_NATIVE_DIR/trino-data" \
            --jvm-dir "$JDK_HOME" \
            stop 2>/dev/null || true
    fi

    # Fallback: kill by our PID file
    if pid_running trino; then
        log "Killing Trino process $(read_pid trino)…"
        kill "$(read_pid trino)" 2>/dev/null || true
        sleep 3
        # Force kill if still alive
        if pid_running trino; then
            kill -9 "$(read_pid trino)" 2>/dev/null || true
            sleep 1
        fi
    fi

    # Last resort: kill anything listening on TRINO_PORT
    if port_in_use "$TRINO_PORT"; then
        local port_pid
        port_pid=$(lsof -ti :"$TRINO_PORT" 2>/dev/null || true)
        if [ -n "$port_pid" ]; then
            log "Force-killing process on port $TRINO_PORT (pid $port_pid)…"
            kill -9 "$port_pid" 2>/dev/null || true
            sleep 1
        fi
    fi

    rm_pid trino
    log "Trino stopped"
}

trino_query() {
    local sql="$1"
    export JAVA_HOME="$JDK_HOME"
    export PATH="$JDK_HOME/bin:$PATH"
    "$TRINO_CLI" --server "http://localhost:$TRINO_PORT" --user "$TRINO_USER" --catalog iceberg --execute "$sql"
}

# ─── Orchestration ────────────────────────────────────────────────────────────

start_all() {
    log "Starting orb-native services…"
    pg_start
    minio_start
    lk_start
    lk_bootstrap
    lk_create_warehouse
    trino_start
    log "All services started."
}

stop_all() {
    log "Stopping orb-native services…"
    trino_stop
    lk_stop
    minio_stop
    pg_stop
    log "All services stopped."
}

status_all() {
    # Also check Trino launcher PID file
    if [ -f "$ORB_NATIVE_DIR/trino-data/var/launcher.pid" ]; then
        local tpid; tpid=$(cat "$ORB_NATIVE_DIR/trino-data/var/launcher.pid" 2>/dev/null || echo "")
        if [ -n "$tpid" ] && kill -0 "$tpid" 2>/dev/null; then
            write_pid trino "$tpid"
        fi
    fi

    local all_ok=true
    for svc in postgres minio lakekeeper trino; do
        if pid_running "$svc"; then
            printf "  ${GREEN}%-14s${NC} running (pid %s)\n" "$svc" "$(read_pid "$svc")"
        else
            printf "  ${RED}%-14s${NC} stopped\n" "$svc"
            all_ok=false
        fi
    done
    # Also check ports
    for pair in "PostgreSQL:$PG_PORT" "MinIO:$MINIO_PORT" "Lakekeeper:$LK_PORT" "Trino:$TRINO_PORT"; do
        local name="${pair%%:*}" port="${pair##*:}"
        if nc -z localhost "$port" 2>/dev/null; then
            printf "  ${GREEN}%-14s${NC} port %s open\n" "$name" "$port"
        else
            printf "  ${RED}%-14s${NC} port %s closed\n" "$name" "$port"
        fi
    done
    $all_ok
}

health_all() {
    local rc=0
    curl -sf "http://localhost:$TRINO_PORT/v1/status" >/dev/null 2>&1 && echo "Trino: OK" || { echo "Trino: FAIL"; rc=1; }
    curl -sf "http://localhost:$LK_PORT/health" >/dev/null 2>&1 && echo "Lakekeeper: OK" || { echo "Lakekeeper: FAIL"; rc=1; }
    curl -sf "http://localhost:$MINIO_PORT/minio/health/live" >/dev/null 2>&1 && echo "MinIO: OK" || { echo "MinIO: FAIL"; rc=1; }
    "$PG_BIN/pg_isready" -h localhost -p "$PG_PORT" -U "$PG_USER" >/dev/null 2>&1 && echo "PostgreSQL: OK" || { echo "PostgreSQL: FAIL"; rc=1; }
    return $rc
}

clean_all() {
    stop_all 2>/dev/null || true
    log "Cleaning orb-native data…"
    rm -rf "$PGDATA" "$MINIO_DATA" "$ORB_NATIVE_DIR/trino-data"
    rm -f "$PIDS_DIR"/*.pid
    rm -f "$LOGS_DIR"/*.log
    # Remove SQLMesh state
    rm -f "$REPO_DIR/sqlmesh_state.db" "$REPO_DIR/sqlmesh_state.db.wal"
    log "Clean done."
}

# ─── Main ─────────────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Usage: $0 <command>

Commands:
  start          Start all services (PG → MinIO → Lakekeeper → Trino)
  stop           Stop all services (reverse order)
  restart        Stop then start
  status         Show service status (process + port)
  health         Check health endpoints
  logs [svc]     Tail logs (svc: postgres|minio|lakekeeper|trino)
  clean          Stop all and wipe data directories
  trino-query SQL  Run SQL via Trino CLI
  trino-wait     Wait until Trino serves SQL queries
EOF
}

case "${1:-}" in
    start)        start_all ;;
    stop)         stop_all ;;
    restart)      stop_all; start_all ;;
    status)       status_all ;;
    health)       health_all ;;
    logs)         tail -f "$LOGS_DIR/${2:-trino}.log" 2>/dev/null || err "No log for ${2:-trino}" ;;
    clean)        clean_all ;;
    trino-query)  shift; trino_query "$*" ;;
    trino-wait)
        export JAVA_HOME="$JDK_HOME"
        export PATH="$JDK_HOME/bin:$PATH"
        elapsed=0
        while [ $elapsed -lt 120 ]; do
            if "$TRINO_CLI" --server "http://localhost:$TRINO_PORT" --user "$TRINO_USER" --execute "SELECT 1" >/dev/null 2>&1; then
                echo "Trino ready"; exit 0
            fi
            sleep 2; elapsed=$((elapsed + 2))
        done
        echo "Trino not ready after 120s"; exit 1 ;;
    *)            usage; exit 1 ;;
esac
