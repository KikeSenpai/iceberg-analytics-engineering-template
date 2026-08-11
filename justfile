# Install Python dependencies
setup:
    uv sync

# Start all infrastructure services
infra-up:
    docker compose -f infra/docker-compose.yml up -d --wait

# Stop infrastructure services
down:
    docker compose -f infra/docker-compose.yml down

# Stop and remove volumes (destructive)
clean:
    docker compose -f infra/docker-compose.yml down -v

# Show infrastructure status
status:
    docker compose -f infra/docker-compose.yml ps

# Tail infrastructure logs
logs:
    docker compose -f infra/docker-compose.yml logs -f --tail=100

# Validate docker-compose config
compose-check:
    docker compose -f infra/docker-compose.yml config --quiet

# Apply SQLMesh plan (interactive)
plan:
    sqlmesh plan

# Apply SQLMesh plan (non-interactive)
plan-auto:
    sqlmesh plan --auto

# Run SQLMesh models
run:
    sqlmesh run

# Run SQLMesh tests
test:
    sqlmesh test

# Fetch query result as dataframe
fetch sql:
    sqlmesh fetchdf "{{sql}}"

# Start SQLMesh UI
ui:
    sqlmesh ui

# Lint SQL models (SQLMesh built-in linter)
lint:
    sqlmesh lint

# Format SQL models
format:
    sqlmesh format

# Full stack verification
verify:
    #!/bin/bash
    set -euo pipefail
    echo "=== Static checks ==="
    sqlmesh lint
    docker compose -f infra/docker-compose.yml config --quiet
    echo "=== Starting infrastructure ==="
    docker compose -f infra/docker-compose.yml up -d --wait
    echo "=== Trino connectivity ==="
    curl -s http://localhost:8080/v1/status >/dev/null && echo "Trino: OK" || { echo "Trino: FAIL"; exit 1; }
    curl -s http://localhost:8181/health >/dev/null && echo "Lakekeeper: OK" || { echo "Lakekeeper: FAIL"; exit 1; }
    echo "=== SQLMesh plan ==="
    sqlmesh plan --auto
    echo "=== SQLMesh run ==="
    sqlmesh run
    echo "=== SQLMesh test ==="
    sqlmesh test
    echo "=== Query verification ==="
    sqlmesh fetchdf "SELECT COUNT(*) AS completed_orders FROM staging.stg_orders"
    echo "=== Teardown ==="
    docker compose -f infra/docker-compose.yml down -v

# Smoke test — query Trino directly via trino CLI
smoke:
    #!/bin/bash
    set -euo pipefail
    docker exec -it $(docker compose -f infra/docker-compose.yml ps -q trino) trino --catalog iceberg --execute "SHOW SCHEMAS"
