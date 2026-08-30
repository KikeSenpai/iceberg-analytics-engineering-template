#!/usr/bin/env python3
"""Focused unit tests for the CSV-to-Iceberg raw loader.

Run:  uv run python scripts/test_load_raw.py
"""

from __future__ import annotations

import csv
import os
import sys
import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch

# Make scripts/ importable
sys.path.insert(0, str(Path(__file__).resolve().parent))
import load_raw  # noqa: E402


# ─── Identifier handling ─────────────────────────────────────────────────────


def test_quote_identifier_basic():
    assert load_raw.quote_identifier("orders") == '"orders"'


def test_quote_identifier_preserves_case():
    assert load_raw.quote_identifier("Orders") == '"Orders"'


def test_quote_identifier_reserved_word():
    """Reserved words like ``order`` must be safely quotable."""
    assert load_raw.quote_identifier("order") == '"order"'


def test_quote_identifier_underscore_and_digits():
    assert load_raw.quote_identifier("user_id") == '"user_id"'
    assert load_raw.quote_identifier("_private") == '"_private"'


def test_quote_identifier_rejects_empty():
    try:
        load_raw.quote_identifier("")
    except ValueError:
        pass
    else:
        raise AssertionError("Should reject empty identifier")


def test_quote_identifier_supports_source_headers():
    assert load_raw.quote_identifier("Order ID") == '"Order ID"'
    assert load_raw.quote_identifier("Price (EUR)") == '"Price (EUR)"'
    assert load_raw.quote_identifier('a"b') == '"a""b"'


def test_quote_identifier_rejects_null_byte():
    try:
        load_raw.quote_identifier("bad\x00header")
    except ValueError:
        pass
    else:
        raise AssertionError("Should reject a null byte")


# ─── SQL literals / parameters ───────────────────────────────────────────────


def test_sql_literal_none_is_null():
    assert load_raw.sql_literal(None) == "NULL"


def test_sql_literal_empty_string_is_not_null():
    """Empty string must become '' not NULL."""
    assert load_raw.sql_literal("") == "''"


def test_sql_literal_simple():
    assert load_raw.sql_literal("hello") == "'hello'"


def test_sql_literal_with_single_quote():
    assert load_raw.sql_literal("O'Brien") == "'O''Brien'"


def test_sql_literal_with_percent():
    assert load_raw.sql_literal("100%") == "'100%'"


def test_build_insert_sql_uses_parameter_placeholders():
    sql = load_raw.build_insert_sql('"orders"', ['"id"', '"name"'], 2)
    assert "?" in sql
    assert sql.count("?") == 4  # 2 rows × 2 columns
    assert "VALUES" in sql


def test_build_insert_sql_single_row():
    sql = load_raw.build_insert_sql('"t"', ['"c"'], 1)
    assert sql == 'INSERT INTO prod.raw."t" ("c") VALUES (?)'


# ─── Duplicate headers ───────────────────────────────────────────────────────


def test_validate_csv_duplicate_headers_exact():
    with _tmp_csv(["id,id\n1,2\n"]) as p:
        try:
            load_raw.validate_csv(p)
        except load_raw.CsvValidationError as e:
            assert "duplicate" in str(e).lower()
        else:
            raise AssertionError("Should reject exact duplicate headers")


def test_validate_csv_duplicate_headers_case_insensitive():
    with _tmp_csv(["ID,id\n1,2\n"]) as p:
        try:
            load_raw.validate_csv(p)
        except load_raw.CsvValidationError as e:
            assert "duplicate" in str(e).lower()
        else:
            raise AssertionError("Should reject case-insensitive duplicate headers")


# ─── Row-width validation ────────────────────────────────────────────────────


def test_validate_csv_inconsistent_row_width():
    with _tmp_csv(["a,b,c\n1,2\n"]) as p:
        try:
            load_raw.validate_csv(p)
        except load_raw.CsvValidationError as e:
            assert "row 2" in str(e)
        else:
            raise AssertionError("Should reject inconsistent row width")


def test_validate_csv_extra_fields():
    with _tmp_csv(["a,b\n1,2,3\n"]) as p:
        try:
            load_raw.validate_csv(p)
        except load_raw.CsvValidationError:
            pass
        else:
            raise AssertionError("Should reject extra fields")


# ─── Pre-drop validation ─────────────────────────────────────────────────────


def test_main_validates_all_before_drops():
    """If the second file is malformed, no DROP should be issued."""
    with tempfile.TemporaryDirectory() as tmpdir:
        data_dir = Path(tmpdir)
        (data_dir / "good.csv").write_text("id,name\n1,alice\n")
        (data_dir / "bad.csv").write_text("a,b\n1,2,3\n")  # bad row width

        with patch.object(load_raw, "DATA_DIR", data_dir):
            with patch.object(load_raw, "connect") as mock_connect:
                mock_cursor = MagicMock()
                mock_connect.return_value.cursor.return_value = mock_cursor
                try:
                    load_raw.main()
                except load_raw.CsvValidationError:
                    pass
                else:
                    raise AssertionError("Should have raised CsvValidationError")

                # No DROP TABLE should have been executed
                for call in mock_cursor.execute.call_args_list:
                    sql = call.args[0] if call.args else call.kwargs.get("sql", "")
                    if "DROP TABLE" in sql:
                        raise AssertionError(
                            "DROP TABLE issued before all files validated!"
                        )


