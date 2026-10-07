# Iceberg Analytics Engineering Template

## Tech Stack

- Query engine: Trino 476 (trinodb/trino, version-pinned)
- Table format: Apache Iceberg
- Catalog: Lakekeeper v0.12.4 (Iceberg REST Catalog)
- Storage: MinIO (S3-compatible, stands in for S3/ADLS; `pgsty/minio` community fork image)
- Transformations: SQLMesh (Trino adapter, DuckDB state)
- Python: UV for dependency management
- Linting: SQLMesh built-in linter
- CLI runner: just

## Testing Workflow

Docker Compose is the only execution mode, locally and in Amp orbs. All
commands use `just`.

### Amp orbs

`.agents/setup` installs uv, just, Docker Engine, the Compose plugin, and
Python deps. `.amp/services.yaml` declares the `docker-daemon` orb service
(`sudo dockerd`), and `.agents/resume` runs `amp orb services ensure` to start it.
If `docker info` fails in an orb, run:

```
amp orb services ensure                 # start dockerd as a supervised service
amp orb service logs docker-daemon      # inspect dockerd logs
```

Then use the same steps as local development below. `just verify` is the
canonical end-to-end check.

### Steps

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
just test           # run SQLMesh unit tests (none ship yet; add under tests/)
just fetch "SELECT COUNT(*) FROM staging.stg_orders"
just smoke          # show schemas and tables via Trino CLI
just trino-query "SELECT * FROM prod.raw.orders LIMIT 5"
```

#### 5. Full stack verification (one command)

```
just verify
```

Runs the entire chain: lint → compose config → infra up → health check →
raw load → SQLMesh plan → SQLMesh run → SQLMesh test → smoke → MinIO storage
check (`just minio-files` must list Parquet files) → restart persistence check
(`down` / `up`, same MinIO objects) → teardown.

Use this after any infra or model change to confirm nothing broke.

#### 6. Teardown

```
just down           # stop services, keep volumes (data survives infra-up)
just clean          # stop services, wipe volumes and SQLMesh state (destructive)
```

## Explore Raw Data Before Modeling

Inspect loaded raw data before writing SQLMesh models. Prefer non-interactive
commands so results remain visible in agent logs.

```
just smoke
just trino-query "SHOW TABLES FROM prod.raw"
just trino-query "DESCRIBE prod.raw.<table>"
just trino-query "SELECT * FROM prod.raw.<table> LIMIT 20"
just trino-query "SELECT COUNT(*) FROM prod.raw.<table>"
```

Use additional read-only queries to profile nulls, distinct values, and ranges.
Raw-loader columns are `VARCHAR`; infer and apply business types in SQLMesh
models. `just fetch "SELECT ..."` is also available through SQLMesh.

## Architecture

SQLMesh connects to Trino on localhost:8080, catalog `prod`.
The `prod` catalog is a static Trino catalog (prod.properties) pointing
to Lakekeeper warehouse `prod`. Dynamic catalog management is enabled
(`catalog.management=dynamic`), so additional catalogs can be created at
runtime via `CREATE CATALOG` SQL statements without restarting Trino.

The Trino catalog name `prod` and the Lakekeeper warehouse name `prod`
happen to match but are different concepts: the Trino catalog is a
connector configuration that points to a Lakekeeper warehouse.

State is stored in local DuckDB file `sqlmesh_state.db`.

### Physical storage

MinIO bucket `warehouse` is the only physical store for Iceberg data. Trino
writes Parquet data files and Iceberg metadata files there through
`s3.endpoint=http://minio:9000` with path-style access and Lakekeeper-vended
credentials. Postgres holds only Lakekeeper catalog state. Both use named
Docker volumes (`minio_data`, `postgres_data`), so data survives `just down` /
`just infra-up`. `just clean` wipes volumes and `sqlmesh_state.db` together;
keep them in sync, or SQLMesh state references tables that no longer exist.

SQLMesh writes each model to a physical table in `sqlmesh__<schema>` (e.g.
`prod.sqlmesh__staging.staging__stg_orders__<hash>`) and exposes it as a view
in `<schema>` (e.g. `prod.staging.stg_orders`). Raw loader tables are physical
tables in `prod.raw`. Use `just minio-files` to list the Parquet files.

Trino catalog → Lakekeeper warehouse → Iceberg namespaces → Trino schemas:

- Lakekeeper warehouse `prod` = top-level storage container (S3 bucket `warehouse`)
- Iceberg namespace = Trino schema (e.g. `raw`, `staging`)
- Iceberg table = Trino table (e.g. `prod.raw.orders`)

## Project Structure

```
.
├── config.yaml                      SQLMesh config (Trino connection, DuckDB state)
├── models/
│   ├── raw/orders.sql               Seed model (loads CSV into Iceberg table)
│   └── staging/stg_orders.sql       Staging model (FULL, with audits)
├── seeds/orders.csv                 10-row fixture data
├── scripts/
│   ├── load_raw.py                  CSV-to-Iceberg raw loader
│   └── test_load_raw.py             Raw loader unit tests
├── infra/
│   ├── docker-compose.yml           Postgres + MinIO + Lakekeeper + Trino (named volumes)
│   ├── trino/
│   │   ├── etc/config.properties    Trino server config (dynamic catalog management)
│   │   └── catalog/prod.properties     Trino catalog `prod` → Lakekeeper warehouse `prod`
│   └── lakekeeper/
│       └── create-warehouse.json    Warehouse bootstrap payload (warehouse "prod")
├── .agents/
│   ├── setup                        Orb setup — installs uv, just, Docker Engine + Compose, Python deps
│   └── resume                       Orb resume — starts the docker-daemon orb service
├── .amp/services.yaml               Orb service: supervised dockerd
├── justfile                         CLI command runner
└── pyproject.toml                   Python deps (sqlmesh[trino])
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

CSV files placed in `data/` are loaded into `prod.raw.<table_name>` by the
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
| `just down` | Stop infrastructure (keep volumes and data) |
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
| `just load-raw` | Load CSV files from data/ into prod.raw.* tables |
| `just test-load-raw` | Run raw loader unit tests |
| `just fetch "SQL"` | Query via SQLMesh fetchdf |
| `just trino-query "SQL"` | Query Trino CLI directly |
| `just trino-shell` | Interactive Trino CLI |
| `just smoke` | Show schemas + tables via Trino CLI |
| `just minio-files` | List Iceberg Parquet data files stored in MinIO |
| `just verify` | Full stack: lint → infra → raw load → plan → run → test → smoke → storage + restart checks → teardown |
| `just ui` | SQLMesh browser UI |
| `just dag` | Render DAG as HTML |
