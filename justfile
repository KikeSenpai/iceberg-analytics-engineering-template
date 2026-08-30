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
    echo "=== Storage check: Iceberg Parquet files in MinIO ==="
    before=$(just minio-files | sort)
    echo "$before"
    [ -n "$before" ] || { echo "No Parquet files in MinIO"; exit 1; }
    echo "=== Persistence check: restart stack, keep volumes ==="
    docker compose -f infra/docker-compose.yml down
    docker compose -f infra/docker-compose.yml up -d --wait
    just trino-wait
    after=$(just minio-files | sort)
    [ "$before" = "$after" ] && echo "MinIO objects survived restart" || { echo "MinIO objects changed after restart"; exit 1; }
    just smoke
    uv run sqlmesh fetchdf "SELECT COUNT(*) AS report_rows FROM analytics.rep_sales_funnel_monthly"
    echo "=== Teardown ==="
    docker compose -f infra/docker-compose.yml down -v
    rm -f sqlmesh_state.db sqlmesh_state.db.wal

# List Iceberg Parquet data files physically stored in MinIO (bucket `warehouse`)
minio-files:
    @docker compose -f infra/docker-compose.yml exec -T minio sh -c 'mc alias set local http://localhost:9000 minio-root-user minio-root-password >/dev/null && mc find local/warehouse --name "*.parquet"'

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
