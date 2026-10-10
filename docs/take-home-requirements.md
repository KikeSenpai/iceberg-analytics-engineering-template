# Air Service take-home: original requirements and provenance

This document recovers the **original assignment requirements** for the Air Service
(Air Boltic) take-home exercise and compares them against the solution implemented
on this branch. It exists so a reader can evaluate the implementation against the
assignment it was built for, without access to the original conversation threads.

**Important framing:** this is the *same exercise* implemented on the Iceberg
Analytics Engineering Template. The original assignment text referenced the
*Delta* Analytics Engineering Template (Delta Lake / Spark / dbt); the identical
brief was then re-issued and solved on this repository's Iceberg stack
(Trino / Iceberg / Lakekeeper / MinIO / SQLMesh). The business brief, input
datasets, and analytical requirements are unchanged; only the technology names
differ.

## How these requirements were recovered (provenance of this document)

The original requirements were recovered from two Amp conversation threads and the
data files they reference:

| Source | What it contributes |
|---|---|
| Original solver thread `T-01a05270-0222-74b0-908e-9b8ecf100831` | The verbatim original assignment (business brief, task, conversion rule, validation requirements), written for the Delta template. |
| Iceberg solver thread `T-01a052ce-7f45-751b-87a6-4ac423385cff` | The same exercise re-issued for this Iceberg template, plus its requirement-to-implementation mapping. |
| Input data files in `data/` | The six datasets the assignment supplied via six immutable Amp attachment URLs. |

Throughout this document:

- **Source-derived** means the text is quoted from, or a close paraphrase of, the
  recovered assignment threads. Quoted passages are exact.
