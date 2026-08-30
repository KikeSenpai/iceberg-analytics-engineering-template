# Iceberg Analytics Engineering Template

## Tech Stack

- Query engine: Trino 476 (trinodb/trino, version-pinned)
- Table format: Apache Iceberg
- Catalog: Lakekeeper v0.12.4 (Iceberg REST Catalog)
- Storage: MinIO (S3-compatible, stands in for S3/ADLS)
- Transformations: SQLMesh (Trino adapter, DuckDB state)
- Python: UV for dependency management
- Linting: SQLMesh built-in linter
- CLI runner: just

## Testing Workflow

This repo supports two execution modes: **Docker** (local development) and **Orb-native** (Amp cloud sandbox, no Docker). All commands use `just`.

### Mode 1: Docker (local development)

Follow these steps when testing infra or model changes.

#### 1. Static checks (no infra needed)

```
just setup          # install Python deps (uv sync)
just lint           # SQLMesh built-in linter
just compose-check  # validate docker-compose.yml
```

#### 2. Start infrastructure

```
just infra-up       # start all 8 services, wait for healthchecks
just health         # verify Trino (:8080) and Lakekeeper (:8181) are up
just status         # show container status
```

Startup order (orchestrated by Compose depends_on):
1. Postgres starts (metadata store for Lakekeeper).
2. MinIO starts; createbuckets creates bucket `warehouse`.
3. Lakekeeper migrate runs (DB schema migration).
4. Lakekeeper server starts (REST catalog on :8181).
5. Bootstrap accepts terms-of-use.
6. Initialwarehouse creates warehouse `prod` (S3 bucket `warehouse`).
7. Trino starts (Iceberg connector → Lakekeeper REST catalog, S3 → MinIO).

One-shot containers (migrate, createbuckets, bootstrap, initialwarehouse) exit 0
when done. Four persistent services (db, minio, lakekeeper, trino) stay up.

#### 3. Apply SQLMesh plan

```
just plan-auto      # non-interactive: creates tables, loads seeds, builds models
```

Or interactive:
```
just plan           # prompts for backfill start date
```

#### 4. Verify data

```
just run            # execute missing intervals
just test           # run SQLMesh unit tests
just fetch "SELECT COUNT(*) FROM staging.stg_orders"
just smoke          # show schemas and tables via Trino CLI
just trino-query "SELECT * FROM iceberg.raw.orders LIMIT 5"
```

#### 5. Full stack verification (one command)

```
just verify
```

Runs the entire chain: lint → compose config → infra up → health check →
raw load → SQLMesh plan → SQLMesh run → SQLMesh test → smoke → teardown.

Use this after any infra or model change to confirm nothing broke.

#### 6. Teardown

```
just down           # stop services, keep volumes
just clean          # stop services, wipe volumes and SQLMesh state (destructive)
```

### Mode 2: Orb-native (Amp cloud sandbox — no Docker)

For Amp orbs that cannot run Docker, use the orb-native workflow. Services run
as native processes with PID files, readiness checks, and log management.

#### 1. Setup (installs all native dependencies)

```
just orb-setup      # installs JDK 24, Trino 476, MinIO, Lakekeeper, PostgreSQL, mc, trino CLI
```

Or run `.agents/setup` directly. This is idempotent — safe to re-run.

#### 2. Start infrastructure

```
just orb-up         # start PostgreSQL → MinIO → Lakekeeper → Trino as processes
just orb-health     # check all health endpoints
just orb-status     # show process and port status
```

The service manager script is `scripts/orb-services.sh`. It handles:
- PostgreSQL: initdb + pg_ctl (data in $ORB_NATIVE_DIR/pgdata)
- MinIO: binary server (data in $ORB_NATIVE_DIR/minio-data, bucket auto-created)
- Lakekeeper: migrate + serve (metadata in PostgreSQL, metrics on port 9100)
- Trino: launcher with generated config pointing to localhost
- Bootstrap and warehouse creation via curl API calls

#### 3. Apply SQLMesh plan (same commands as Docker)

```
just plan-auto      # creates tables, loads seeds, builds models
just run            # execute missing intervals
just test           # run SQLMesh unit tests
```

#### 4. Query and verify

```
just fetch "SELECT COUNT(*) FROM staging.stg_orders"
just orb-trino-query "SELECT * FROM iceberg.raw.orders LIMIT 5"
just orb-logs trino # tail Trino server logs
```

#### 5. Full stack verification (one command)

```
just verify-orb
```

Runs: lint → compose config check → clean → start native services → health checks →
raw load → SQLMesh plan → run → test → smoke (schemas/tables) → teardown.
Uses a trap/finalizer so services and runtime state are cleaned on success or failure.

#### 6. Teardown

```
just orb-down       # stop all native services (keep data)
just orb-clean      # stop and wipe all native data + SQLMesh state (destructive)
```

#### Logs and storage

- Service logs: `$HOME/.local/share/orb-native/logs/`
- Trino server log: `$HOME/.local/share/orb-native/trino-data/var/log/server.log`
- PID files: `$HOME/.local/share/orb-native/pids/`
- Data dirs: `pgdata/`, `minio-data/`, `trino-data/` under `$HOME/.local/share/orb-native/`

#### Differences from Docker

