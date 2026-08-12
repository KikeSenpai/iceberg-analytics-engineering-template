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

Follow these steps when testing infra or model changes. All commands use `just`.

### 1. Static checks (no infra needed)

```
just setup          # install Python deps (uv sync)
just lint           # SQLMesh built-in linter
just compose-check  # validate docker-compose.yml
```

### 2. Start infrastructure

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

### 3. Apply SQLMesh plan

```
just plan-auto      # non-interactive: creates tables, loads seeds, builds models
```

Or interactive:
```
just plan           # prompts for backfill start date
```

### 4. Verify data

```
just run            # execute missing intervals
just test           # run SQLMesh unit tests
just fetch "SELECT COUNT(*) FROM staging.stg_orders"
just smoke          # show schemas and tables via Trino CLI
just trino-query "SELECT * FROM iceberg.raw.orders LIMIT 5"
```

### 5. Full stack verification (one command)

```
just verify
```

Runs the entire chain: lint → compose config → infra up → health check →
SQLMesh plan → SQLMesh run → SQLMesh test → query verification → teardown.

Use this after any infra or model change to confirm nothing broke.

### 6. Teardown

```
just down           # stop services, keep volumes
just clean          # stop services, wipe volumes and SQLMesh state (destructive)
```

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
├── infra/
│   ├── docker-compose.yml           Postgres + MinIO + Lakekeeper + Trino
│   ├── trino/
│   │   ├── etc/config.properties    Trino server config (dynamic catalog management)
│   │   └── catalog/iceberg.properties  Iceberg REST catalog → Lakekeeper warehouse prod
│   └── lakekeeper/
│       └── create-warehouse.json    Warehouse bootstrap payload (warehouse "prod")
├── justfile                         CLI command runner (all testing commands)
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
| `just fetch "SQL"` | Query via SQLMesh fetchdf |
| `just trino-query "SQL"` | Query Trino CLI directly |
| `just trino-shell` | Interactive Trino CLI |
| `just smoke` | Show schemas + tables via Trino CLI |
| `just verify` | Full stack verification + teardown |
| `just ui` | SQLMesh browser UI |
| `just dag` | Render DAG as HTML |
