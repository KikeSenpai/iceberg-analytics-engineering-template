# Install Python dependencies
setup:
    uv sync

# Start all infrastructure services and wait for healthchecks
infra-up:
    docker compose -f infra/docker-compose.yml up -d --wait

# Stop infrastructure services (keeps volumes)
down:
    docker compose -f infra/docker-compose.yml down

# Stop and remove volumes (destructive — wipes all data)
clean:
    docker compose -f infra/docker-compose.yml down -v
    rm -f sqlmesh_state.db sqlmesh_state.db.wal

# Show infrastructure status
status:
    docker compose -f infra/docker-compose.yml ps -a

# Tail infrastructure logs
logs:
    docker compose -f infra/docker-compose.yml logs -f --tail=100

# Validate docker-compose config
compose-check:
    docker compose -f infra/docker-compose.yml config --quiet

# Check Trino and Lakekeeper health endpoints
health:
    #!/bin/bash
    set -euo pipefail
    curl -sf http://localhost:8080/v1/status >/dev/null && echo "Trino: OK" || echo "Trino: FAIL"
    curl -sf http://localhost:8181/health >/dev/null && echo "Lakekeeper: OK" || echo "Lakekeeper: FAIL"

# Wait for Trino to be fully ready to serve queries
trino-wait:
    #!/bin/bash
    set -euo pipefail
    echo "Waiting for Trino to be ready..."
    for i in $(seq 1 30); do
        if docker compose -f infra/docker-compose.yml exec -T trino \
            trino --execute "SELECT 1" --user sqlmesh >/dev/null 2>&1; then
            echo "Trino ready"
            exit 0
        fi
        sleep 2
    done
    echo "Trino not ready after 60s"
    exit 1

# Load CSV files from data/ into prod.raw tables (requires running infrastructure)
load-raw:
    uv run python scripts/load_raw.py

# Run unit tests for the raw loader
test-load-raw:
    uv run python scripts/test_load_raw.py

# Apply SQLMesh plan (interactive — prompts for backfill start date)
plan:
    uv run sqlmesh plan

# Apply SQLMesh plan (non-interactive — auto-apply, no prompts)
plan-auto:
    uv run sqlmesh plan --auto-apply

# Run SQLMesh models (execute missing intervals)
run:
    uv run sqlmesh run

# Run SQLMesh unit tests
test:
    uv run sqlmesh test

# Lint SQL models (SQLMesh built-in linter)
lint:
    uv run sqlmesh lint

# Format SQL models
format:
    uv run sqlmesh format

# Fetch query result as dataframe via SQLMesh
fetch sql:
    uv run sqlmesh fetchdf "{{sql}}"

# Query Trino directly via trino CLI (non-interactive)
trino-query sql:
    #!/bin/bash
    set -euo pipefail
    container=$(docker compose -f infra/docker-compose.yml ps -q trino)
    docker exec "$container" trino --catalog prod --execute "{{sql}}" --user sqlmesh

# Open interactive Trino CLI shell
trino-shell:
    #!/bin/bash
    set -euo pipefail
    container=$(docker compose -f infra/docker-compose.yml ps -q trino)
    docker exec -it "$container" trino --catalog prod --user sqlmesh

# Start SQLMesh browser UI
ui:
    uv run sqlmesh ui

# Render the DAG as an HTML file
dag:
    uv run sqlmesh dag

