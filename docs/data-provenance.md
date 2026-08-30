# Data provenance and profiling

## Provenance

Files were downloaded from the six immutable Amp attachment URLs supplied with the exercise. `data/` contains only the five supplied CSVs and the CSV converted from the supplied JSON.

| File | Source SHA-256 | Rows | Columns |
|---|---|---:|---:|
| `aeroplane.csv` | `b56f699ab8c3e0d4d01cb7804e08ed051062cfc758935b5c844d6e6550fe406b` | 10 | 3 |
| `aeroplane_model.csv` | `c05a2c09a24fb318bf1687677098ce7a92f1771465e8f362d8152963cd6e44ae` | 19 | 6 |
| `customer.csv` | `18a62d3c03aa8cc529c0b9ea41a175ae862def81b5f49e893cb0c99fbfbadf41` | 20 | 5 |
| `customer_group.csv` | `249fe740ac7d1fc5bd519f7a50822c34b674d2f51f0fa70fa676af3bf28a278e` | 5 | 4 |
| `order.csv` | `9d8557664b0e4503ec327d21bcfc10d15aeef739a1589bd0dc919d026a0c6fed` | 20 | 6 |
| `trip.csv` | `d14f672a72c932da96719b60e297026f30bab7a6a0f15735449b76f3287fed01` | 20 | 6 |

The original `aeroplane_model.json` SHA-256 is `b91a1b319b31aa00e27de8f93aef382db11c8843b9eae865098ea5c8b4d499c8`. Conversion flattened the hierarchy `manufacturer -> model -> attributes` into columns `manufacturer, model, max_seats, max_weight, max_distance, engine_type`, preserving source iteration order and native scalar values. Validation reconstructed the JSON object from CSV and compared it for exact Python equality: 9 manufacturers, 19 models, and 76 attributes matched. Re-run with:

```bash
uv run python scripts/validate-model-csv.py /path/to/aeroplane_model.json
```

The JSON is intentionally not committed or copied into `data/`.

## Evidence-based source profile

### `trip.csv`

- Grain/key: one scheduled trip per `Trip ID`; 20 rows, 20 distinct non-null IDs.
- Relationships: all 20 `Airplane ID` values resolve to `aeroplane`; each of 10 aircraft appears twice.
- Timestamps: local-looking timestamp strings from 2024-08-01 through 2024-08-28. No timezone is supplied. Trips 3 and 9 have an end clock value earlier than their start clock value on the same nominal date; this is compatible with cross-timezone travel but cannot be distinguished from bad data.
- Routes: 20 distinct origin cities and 20 distinct directional routes; 18 destination cities. No origin equals its destination.
- Nulls: none. No distance, trip status, operator, creation timestamp, or timezone.

### `order.csv`

- Grain/key: one customer-seat order per `Order ID`; 20 rows, 20 distinct non-null IDs and 20 distinct seat labels.
- Relationships: all customer and trip references resolve. Orders cover 8 of 20 trips; 12 trips have no order rows. Each customer appears exactly once in this sample.
- Status domain: 13 `Finished`, 5 `Booked`, 2 `Cancelled`.
- Price: integer-looking EUR values loaded as decimal; range EUR 500–2,500; total EUR 30,200. Finished value is EUR 18,900, booked pipeline is EUR 9,900, and cancelled value is EUR 1,400.
- Nulls: none. No quantity, payment/refund record, fee, tax, currency conversion, or order/status timestamp.

### `customer.csv`

- Grain/key: one current customer per `Customer ID`; 20 rows, 20 distinct non-null IDs and names.
- Group references: 14 non-null values. Seven references resolve to groups 1–5; seven customer rows reference absent group IDs 6–10. Six customers have no group ID.
- Contact quality: 2 null emails, 3 null phones, and trailing whitespace in 17 email source values. Staging trims and lowercases email while retaining nulls.
- No signup timestamp, geography, demographic attributes, consent state, or history.

### `customer_group.csv`

- Grain/key: one current group per `ID`; 5 rows and 5 distinct non-null IDs.
- Type domain: 3 Company, 1 Private Group, 1 Organisation. Registry number is missing for the private group and is alphanumeric for one organisation, so it remains text.
- Group membership is inferred by counting customer foreign keys that resolve; this is not contractual group size.

### `aeroplane.csv`

- Grain/key: one aircraft per `Airplane ID`; 10 rows and 10 distinct non-null IDs.
- Models: 6 distinct manufacturer/model pairs across 5 manufacturers. Every pair resolves to the model reference data.
- Fleet identifiers are sample IDs, not registration/tail numbers. Operator and ownership are absent.

### `aeroplane_model.csv`

- Grain/key: one model per `(manufacturer, model)`; 19 unique models across 9 manufacturers.
- Attributes: all 114 CSV cells are populated. `max_seats`, `max_weight`, and `max_distance` are positive integer values. Source labels do not state weight/distance units; values are retained without invented unit names.
- Model names are globally unique in this sample, but the model uses the safer manufacturer/model composite key.
