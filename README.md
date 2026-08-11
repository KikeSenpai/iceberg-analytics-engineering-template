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
just plan         # apply SQLMesh plan (creates tables, loads seeds)
just run          # run models
just test         # run tests
```

## Verify Full Stack

```bash
just verify
```

## Services

| Service | Port | Purpose |
|---------|------|---------|
| Trino | 8080 | SQL query engine |
| Lakekeeper | 8181 | Iceberg REST Catalog UI/API |
| MinIO S3 | 9000 | S3 API |
| MinIO Console | 9001 | Web console |

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
3. Run `just plan` to apply.
4. Run `just run` to execute.

## Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| MINIO_ROOT_USER | minio-root-user | MinIO admin user |
| MINIO_ROOT_PASSWORD | minio-root-password | MinIO admin password |
| LAKEKEEPER_PG_ENCRYPTION_KEY | This-is-NOT-Secure! | Lakekeeper DB encryption key |