- **Inferred clarification** means an interpretation decision made during the
  solution that the original assignment did not state explicitly. These are
  listed separately in [Inferred clarifications](#inferred-clarifications) and
  were **not** part of the original text.

## Original assignment (verbatim, source-derived)

The assignment was delivered as a single instruction message. It read, in full:

> Solve this take-home exercise completely end-to-end in the Delta Analytics
> Engineering Template repository. Do the work yourself and do not create another
> thread. Start from the latest `origin/main`, preserve `main`, create branch
> `take-home/air-service`, commit the completed solution, and push that branch
> automatically. Never merge into or push changes to `main`.
>
> Download and use these input files:
>
> - `trip.csv`
> - `order.csv`
> - `customer_group.csv`
> - `customer.csv`
> - `aeroplane_model.json`
> - `aeroplane.csv`
>
> Convert `aeroplane_model.json` into a clean CSV suitable for the template raw
> loader. Do not add the JSON file to `data/`; add only the converted CSV and
> supplied CSV datasets. Preserve provenance/document the conversion and validate
> row/field fidelity.
>
> **Business brief:**
> Bolt hypothetically launched Air Boltic, a marketplace matching aeroplane
> operators with individuals/groups needing transport. The service wants to
> understand regional growth drivers, customer segments served well, use cases
> (distance, geography, price tier, group/seat size, aircraft type), and
> portfolio-comparable metrics including DAU/WAU/MAU and revenue. It aims to
> facilitate 20% of global aeroplane rides by 2030.
>
> **Task:**
> Design and implement a reliable, scalable, maintainable, user-friendly
> analytical data model for monitoring and self-service analysis. Deliver both
> the implemented model and documentation explaining its design. At minimum:
>
> - Inspect and profile every dataset deeply; infer grain, keys, relationships,
>   timestamps, statuses, units, null behavior, and anomalies from evidence
>   rather than assumptions.
> - Load all raw CSVs through the template's non-dbt raw-loading workflow into
>   the raw schema.
> - Define dbt sources with freshness/tests where supported and useful.
> - Build sensible staging, intermediate, fact, dimension, and reporting/mart
>   layers. Choose grains and history handling appropriate to supplied data and
>   anticipated scale.
> - Support regional growth analysis, customer/customer-group segmentation,
>   route/use-case analysis, aircraft/model analysis, order/seat economics,
>   trips, revenue, and daily/weekly/monthly active users. Define active-user
>   and revenue semantics explicitly.
> - Add robust generic and singular data tests for keys, relationships, accepted
>   values, logical consistency, and important business rules without encoding
>   false assumptions.
> - Provide an ERD (Mermaid is acceptable), model dictionary, grain/key
>   documentation, KPI definitions, assumptions, limitations, and rationale.
> - Keep the solution appropriately scoped to the actual data; clearly identify
>   metrics that cannot be computed reliably.
> - Use Delta/Spark/dbt patterns native to this template; do not replace its
>   architecture.
>
> **Validation:**
> Run the full template workflow and all available checks. If Docker is
> available, start the stack, load raw data, execute dbt build/tests, and query
> representative outputs/KPIs. Resolve failures. If Docker is unavailable, run
> every static/unit check possible and clearly document runtime gaps. Remove
> temporary test artifacts. Verify `main` remains untouched, branch is pushed,
> and report the branch name, commit SHA, validation results, key model outputs,
> assumptions, and any blockers.

The six input files were supplied as immutable Amp attachment URLs (with
`trip.csv`, `order.csv`, `customer_group.csv`, `customer.csv`,
`aeroplane_model.json`, and `aeroplane.csv` as the URL name suffixes). The
downloaded files are committed under `data/`, except the JSON, which the
assignment forbids adding to `data/` in raw form — only its converted CSV
(`data/aeroplane_model.csv`) is committed.

### Re-issued Iceberg variant (source-derived)

The identical exercise was subsequently re-issued for this repository. The
re-issued message restated the same objective ("Solve the Air Service (Air
Boltic) take-home exercise completely end-to-end using the Iceberg Analytics
Engineering Template"), the same six input files, and the same conversion and
provenance rule, with the technology-specific bullets rewritten for the
Iceberg stack:

- Load all raw CSVs through the template's **non-SQLMesh** raw loader into
  `iceberg.raw` (later renamed `prod.raw` across the template — see
  [Inferred clarifications](#inferred-clarifications)).
- Define **SQLMesh external models** (instead of dbt sources) and build
  staging, intermediate, fact, dimension, and mart layers with appropriate
  model kinds, grains, audits, and dependencies.
- Preserve SQLMesh, Trino 476, Iceberg, Lakekeeper, MinIO, and the template
  architecture; do not convert to dbt.
- Add robust **SQLMesh audits/tests** for keys, relationships, domains,
  reconciliation, chronology, and business rules without false assumptions.
- Run `just verify-orb` and the relevant SQLMesh planning/execution/audit
  commands, load the real datasets, materialize all models, query
  representative outputs, and reconcile KPIs against source-level checks.

All other bullets (profiling, layering, analysis coverage, semantics,
documentation deliverables, scoping, and limitations) were carried over
unchanged in substance.

## Source-derived requirement summary

Condensed checklist of what the assignment required, all traceable to the
recovered threads above:

1. **Process:** work end-to-end on branch `take-home/air-service`; never touch
   `main`; commit and push the branch; remove temporary artifacts.
2. **Inputs:** use exactly the six supplied datasets; convert
   `aeroplane_model.json` to a clean CSV suitable for the template raw loader;
   no JSON in `data/`; document conversion provenance and validate row/field
   fidelity.
3. **Profiling:** evidence-based profiling of every dataset — grain, keys,
   relationships, timestamps, statuses, units, null behavior, anomalies.
4. **Loading:** load all raw CSVs through the template's loader outside the
   transformation framework, into the raw schema.
5. **Source declaration:** declare external sources with freshness/tests where
   supported and useful.
6. **Modeling:** staging → intermediate → fact/dimension → reporting/mart
   layers with appropriate grains and history handling.
7. **Analysis coverage:** regional growth, customer and customer-group
   segmentation, route/use-case analysis, aircraft/model analysis, order/seat
   economics, trips, revenue, and daily/weekly/monthly active users, with
   explicit active-user and revenue semantics.
8. **Testing:** robust generic and singular tests for keys, relationships,
   accepted values, logical consistency, and business rules, without encoding
   false assumptions.
9. **Documentation:** ERD, model dictionary, grain/key documentation, KPI
   definitions, assumptions, limitations, and design rationale.
10. **Honest scoping:** keep scope faithful to the actual data; explicitly
    identify metrics that cannot be computed reliably.
11. **Architecture fidelity:** use the template's native stack and patterns;
    do not replace its architecture.
12. **Validation:** run the full template workflow and checks against real
    data; reconcile representative KPIs; report branch name, commit SHA,
    validation results, key outputs, assumptions, and blockers.

## Inferred clarifications

The following are interpretation decisions made while solving the exercise.
They are **not** stated in the original assignment text and are listed so a
reader can separate the assignment from the solver's judgment:

- **Template substitution (Delta → Iceberg).** The original text says
  "Delta/Spark/dbt patterns native to this template" and "non-dbt raw-loading
  workflow". Because this branch implements the same exercise on the Iceberg
  template, the equivalent choices are: SQLMesh replaces dbt, the generic
  `scripts/load_raw.py` loader replaces the Delta template's raw loader, and
  SQLMesh audits/tests replace dbt tests. This substitution was explicit in the
  re-issued Iceberg assignment, not an undocumented change.
- **Raw schema rename (`iceberg.raw` → `prod.raw`).** The re-issued assignment
  named the raw schema `iceberg.raw`. The template later renamed its catalog and
  schema to `prod`, so the current equivalent namespace is `prod.raw`. All six
  raw tables live there today.
- **"Revenue" means listed order value, not accounting revenue.** The data has
  no payments, refunds, fees, or recognition timestamps, so revenue is defined
  as the listed EUR order price by status (finished value as a revenue proxy,
  booked value as pipeline, cancelled as diagnostic).
- **"Active users" is anchored to trip start dates.** No order or login event
  timestamps exist, so DAU/WAU/MAU count distinct customers with active
  (booked/finished) orders attributed to the associated trip's scheduled start
  date. The documentation flags this as not a true event-based DAU/WAU/MAU.
- **"Use case" is limited to observable dimensions.** Distance, passenger
  counts, and trip purpose are not in the data; use-case analysis is expressed
  through geography, price tier, group/seat size, and aircraft type, which the
  data does support.
- **Geography is a maintained mapping.** Cities have no country column in the
  source; a city → country/region mapping (including explicit choices such as
  Moscow → Europe) was added as an intermediate model.
- **Post-completion maintenance instruction.** A later instruction in the
  original thread required rebasing the branch onto current `origin/main` and
  running `just verify-orb` with force-with-lease push. This is housekeeping,
  not a functional requirement, and is recorded only for provenance.

## Original requirements vs. implemented Iceberg solution

| # | Original requirement (source-derived) | Implementation on this branch |
|---|---|---|
| 1 | Branch workflow; `main` untouched | Branch `take-home/air-service`; solution committed on top of `origin/main`; `main` never modified |
| 2 | Six datasets; JSON→CSV conversion, provenance, fidelity validation | `data/` holds five supplied CSVs plus `aeroplane_model.csv`; conversion documented in `docs/data-provenance.md` with SHA-256 checksums and an exact-equality round-trip check (`scripts/validate-model-csv.py`) |
| 3 | Evidence-based profiling | `docs/data-provenance.md` profiles all six sources: grain, keys, relationships, timestamps, statuses, units, nulls, anomalies (e.g. unresolved group IDs 6–10, trips 3/9 cross-midnight end times, missing timezones) |
| 4 | Raw loading outside the transform framework | `scripts/load_raw.py` loads all six files as text into `prod.raw.*` (raw loader unit tests in `scripts/test_load_raw.py`) |
| 5 | Declared sources | `external_models.yaml` declares all six raw tables to SQLMesh |
| 6 | Layered model with grains/history | Staging views (typed/normalized), intermediates (`int_city_geography`, `int_customer_enriched`, `int_order_enriched`, `int_trip_enriched`), dimensions (`dim_aircraft`, `dim_customer`, `dim_customer_group`, `dim_date`, `dim_route`), facts (`fct_order`, `fct_trip`), ten marts; `FULL` kind chosen deliberately with rationale in `docs/air-service-analytics.md` |
| 7 | Analysis coverage + explicit semantics | Marts: `regional_monthly`, `customer_segments`, `route_performance`, `aircraft_performance`, `trip_seat_economics`, `price_tier_performance`, `business_overview`, `customer_activity_daily/_weekly/_monthly`; KPI semantics defined in `docs/air-service-analytics.md` |
| 8 | Tests without false assumptions | `audits/data_quality.sql`, `audits/relationships.sql`, `tests/test_business_logic.yaml` (73 audits, 3 SQLMesh tests passing at validation time) |
| 9 | ERD, dictionary, KPIs, assumptions, limitations | `docs/air-service-analytics.md` (Mermaid ERD, model dictionary with grains, KPI definitions, limitations) |
| 10 | Identify unreliable metrics | Documented exclusions: accounting revenue/take-rate, true event-based DAU/WAU/MAU, retention/LTV, lead time, timezone-safe duration, distance feasibility, passenger/load factor, customer geography, use case, multi-period growth |
| 11 | Template architecture preserved | SQLMesh + Trino 476 + Iceberg + Lakekeeper + MinIO stack unchanged; no dbt |
| 12 | Full workflow validation with real data | `just verify-orb` plus SQLMesh plan/run/test passed; 6 raw files loaded (10 aeroplanes, 19 models, 20 customers, 5 groups, 20 orders, 20 trips); 29 loader tests; KPI reconciliation against source-level checks: 20 trips, 20 orders, €18,900 finished value, €9,900 booked pipeline, €30,200 gross listed value |

## Where to look next

- `docs/data-provenance.md` — input provenance, conversion validation, and the
  evidence-based source profiles.
- `docs/air-service-analytics.md` — analytical design, ERD, model dictionary,
  KPI semantics, and limitations.
