# Raw Data Directory

Place CSV files here to load them into `prod.raw.<table_name>`.

These six CSVs are the complete supplied Pipedrive extract. There is no deals
table. The supplied `load_data.sh` confirms the same one-file/one-table contract
for its PostgreSQL example, but this stack uses the native loader below.

## Convention

- Each `*.csv` file becomes a table named after its filename (without extension).
- Example: `data/orders.csv` → `prod.raw.orders`
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
