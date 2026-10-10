# Iceberg Analytics Engineering Template

Apache Iceberg analytics stack for analytics engineer take-home tests. Trino + Iceberg + Lakekeeper + MinIO + SQLMesh, with UV for Python dependency management.

## Air Service take-home

This branch contains the complete Air Service analytical model. See:

- [Original employer assignment (Part 1 and Part 2)](docs/take_home_test_requirements.md)
- [Analytical design, ERD, model dictionary, KPIs, and limitations](docs/take_home_solution.md)
- [Source provenance, conversion fidelity, and dataset profile](docs/data-provenance.md)

Run `just verify` for a clean full-stack load, plan, execution, audit/test, query, MinIO storage and restart persistence checks, and teardown. Run `just load-raw` when services are already up.

## Tech Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| Trino | 476 | SQL query engine |
| Apache Iceberg | — | Table format |
| Lakekeeper | v0.12.4 | Iceberg REST Catalog |
| MinIO | RELEASE.2026-08-04 (`pgsty/minio` fork) | S3-compatible object storage |
| SQLMesh | latest | Transformations framework + built-in linter |
| UV | — | Python dependency management |
| just | — | CLI command runner |

## Quick Start

### Docker (local development)

```bash
just setup        # install Python deps
just infra-up     # start Trino, Lakekeeper, MinIO, Postgres (Docker)
just load-raw     # load data/*.csv into prod.raw outside SQLMesh
just plan-auto    # apply SQLMesh plan
just run          # run models
just test         # run tests
```

### Amp orbs

`.agents/setup` installs uv, just, Docker Engine, and the Compose plugin.
`.amp/services.yaml` runs `dockerd` as the supervised `docker-daemon` orb
service, which `.agents/resume` starts. If Docker is not reachable, run
`amp orb services ensure`, then use the same `just` commands as above.

## Verify Full Stack

```bash
just verify
```

Runs: lint → compose config → infra up → health checks → raw load → SQLMesh plan → run → test → smoke → MinIO storage check → restart persistence check → teardown.

The storage check lists the Iceberg Parquet data files in MinIO (`just minio-files`)
and fails if there are none. The persistence check restarts the stack with
`docker compose down` / `up` and fails unless the same objects are still there.

## Services

| Service | Port | Purpose |
|---------|------|---------|
| Trino | 8080 | SQL query engine |
| Lakekeeper | 8181 | Iceberg REST Catalog UI/API |
| MinIO S3 | 9000 | S3 API |
| MinIO Console | 9001 | Web console |

### Storage and persistence

