#!/usr/bin/env python3
"""Generic CSV-to-Iceberg raw loader.

Discovers data/*.csv and loads each file into prod.raw.<table_name>.
All raw columns are VARCHAR — SQLMesh owns typing and transformation.

Raw-fidelity policy:
- Empty CSV fields are stored as empty strings (''), not SQL NULL.
- This preserves the original data; downstream models decide treatment.

Usage:
    uv run python scripts/load_raw.py
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path

from trino.dbapi import connect

DATA_DIR = Path(__file__).resolve().parents[1] / "data"
BATCH_SIZE = 500
TRINO_HOST = "localhost"
TRINO_PORT = 8080
TRINO_USER = "raw_loader"
TRINO_CATALOG = "prod"


# ─── Identifier handling ──────────────────────────────────────────────────────


def quote_identifier(value: str) -> str:
    """Quote a SQL identifier (table or column name).

    Double quotes are escaped per SQL rules. This supports source headers with
    spaces and punctuation while safely handling reserved words like ``order``.
    """
    if not value:
        raise ValueError("Empty identifier")
    if "\x00" in value:
        raise ValueError("Identifier contains a null byte")
    return '"' + value.replace('"', '""') + '"'


# ─── SQL literal escaping ─────────────────────────────────────────────────────


def sql_literal(value: str | None) -> str:
    """Escape a string as a Trino SQL string literal.

    ``None`` becomes ``NULL``; an empty string becomes ``''`` (empty string,
    not NULL) per the raw-fidelity policy.
    """
    if value is None:
        return "NULL"
    return "'" + value.replace("'", "''") + "'"


# ─── CSV validation ───────────────────────────────────────────────────────────


class CsvValidationError(ValueError):
    """Raised when a CSV file fails validation."""


def validate_csv(path: Path) -> tuple[list[str], list[list[str]]]:
    """Read and fully validate a CSV file.

    Returns ``(headers, rows)``.  Raises :class:`CsvValidationError` on any
    problem: bad encoding, missing headers, duplicate headers (case-insensitive),
    invalid identifiers, or inconsistent row widths.
    """
    # Read as UTF-8 (strip BOM if present)
    try:
        text = path.read_text(encoding="utf-8-sig")
    except UnicodeDecodeError as exc:
        raise CsvValidationError(f"{path.name}: not valid UTF-8 ({exc})") from exc

    reader = csv.reader(text.splitlines())
    try:
        headers = next(reader)
    except StopIteration as exc:
        raise CsvValidationError(f"{path.name}: empty file (no headers)") from exc

    if not headers or all(h == "" for h in headers):
        raise CsvValidationError(f"{path.name}: empty headers")

    # Duplicate-header check (case-insensitive)
    seen: set[str] = set()
    for h in headers:
        lower = h.lower()
        if lower in seen:
            raise CsvValidationError(
                f"{path.name}: duplicate header {h!r} (case-insensitive)"
            )
        seen.add(lower)

    # Validate every header can be represented as a quoted identifier.
    for h in headers:
        try:
            quote_identifier(h)
        except ValueError as exc:
            raise CsvValidationError(f"{path.name}: invalid header {h!r}") from exc

    rows = [r for r in reader if r != []]

    # Consistent row width
    for i, row in enumerate(rows, start=2):  # line 1 = headers
        if len(row) != len(headers):
            raise CsvValidationError(
                f"{path.name}: row {i} has {len(row)} fields, expected {len(headers)}"
            )

    return headers, rows


# ─── DDL / DML builders ───────────────────────────────────────────────────────


def build_create_table_sql(table: str, columns: list[str]) -> str:
    """Build a CREATE TABLE statement for an Iceberg v2 Parquet table."""
    col_sql = ", ".join(f"{col} VARCHAR" for col in columns)
    return (
        f"CREATE TABLE prod.raw.{table} ({col_sql}) "
        "WITH (format = 'PARQUET', format_version = 2)"
    )


def build_insert_sql(table: str, columns: list[str], num_rows: int) -> str:
    """Build a parameterised INSERT statement for *num_rows* rows.

    Uses ``?`` placeholders for Trino DBAPI ``EXECUTE IMMEDIATE``.
    """
    col_sql = ", ".join(columns)
    row_ph = "(" + ", ".join(["?"] * len(columns)) + ")"
    placeholders = ", ".join([row_ph] * num_rows)
    return f"INSERT INTO prod.raw.{table} ({col_sql}) VALUES {placeholders}"


def insert_batch(
    cursor, table: str, columns: list[str], batch: list[list[str]]
) -> None:
    """Insert a bounded batch of rows using parameterised values."""
    sql = build_insert_sql(table, columns, len(batch))
    params = tuple(v for row in batch for v in row)
    cursor.execute(sql, params)


# ─── Orchestration ────────────────────────────────────────────────────────────


def load_csv(cursor, path: Path) -> int:
    """Drop, recreate, and load a single CSV file. Returns row count."""
    table = quote_identifier(path.stem)
    headers, rows = validate_csv(path)
    columns = [quote_identifier(h) for h in headers]

    cursor.execute(f"DROP TABLE IF EXISTS prod.raw.{table}")
    cursor.execute(build_create_table_sql(table, columns))

    for offset in range(0, len(rows), BATCH_SIZE):
        insert_batch(cursor, table, columns, rows[offset : offset + BATCH_SIZE])

    return len(rows)


def main() -> None:
    paths = sorted(DATA_DIR.glob("*.csv"))
    if not paths:
        raise SystemExit(f"No CSV files found in {DATA_DIR}")

    # ── Phase 1: validate ALL files before any destructive operation ──
    validated: dict[Path, tuple[str, list[str], list[list[str]]]] = {}
    for path in paths:
        headers, rows = validate_csv(path)
        table = quote_identifier(path.stem)
        columns = [quote_identifier(h) for h in headers]
        validated[path] = (table, columns, rows)
        print(f"  validated {path.name}: {len(rows)} rows, {len(headers)} columns")

    # ── Phase 2: drop / create / load (all files passed validation) ──
    conn = connect(
        host=TRINO_HOST, port=TRINO_PORT, user=TRINO_USER, catalog=TRINO_CATALOG
    )
    cursor = conn.cursor()
    cursor.execute("CREATE SCHEMA IF NOT EXISTS prod.raw")

    for path, (table, columns, rows) in validated.items():
        cursor.execute(f"DROP TABLE IF EXISTS prod.raw.{table}")
        cursor.execute(build_create_table_sql(table, columns))
        for offset in range(0, len(rows), BATCH_SIZE):
            insert_batch(cursor, table, columns, rows[offset : offset + BATCH_SIZE])
        print(f"  loaded {len(rows):,} rows → prod.raw.{path.stem}")

    conn.close()
    print("Done.")


if __name__ == "__main__":
    main()
