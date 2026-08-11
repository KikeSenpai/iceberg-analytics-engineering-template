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

## Quick Start

1. `cp .env.example .env` — copy environment template
2. `just setup` — install Python deps via UV
3. `just infra-up` — start Trino, Lakekeeper, MinIO, Postgres
4. `just plan` — apply SQLMesh plan (creates tables, loads seeds)
5. `just run` — run models
6. `just test` — run SQLMesh tests

## Verification

For infra or model changes, run `just verify`. This executes the full chain:
sqlfluff lint → compose config check → docker compose up → Trino/Lakekeeper health
check → sqlmesh plan → sqlmesh run → sqlmesh test → query verification → teardown.

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
│   │   ├── etc/config.properties    Trino server config
│   │   └── catalog/iceberg.properties  Iceberg REST catalog → Lakekeeper, S3 → MinIO
│   └── lakekeeper/
│       └── create-warehouse.json    Warehouse bootstrap payload
├── justfile                         CLI command runner
├── pyproject.toml                   Python deps (sqlmesh[trino], sqlfluff)
└── .env.example                     Environment variables template
```

## Architecture

Startup order (orchestrated by Compose depends_on):
1. Postgres starts (metadata store for Lakekeeper).
2. MinIO starts; createbuckets creates bucket `warehouse`.
3. Lakekeeper migrate runs (DB schema migration).
4. Lakekeeper server starts (REST catalog on :8181).
5. Bootstrap accepts terms-of-use.
6. Initialwarehouse creates warehouse `demo` (S3 bucket `warehouse`).
7. Trino starts (Iceberg connector → Lakekeeper REST catalog, S3 → MinIO).

SQLMesh connects to Trino on localhost:8080, catalog `iceberg`.
State is stored in local DuckDB file `sqlmesh_state.db`.

## Adding Models

1. Create `.sql` file in `models/` (e.g. `models/marts/final_orders.sql`).
2. Define MODEL block with name, kind, and optional audits.
3. Run `just plan` to apply changes.
4. Run `just run` to execute models.
5. Run `just test` to validate.

## Key Commands

| Command | Purpose |
|---------|---------|
| `just setup` | Install Python deps |
| `just infra-up` | Start infrastructure |
| `just down` | Stop infrastructure |
| `just clean` | Stop and wipe volumes |
| `just plan` | Apply SQLMesh plan |
| `just run` | Run models |
| `just test` | Run tests |
| `just lint` | Lint SQL |
| `just verify` | Full stack verification |
| `just ui` | SQLMesh browser UI |
