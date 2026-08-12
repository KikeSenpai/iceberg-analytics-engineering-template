# Iceberg Analytics Engineering Template

Apache Iceberg analytics stack for analytics engineer take-home tests. Trino + Iceberg + Lakekeeper + MinIO + SQLMesh, with UV for Python dependency management.

## Tech Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| Trino | 476 | SQL query engine |
| Apache Iceberg | — | Table format |
| Lakekeeper | v0.12.4 | Iceberg REST Catalog |
| MinIO | RELEASE.2025-07-23 | S3-compatible object storage |
| SQLMesh | latest | Transformations framework + built-in linter |
| UV | — | Python dependency management |
| just | — | CLI command runner |

## Quick Start

```bash
cp .env.example .env
just setup        # install Python deps
just infra-up     # start Trino, Lakekeeper, MinIO, Postgres
just plan-auto    # apply SQLMesh plan (creates tables, loads seeds)
just run          # run models
just test         # run tests
```

## Verify Full Stack

```bash
just verify
```

Runs: lint → compose config → infra up → health checks → SQLMesh plan → run → test → query → teardown.

## Services

| Service | Port | Purpose |
|---------|------|---------|
| Trino | 8080 | SQL query engine |
| Lakekeeper | 8181 | Iceberg REST Catalog UI/API |
| MinIO S3 | 9000 | S3 API |
| MinIO Console | 9001 | Web console |

## CLI Commands (justfile)

All commands run via `just`. Run `just --list` to see all recipes.

### Infrastructure

| Command | Purpose |
|---------|---------|
| `just setup` | Install Python deps via UV |
| `just infra-up` | Start all services, wait for healthchecks |
| `just down` | Stop services (keep volumes) |
| `just clean` | Stop and wipe volumes + SQLMesh state (destructive) |
| `just status` | Show container status |
| `just logs` | Tail infrastructure logs |
| `just health` | Check Trino + Lakekeeper health endpoints |
| `just compose-check` | Validate docker-compose config |

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

### Full Verification

| Command | Purpose |
|---------|---------|
| `just verify` | Full stack: lint → infra → plan → run → test → query → teardown |

## Project Structure

```
models/          SQLMesh models (SQL files)
seeds/           CSV fixture data
infra/           Docker Compose + Trino/Lakekeeper config
config.yaml      SQLMesh project config
justfile         CLI recipes
```

## Adding Models

1. Create a `.sql` file under `models/`.
2. Define the `MODEL (...)` block with name, kind, and audits.
3. Run `just lint` to check for issues.
4. Run `just plan` to apply.
5. Run `just run` to execute.

## Architecture

```
Lakekeeper warehouse "prod"
  └── namespace "raw"        ← Trino schema: iceberg.raw
  │   └── table "orders"
  └── namespace "staging"    ← Trino schema: iceberg.staging
      └── table "stg_orders"
```

- Lakekeeper = catalog service (metadata, storage profiles)
- Warehouse = top-level storage container (S3 bucket, credentials)
- Namespace = Trino schema (group of tables)
- Table = Iceberg table (Parquet files in MinIO)

Static catalog `iceberg` loads at startup (points to warehouse `prod`).
Dynamic catalog management enabled — create additional catalogs at runtime:

```sql
CREATE CATALOG silver USING iceberg
WITH (
    "iceberg.catalog.type" = 'rest',
    "iceberg.rest-catalog.uri" = 'http://lakekeeper:8181/catalog',
    "iceberg.rest-catalog.warehouse" = 'prod',
    "iceberg.rest-catalog.nested-namespace-enabled" = 'true',
    "iceberg.rest-catalog.vended-credentials-enabled" = 'true',
    "fs.native-s3.enabled" = 'true',
    "s3.endpoint" = 'http://minio:9000',
    "s3.region" = 'local-01',
    "s3.path-style-access" = 'true'
)
```

## Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| MINIO_ROOT_USER | minio-root-user | MinIO admin user |
| MINIO_ROOT_PASSWORD | minio-root-password | MinIO admin password |
| LAKEKEEPER_PG_ENCRYPTION_KEY | This-is-NOT-Secure! | Lakekeeper DB encryption key |
