# Air Service (Air Boltic) Take-Home Test

Welcome. This is the assignment for the analytics engineer take-home test. You
will design and implement an analytical data model for **Air Boltic**, a
hypothetical Bolt venture, using this repository's Iceberg analytics stack:
Trino 476, Apache Iceberg, Lakekeeper, MinIO, and SQLMesh.

## Business context

Bolt has launched **Air Boltic**, a marketplace that matches aeroplane
operators with individuals and groups who need transport. The service wants to
understand:

- regional growth drivers,
- the customer segments it serves well,
- its use cases (geography, price tier, group/seat size, aircraft type),
- portfolio-comparable metrics, including DAU/WAU/MAU and revenue.

Air Boltic aims to facilitate 20% of global aeroplane rides by 2030. Your model
is the foundation for monitoring and self-service analysis toward that goal.

## Inputs

Six datasets are provided in `data/`:

| File | Content |
|---|---|
| `trip.csv` | Scheduled aeroplane trips |
| `order.csv` | Customer seat orders against trips |
| `customer.csv` | Customers |
| `customer_group.csv` | Customer groups |
| `aeroplane.csv` | Aircraft in the fleet |
| `aeroplane_model.csv` | Aircraft model specifications, converted from a supplied `aeroplane_model.json` |

Convert the supplied `aeroplane_model.json` into a clean CSV suitable for the
template raw loader, and commit only the converted CSV. Do not add the JSON
file to `data/`. Document the conversion and validate row/field fidelity.

## Required deliverables

1. **Profiled sources.** Inspect and profile every dataset deeply; infer grain,
   keys, relationships, timestamps, statuses, units, null behavior, and
   anomalies from evidence rather than assumptions.
2. **Raw loading.** Load all raw CSVs through the template's non-SQLMesh raw
   loading workflow into the raw schema.
3. **Declared sources.** Define SQLMesh external models with freshness/tests
   where supported and useful.
4. **Layered model.** Build sensible staging, intermediate, fact, dimension,
   and reporting/mart layers. Choose grains and history handling appropriate to
   the supplied data and anticipated scale.
5. **Analysis coverage.** Support regional growth analysis,
   customer/customer-group segmentation, route/use-case analysis,
   aircraft/model analysis, order/seat economics, trips, revenue, and
   daily/weekly/monthly active users. Define active-user and revenue semantics
   explicitly.
6. **Data quality.** Add robust generic and singular data tests for keys,
   relationships, accepted values, logical consistency, and important business
   rules, without encoding false assumptions.
7. **Documentation.** Provide an ERD (Mermaid is acceptable), a model
   dictionary, grain/key documentation, KPI definitions, assumptions,
   limitations, and design rationale.
8. **Honest scoping.** Keep the solution appropriately scoped to the actual
   data; clearly identify metrics that cannot be computed reliably.

Deliver both the implemented model and the documentation explaining its design.

## Constraints

- Work on the branch `take-home/air-service` starting from the latest
  `origin/main`. Never merge into or push changes to `main`.
- Preserve the template architecture — SQLMesh, Trino, Iceberg, Lakekeeper,
  MinIO — and use patterns native to it. Do not replace it with another
  framework.
- Keep the solution reliable, scalable, maintainable, and user-friendly for
  monitoring and self-service analysis.
- Remove any temporary test artifacts before finishing.

## Validation

Run the full template workflow and all available checks. If Docker is
available, start the stack, load raw data, run the SQLMesh plan, run, and
audit/test commands, and query representative outputs and KPIs. Resolve any
failures. If Docker is unavailable, run every static and unit check possible
and clearly document runtime gaps.

## Acceptance criteria

- All six datasets are loaded into the raw schema through the template loader,
  including the converted `aeroplane_model.csv`; the JSON is not committed to
  `data/`.
- All models materialize end to end via `just verify` (or `just verify-orb`
  in an Amp orb) against the real datasets, with audits and tests passing.
- The layered model covers the analysis areas listed above, and every KPI in
  scope has explicitly defined semantics.
- Documentation includes the ERD, model dictionary, grain/key documentation,
  KPI definitions, assumptions, limitations, and rationale.
- Metrics that cannot be computed reliably are identified as such.
- `main` remains untouched; the branch is pushed; the completion report states
  the branch name, commit SHA, validation results, key model outputs,
  assumptions, and any blockers.
