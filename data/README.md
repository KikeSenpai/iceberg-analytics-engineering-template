# Raw Data Directory

Place CSV files here to load them into `iceberg.raw.<table_name>`.

## Convention

- Each `*.csv` file becomes a table named after its filename (without extension).
- Example: `data/orders.csv` → `iceberg.raw.orders`
- Reserved filenames like `order.csv` work (the table name is quoted).

## Raw-fidelity policy

- All columns are created as `VARCHAR` — SQLMesh owns typing and transformation.
- Empty CSV fields are stored as **empty strings** (`''`), not SQL NULL.
- Downstream models decide whether to treat `''` as NULL.

## CSV requirements

- Valid UTF-8 encoding (BOM tolerated).
- First row must contain headers.
- No duplicate headers (case-insensitive).
- Header names must be safe identifiers: `[A-Za-z_][A-Za-z0-9_]*`.
- Every data row must have the same number of fields as the headers.

## Usage

```bash
just load-raw
```

All files are validated before any table changes. If any file is malformed,
no tables are dropped or modified.