MinIO is the only physical store for Iceberg data. Every Parquet data file and
Iceberg `metadata.json` file lives in MinIO bucket `warehouse`; Trino has no
other filesystem configured. Postgres holds only Lakekeeper's catalog state
(warehouses, namespaces, and the pointer to each table's current metadata file).

Both are stored in named Docker volumes (`postgres_data`, `minio_data`), so data
survives `just down` / `just infra-up`. `just clean` removes the volumes and the
SQLMesh state file together; never delete one without the other, or SQLMesh will
reference tables that no longer exist.

## CLI Commands (justfile)

All commands run via `just`. Run `just --list` to see all recipes.

### Infrastructure

| Command | Purpose |
|---------|---------|
| `just setup` | Install Python deps via UV |
| `just infra-up` | Start all services, wait for healthchecks |
| `just down` | Stop services (keep volumes and data) |
| `just clean` | Stop and wipe volumes + SQLMesh state (destructive) |
| `just status` | Show container status |
| `just logs` | Tail infrastructure logs |
| `just health` | Check Trino + Lakekeeper health endpoints |
| `just compose-check` | Validate docker-compose config |

### Raw Data Loading

| Command | Purpose |
|---------|---------|
| `just load-raw` | Load CSV files from `data/` into `prod.raw.*` tables |
| `just test-load-raw` | Run raw loader unit tests |

### SQLMesh

| Command | Purpose |
|---------|---------|
| `just plan` | Apply SQLMesh plan (interactive) |
| `just plan-auto` | Apply SQLMesh plan (non-interactive, auto-apply) |
| `just run` | Execute missing model intervals |
| `just test` | Run SQLMesh unit tests |
| `just lint` | Lint SQL models |
| `just format` | Format SQL models |
| `just fetch "SQL"` | Query via SQLMesh fetchdf |
| `just ui` | SQLMesh browser UI |
| `just dag` | Render DAG as HTML |

### Trino Direct Access

| Command | Purpose |
|---------|---------|
| `just trino-query "SQL"` | Run SQL via Trino CLI (non-interactive) |
| `just trino-shell` | Open interactive Trino CLI shell |
| `just smoke` | Show schemas + tables via Trino CLI |
| `just minio-files` | List Iceberg Parquet data files stored in MinIO |

### Full Verification

| Command | Purpose |
|---------|---------|
| `just verify` | Full stack: lint → infra → raw load → plan → run → test → smoke → storage + restart checks → teardown |

## Project Structure

```
models/          SQLMesh models (SQL files)
data/            Raw loader input CSVs
audits/          SQLMesh data audits
tests/           SQLMesh unit tests
docs/            Analytics and source documentation
scripts/         Raw loader and validation tools
infra/           Docker Compose + Trino/Lakekeeper config
config.yaml      SQLMesh project config
justfile         CLI recipes
```

## Raw Data Loading

Place CSV files in `data/` and run `just load-raw` to load them into `prod.raw.<table_name>`.
All files are validated before any table changes. See `data/README.md` for details.

## Adding Models

1. Create a `.sql` file under `models/`.
2. Define the `MODEL (...)` block with name, kind, and audits.
3. Run `just lint` to check for issues.
4. Run `just plan` to apply.
5. Run `just run` to execute.

## Architecture

```mermaid
graph LR
    sqlmesh["SQLMesh"]
    trino["Trino"]
    lakekeeper["Lakekeeper\n(REST Catalog)"]
    minio["MinIO\n(s3://warehouse/)"]
    postgres["Postgres\n(Lakekeeper metadata)"]

    sqlmesh -- "Trino JDBC" --> trino
    trino -- "Iceberg REST" --> lakekeeper
    lakekeeper -- "metadata" --> postgres
    trino -- "S3: Parquet data + metadata (vended creds)" --> minio
    lakekeeper -- "S3: metadata files" --> minio

    subgraph "Lakekeeper warehouse 'prod'"
        ns_raw["namespace: raw"]
        ns_logical["namespaces: staging, intermediate, dimensions, facts, marts"]
        ns_phys["namespaces: sqlmesh__staging, sqlmesh__intermediate, sqlmesh__dimensions, sqlmesh__facts, sqlmesh__marts"]
    end
    lakekeeper --- ns_raw
    lakekeeper --- ns_logical
    lakekeeper --- ns_phys
    ns_raw -- "table (just load-raw)" --> tbl_raw["order, trip, customer, ..."]
    ns_logical -- "view" --> tbl_views["stg_order, fct_trip, business_overview, ..."]
    ns_phys -- "FULL: tables, VIEW: views" --> tbl_phys["facts__fct_trip__hash, marts__business_overview__hash, ..."]
```

### Catalog and namespace hierarchy

The terminology can be confusing because "catalog" is used in two senses:

- **Lakekeeper** is the metadata/catalog **service**. It manages one or more
  **warehouses**. This template creates a warehouse named `prod`.
- A **Trino catalog** is a connector configuration file (`<name>.properties`).
  The file name becomes the first component of `catalog.schema.table` in SQL.
  One Trino instance can have multiple Iceberg connector configurations,
  typically one per Lakekeeper warehouse.

This template uses a Trino catalog named `prod` (from `prod.properties`) that
points to the Lakekeeper warehouse `prod`. The names happen to match but are
different concepts.

**Hierarchy:**

```
Lakekeeper (metadata service)
└── warehouse "prod" (MinIO bucket "warehouse")
    ├── namespace "raw"                    → Trino schema: prod.raw
    │   └── table "order", "trip", ...     → raw loader tables (just load-raw, Parquet in MinIO)
    ├── namespace "staging"                → Trino schema: prod.staging
    │   └── view "stg_order", ...          → SQLMesh view over sqlmesh__staging
    ├── namespace "marts"                  → Trino schema: prod.marts
    │   └── view "business_overview", ...  → SQLMesh view over sqlmesh__marts
    ├── namespace "sqlmesh__staging"       → SQLMesh VIEW models (no data files)
    └── namespace "sqlmesh__marts"         → SQLMesh FULL tables (Parquet in MinIO)
    (intermediate / dimensions / facts follow the same pattern)
```

**Example:**

```sql
-- prod = Trino catalog (from prod.properties)
-- raw = Iceberg namespace (Trino schema)
-- "order" = Iceberg table (quoted because it is reserved)
SELECT * FROM prod.raw."order" LIMIT 5;
```

- SQLMesh connects to Trino via JDBC and submits all model SQL there.
- Trino's static `prod` catalog points to Lakekeeper warehouse `prod`.
- Lakekeeper stores catalog state in Postgres (namespaces, tables, and each
  table's current metadata-file pointer) and vends S3 credentials to Trino.
- Trino reads/writes Parquet data files and Iceberg metadata files in MinIO
  (`s3://warehouse/<namespace-id>/<table>-<id>/{data,metadata}/`) through the
  S3 endpoint `http://minio:9000` with path-style access.
- SQLMesh writes each model to a physical object in a `sqlmesh__<schema>`
  namespace (e.g. `prod.sqlmesh__marts.marts__business_overview__<hash>`) and
  exposes it as a view in `<schema>` (e.g. `prod.marts.business_overview`).
  `FULL` models (dimensions, facts, marts) store Parquet in MinIO like the raw
  loader tables; `VIEW` models (staging, intermediate) store no data files.
- Namespace = Trino schema (e.g. `raw`, `staging`). Table = Iceberg table.

Static catalog `prod` loads at startup (points to warehouse `prod`).
Dynamic catalog management enabled — create additional catalogs at runtime:

```sql
CREATE CATALOG silver USING iceberg
WITH (
    "iceberg.catalog.type" = 'rest',
    "iceberg.rest-catalog.uri" = 'http://lakekeeper:8181/catalog',
    "iceberg.rest-catalog.warehouse" = 'silver',
    "iceberg.rest-catalog.nested-namespace-enabled" = 'true',
    "iceberg.rest-catalog.vended-credentials-enabled" = 'true',
    "fs.native-s3.enabled" = 'true',
    "s3.endpoint" = 'http://minio:9000',
    "s3.region" = 'local-01',
    "s3.path-style-access" = 'true'
)
```

## Local Credentials

No `.env` file is needed. The stack uses fixed, non-secret local development
values set directly in `infra/docker-compose.yml` and
`infra/lakekeeper/create-warehouse.json`:

| Setting | Value | Purpose |
|---------|-------|---------|
| MinIO root user | minio-root-user | MinIO admin user / S3 access key |
| MinIO root password | minio-root-password | MinIO admin password / S3 secret key |
| Lakekeeper PG encryption key | This-is-NOT-Secure! | Lakekeeper DB encryption key |

Do not reuse these values outside local development.