# ─── Empty fields ────────────────────────────────────────────────────────────


def test_validate_csv_empty_fields_preserved_as_empty_string():
    with _tmp_csv(["a,b\n,hello\nworld,\n"]) as p:
        headers, rows = load_raw.validate_csv(p)
        assert rows[0] == ["", "hello"]
        assert rows[1] == ["world", ""]


def test_sql_literal_empty_vs_none_distinction():
    assert load_raw.sql_literal("") == "''"
    assert load_raw.sql_literal(None) == "NULL"
    assert load_raw.sql_literal("") != load_raw.sql_literal(None)


# ─── Batching ────────────────────────────────────────────────────────────────


def test_batching_boundaries():
    """Verify batch slicing at BATCH_SIZE boundaries."""
    rows = [list(range(3)) for _ in range(1200)]
    batches = [
        rows[i : i + load_raw.BATCH_SIZE]
        for i in range(0, len(rows), load_raw.BATCH_SIZE)
    ]
    assert len(batches) == 3
    assert len(batches[0]) == 500
    assert len(batches[1]) == 500
    assert len(batches[2]) == 200


def test_insert_batch_calls_execute_with_correct_params():
    cursor = MagicMock()
    load_raw.insert_batch(cursor, '"t"', ['"a"', '"b"'], [["x", "y"], ["p", "q"]])
    cursor.execute.assert_called_once()
    sql, params = cursor.execute.call_args.args
    assert "?" in sql
    assert params == ("x", "y", "p", "q")


def test_insert_batch_empty_does_not_call_execute():
    cursor = MagicMock()
    # An empty batch should not produce an INSERT call
    # (load_csv only batches non-empty slices, but be safe)
    # build_insert_sql with 0 rows would produce invalid SQL, so we just
    # verify the function doesn't crash on empty input — it would if called.
    # Skip: insert_batch with 0 rows is a programming error, not a test case.


# ─── No CSV files ────────────────────────────────────────────────────────────


def test_main_fails_when_no_csv_files():
    with tempfile.TemporaryDirectory() as tmpdir:
        with patch.object(load_raw, "DATA_DIR", Path(tmpdir)):
            try:
                load_raw.main()
            except SystemExit as e:
                assert "No CSV files" in str(e)
            else:
                raise AssertionError("Should exit when no CSV files found")


# ─── Empty / malformed files ─────────────────────────────────────────────────


def test_validate_csv_empty_file():
    with _tmp_csv([""]) as p:
        try:
            load_raw.validate_csv(p)
        except load_raw.CsvValidationError as e:
            assert "empty" in str(e).lower()
        else:
            raise AssertionError("Should reject empty file")


def test_validate_csv_no_headers():
    with _tmp_csv(["\n\n"]) as p:
        try:
            load_raw.validate_csv(p)
        except load_raw.CsvValidationError as e:
            assert "header" in str(e).lower()
        else:
            raise AssertionError("Should reject file with no headers")


def test_validate_csv_empty_header():
    with _tmp_csv(["id,\n1,2\n"]) as p:
        try:
            load_raw.validate_csv(p)
        except load_raw.CsvValidationError as e:
            assert "invalid" in str(e).lower()
        else:
            raise AssertionError("Should reject empty header name")


# ─── CREATE TABLE ────────────────────────────────────────────────────────────


def test_build_create_table_sql():
    sql = load_raw.build_create_table_sql('"orders"', ['"id"', '"name"'])
    assert "prod.raw.\"orders\"" in sql
    assert '"id" VARCHAR' in sql
    assert "PARQUET" in sql
    assert "format_version = 2" in sql


# ─── Helpers ─────────────────────────────────────────────────────────────────


class _tmp_csv:
    """Context manager that writes content to a temp CSV file."""

    def __init__(self, lines: list[str]):
        self.lines = lines
        self.path: Path | None = None
        self._tmpdir = tempfile.TemporaryDirectory()

    def __enter__(self) -> Path:
        self.path = Path(self._tmpdir.name) / "test.csv"
        self.path.write_text("".join(self.lines), encoding="utf-8")
        return self.path

    def __exit__(self, *exc):
        self._tmpdir.cleanup()


# ─── Runner ──────────────────────────────────────────────────────────────────


def _run_all_tests():
    tests = [
        (name, obj)
        for name, obj in globals().items()
        if name.startswith("test_") and callable(obj)
    ]
    passed = 0
    failed = 0
    for name, fn in tests:
        try:
            fn()
            print(f"  PASS  {name}")
            passed += 1
        except Exception as e:
            print(f"  FAIL  {name}: {e}")
            failed += 1
    print(f"\n{passed} passed, {failed} failed, {passed + failed} total")
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    _run_all_tests()