- PostgreSQL 15 (apt) instead of 17 (Docker image). Lakekeeper compatible with both.
- Hostnames are `localhost` instead of Docker DNS names (lakekeeper, minio, db).
- Lakekeeper metrics port is 9100 (to avoid conflict with MinIO on 9000).
- Trino config is generated at runtime with localhost endpoints.
- No Docker volumes — data is in `$HOME/.local/share/orb-native/`.

## Architecture

SQLMesh connects to Trino on localhost:8080, catalog `iceberg`.
The `iceberg` catalog is a static Trino catalog (iceberg.properties) pointing
to Lakekeeper warehouse `prod`. Dynamic catalog management is enabled
(`catalog.management=dynamic`), so additional catalogs can be created at
runtime via `CREATE CATALOG` SQL statements without restarting Trino.

State is stored in local DuckDB file `sqlmesh_state.db`.

Trino catalog → Lakekeeper warehouse → Iceberg namespaces → Trino schemas:

- Lakekeeper warehouse `prod` = top-level storage container (S3 bucket `warehouse`)
- Iceberg namespace = Trino schema (e.g. `raw`, `staging`)
- Iceberg table = Trino table (e.g. `iceberg.raw.orders`)

## Project Structure

```
.
├── config.yaml                      SQLMesh config (Trino connection, DuckDB state)
├── models/
│   ├── raw/orders.sql               Seed model (loads CSV into Iceberg table)
│   └── staging/stg_orders.sql       Staging model (FULL, with audits)
├── seeds/orders.csv                 10-row fixture data
├── audits/                          Custom audit definitions
├── macros/                          Custom macro definitions
├── tests/                           SQLMesh unit tests
├── scripts/
│   └── orb-services.sh              Orb-native service manager (start/stop/health/clean)
├── infra/
│   ├── docker-compose.yml           Postgres + MinIO + Lakekeeper + Trino (Docker mode)
│   ├── trino/
│   │   ├── etc/config.properties    Trino server config (dynamic catalog management)
│   │   └── catalog/iceberg.properties  Iceberg REST catalog → Lakekeeper warehouse prod
│   └── lakekeeper/
│       └── create-warehouse.json    Warehouse bootstrap payload (warehouse "prod")
├── .agents/
│   ├── setup                        Orb setup — installs all native + Python deps
│   └── resume                       Orb resume — fast idempotent check
├── justfile                         CLI command runner (Docker + orb-native recipes)
├── pyproject.toml                   Python deps (sqlmesh[trino])
└── .env.example                     Environment variables template
```

## Adding Models

1. Create `.sql` file in `models/` (e.g. `models/marts/final_orders.sql`).
2. Define MODEL block with name, kind, and optional audits.
3. Run `just lint` to check for issues.
4. Run `just plan` to apply changes.
5. Run `just run` to execute models.
6. Run `just test` to validate.
7. Run `just verify` for full stack verification.

## Raw Data Loading

CSV files placed in `data/` are loaded into `iceberg.raw.<table_name>` by the
generic loader (`scripts/load_raw.py`).

- Run `just load-raw` to load all `data/*.csv` files.
- Run `just test-load-raw` to run the loader's unit tests.
- All files are validated before any table is dropped or modified.
- All raw columns are VARCHAR — SQLMesh owns typing.
- Empty CSV fields are stored as empty strings (`''`), not SQL NULL.
- Reserved filenames like `order.csv` work (table name is quoted).
- See `data/README.md` for the full CSV specification.

## Key Commands

| Command | Purpose |
|---------|---------|
| `just setup` | Install Python deps |
| `just infra-up` | Start infrastructure (wait for healthchecks) |
| `just down` | Stop infrastructure (keep volumes) |
| `just clean` | Stop and wipe everything (destructive) |
| `just health` | Check Trino + Lakekeeper endpoints |
| `just status` | Show container status |
| `just logs` | Tail infrastructure logs |
| `just plan` | Apply SQLMesh plan (interactive) |
| `just plan-auto` | Apply SQLMesh plan (non-interactive) |
| `just run` | Run models |
| `just test` | Run SQLMesh tests |
| `just lint` | Lint SQL models |
| `just format` | Format SQL models |
| `just load-raw` | Load CSV files from data/ into iceberg.raw.* tables |
| `just test-load-raw` | Run raw loader unit tests |
| `just fetch "SQL"` | Query via SQLMesh fetchdf |
| `just trino-query "SQL"` | Query Trino CLI directly |
| `just trino-shell` | Interactive Trino CLI |
| `just smoke` | Show schemas + tables via Trino CLI |
| `just verify` | Docker full stack: lint → infra → raw load → plan → run → test → smoke → teardown |
| `just verify-orb` | Orb-native full stack: lint → native infra → raw load → plan → run → test → smoke → teardown |
| `just orb-setup` | Install native deps (JDK, Trino, MinIO, Lakekeeper, PG) |
| `just orb-up` | Start native services |
| `just orb-down` | Stop native services |
| `just orb-clean` | Stop and wipe native data (destructive) |
| `just orb-status` | Show native service status |
| `just orb-health` | Health-check native services |
| `just orb-logs [svc]` | Tail native service logs |
| `just orb-trino-query "SQL"` | Query native Trino via CLI |
| `just ui` | SQLMesh browser UI |
| `just dag` | Render DAG as HTML |