# Full stack verification — static checks + infra + raw load + SQLMesh + query + teardown
verify:
    #!/bin/bash
    set -euo pipefail
    echo "=== Static checks ==="
    uv run sqlmesh lint
    docker compose -f infra/docker-compose.yml config --quiet
    echo "=== Starting infrastructure ==="
    docker compose -f infra/docker-compose.yml up -d --wait
    echo "=== Wait for Trino readiness ==="
    just trino-wait
    echo "=== Health checks ==="
    curl -sf http://localhost:8080/v1/status >/dev/null && echo "Trino: OK" || { echo "Trino: FAIL"; exit 1; }
    curl -sf http://localhost:8181/health >/dev/null && echo "Lakekeeper: OK" || { echo "Lakekeeper: FAIL"; exit 1; }
    echo "=== Raw data loading ==="
    if ls data/*.csv >/dev/null 2>&1; then
        just load-raw
    else
        echo "No CSV files in data/ — skipping raw loading"
    fi
    echo "=== SQLMesh plan ==="
    uv run sqlmesh plan --auto-apply
    echo "=== SQLMesh run ==="
    uv run sqlmesh run
    echo "=== SQLMesh test ==="
    uv run sqlmesh test
    echo "=== Query verification ==="
    just smoke
    uv run sqlmesh fetchdf "SELECT COUNT(*) AS report_rows FROM analytics.rep_sales_funnel_monthly"
    echo "=== Teardown ==="
    docker compose -f infra/docker-compose.yml down -v
    rm -f sqlmesh_state.db sqlmesh_state.db.wal

# Quick smoke test — show schemas and tables via Trino CLI
smoke:
    #!/bin/bash
    set -euo pipefail
    container=$(docker compose -f infra/docker-compose.yml ps -q trino)
    echo "=== Schemas ==="
    docker exec "$container" trino --catalog prod --execute "SHOW SCHEMAS" --user sqlmesh
    echo "=== Tables in raw ==="
    docker exec "$container" trino --catalog prod --execute "SHOW TABLES FROM prod.raw" --user sqlmesh
    echo "=== Tables in staging ==="
    docker exec "$container" trino --catalog prod --execute "SHOW TABLES FROM prod.staging" --user sqlmesh

# ─── Orb-native (no Docker) ───────────────────────────────────────────────────

# Install all orb-native dependencies (JDK, Trino, MinIO, Lakekeeper, PostgreSQL)
orb-setup:
    bash .agents/setup

# Start all services natively (PostgreSQL → MinIO → Lakekeeper → Trino)
orb-up:
    scripts/orb-services.sh start

# Stop all native services
orb-down:
    scripts/orb-services.sh stop

# Show native service status
orb-status:
    scripts/orb-services.sh status

# Tail native service logs (optional service name: postgres|minio|lakekeeper|trino)
orb-logs service="trino":
    scripts/orb-services.sh logs {{service}}

# Health-check native services
orb-health:
    scripts/orb-services.sh health

# Stop and wipe all native data (destructive)
orb-clean:
    scripts/orb-services.sh clean

# Wait for native Trino to be ready
orb-trino-wait:
    scripts/orb-services.sh trino-wait

# Query native Trino via CLI
orb-trino-query sql:
    scripts/orb-services.sh trino-query "{{sql}}"

# Full orb-native verification — start → raw load → SQLMesh → query → teardown
verify-orb:
    #!/bin/bash
    set -euo pipefail
    export PATH="$HOME/.local/bin:$PATH"
    export JAVA_HOME="$HOME/.local/share/orb-native/jdk17"
    export PATH="$JAVA_HOME/bin:$PATH"
    ORB_SCRIPT="$(pwd)/scripts/orb-services.sh"

    _cleanup() {
        local rc=$?
        echo "=== Teardown (rc=$rc) ==="
        "$ORB_SCRIPT" clean
        rm -f sqlmesh_state.db sqlmesh_state.db.wal
        exit $rc
    }
    trap _cleanup EXIT INT TERM

    echo "=== Static checks ==="
    uv run sqlmesh lint
    just test-load-raw
    docker compose -f infra/docker-compose.yml config --quiet 2>/dev/null && echo "Compose config: OK" || echo "Compose config: skipped (Docker not available)"

    echo "=== Clean slate ==="
    "$ORB_SCRIPT" clean

    echo "=== Starting orb-native services ==="
    "$ORB_SCRIPT" start

    echo "=== Health checks ==="
    "$ORB_SCRIPT" health

    echo "=== Raw data loading ==="
    if ls data/*.csv >/dev/null 2>&1; then
        just load-raw
    else
        echo "No CSV files in data/ — skipping raw loading"
    fi

    echo "=== SQLMesh plan ==="
    uv run sqlmesh plan --auto-apply

    echo "=== SQLMesh run ==="
    uv run sqlmesh run

    echo "=== SQLMesh test ==="
    uv run sqlmesh test

    echo "=== Report contract and reconciliation ==="
    uv run sqlmesh fetchdf "SELECT MIN(month) AS first_month, MAX(month) AS last_month, COUNT(*) AS report_rows, COUNT(DISTINCT month) AS months FROM analytics.rep_sales_funnel_monthly"
    uv run sqlmesh fetchdf "SELECT funnel_step, kpi_name, SUM(deals_count) AS deals_count FROM analytics.rep_sales_funnel_monthly GROUP BY 1, 2 ORDER BY CASE funnel_step WHEN 'Step 1' THEN 1 WHEN 'Step 2' THEN 2 WHEN 'Step 2.1' THEN 3 WHEN 'Step 3' THEN 4 WHEN 'Step 3.1' THEN 5 WHEN 'Step 4' THEN 6 WHEN 'Step 5' THEN 7 WHEN 'Step 6' THEN 8 WHEN 'Step 7' THEN 9 WHEN 'Step 8' THEN 10 WHEN 'Step 9' THEN 11 END"
    uv run sqlmesh fetchdf "SELECT month, COUNT(*) AS step_rows FROM analytics.rep_sales_funnel_monthly GROUP BY 1 ORDER BY 1"
    uv run sqlmesh fetchdf "SELECT event_source, COUNT(*) AS event_count FROM intermediate.int_pipedrive__funnel_step_events GROUP BY 1 ORDER BY 1"
    uv run sqlmesh fetchdf "SELECT issue_type, COUNT(*) AS record_count FROM intermediate.int_pipedrive__unmapped_records GROUP BY 1 ORDER BY 1"

    echo "=== Smoke: schemas and tables ==="
    "$ORB_SCRIPT" trino-query "SHOW SCHEMAS FROM prod"
    "$ORB_SCRIPT" trino-query "SHOW TABLES FROM prod.raw"
    "$ORB_SCRIPT" trino-query "SHOW TABLES FROM prod.staging"
    "$ORB_SCRIPT" trino-query "DESCRIBE prod.analytics.rep_sales_funnel_monthly"

    echo "=== verify-orb passed ==="
