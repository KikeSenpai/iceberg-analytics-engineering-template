# Pipedrive Senior Analytics Engineer take-home — original requirements

This document recovers the original assignment requirements for the Pipedrive
sales funnel take-home exercise and maps them against the Iceberg solution
implemented on the `take-home/pipedrive-sales-funnel` branch. It exists so a
reader can compare what was originally asked against what was built, without
needing access to the original conversation threads.

**This is the same exercise, implemented on Iceberg.** The assignment was
first solved on the Delta Analytics Engineering Template and was then re-solved
on this repository's Iceberg template (SQLMesh, Trino 476, Iceberg, Lakekeeper,
MinIO). The functional requirements below are identical in both; only the
technology instructions differ, because each solver thread adapted the
operational wording to its template's stack.

## Provenance and confidence

Requirements were recovered from two Amp solver threads and the original data
attachments they reference:

- Source A — original solver thread `T-01a05270-07eb-746c-987d-ed7d128fc652`
  (Delta template solve). Contains the earliest recorded statement of the
  assignment.
- Source B — Iceberg solver thread `T-01a052ce-8496-7790-a1d8-04e723a881e8`
  (this repository's solve). Contains the restated assignment for the Iceberg
  template and the delivered solution.
- Source C — the six supplied CSV datasets and `load_data.sh` reference script,
  attached to both threads and copied into `data/` in this repository.

Labelling used below:

- **[Source]** — quoted or paraphrased directly from the recorded assignment
  text in the threads. Preserved faithfully, including constraints that the
  implementation may interpret differently.
- **[Inferred]** — a clarification or interpretation made during recovery or
  implementation that is not stated in the original text. Kept separate so the
  original requirements are never silently rewritten.

No deadline, time limit, or turnaround requirement appears in either recorded
statement of the assignment.

## Original data inputs [Source]

The assignment supplied seven attachments: six CSV datasets plus one reference
script.

| File | Role per assignment |
|---|---|
| `users.csv` | CRM users |
| `stages.csv` | Pipeline stages |
| `fields.csv` | Custom field metadata |
| `deal_changes.csv` | Deal change history |
| `activity.csv` | Activities |
| `activity_types.csv` | Activity type definitions |
| `load_data.sh` | Reference loading script — *not* a dataset; inspect for source semantics only |

Explicit constraints stated in the assignment:

- "The six CSV datasets — users, stages, fields, deal_changes, activity, and
  activity_types — are the complete supplied source data. **There is no
  separate deals table.**" Solver must not invent a missing deals dataset.
- Use the template's native non-dbt raw loader (Delta wording) / native raw
  loader (Iceberg wording); treat `load_data.sh` as reference input, not a
  component to run.

## Deliverable [Source]

Build a single reporting model, `rep_sales_funnel_monthly`:

- **Intervals:** monthly.
- **Exact reporting columns:** `month`, `kpi_name`, `funnel_step`,
  `deals_count` — no more, no fewer.
- **Required funnel steps / KPIs, in this order:**

  | funnel_step | KPI name |
  |---|---|
  | Step 1 | Lead Generation |
  | Step 2 | Qualified Lead |
  | Step 2.1 | Sales Call 1 |
  | Step 3 | Needs Assessment |
  | Step 3.1 | Sales Call 2 |
  | Step 4 | Proposal/Quote Preparation |
  | Step 5 | Negotiation |
  | Step 6 | Closing |
  | Step 7 | Implementation/Onboarding |
  | Step 8 | Follow-up/Customer Success |
  | Step 9 | Renewal/Expansion |

  The Delta thread words these as "Step 1: Lead Generation … Step 9:
  Renewal/Expansion"; the Iceberg thread lists them without the "Step n:"
  prefixes but in the same order. Both threads agree on the eleven names, the
  2.x/3.x sub-steps, and the column contract.

## Required modeling work [Source]

1. Remove any test/demo model after confirming the environment works.
2. Profile and deeply understand all Pipedrive CRM source data. Research
   Pipedrive terminology only where useful; let the supplied data determine
   semantics.
3. Define sources (dbt sources on Delta; SQLMesh external models on Iceberg)
   and build appropriate staging / intermediate / reporting layers for
   relevance and maintainability.
4. Load the six CSVs through the template workflow; do not invent a missing
   deals dataset.
5. Reverse-engineer deal identity and lifecycle events from `deal_changes`,
   stages, fields, activities, and activity types. Document evidence for the
   mappings, especially how each required funnel step is represented.
6. Decide and explicitly document whether monthly counts represent entry
   events, distinct deals reaching a step, current snapshots, or another
   defensible semantic. Avoid double-counting repeated changes/activities.
7. If any requested KPI cannot be derived faithfully, do not fabricate it:
   implement the most defensible evidence-based mapping, clearly flag
   limitations, and include tests/diagnostics that expose unmapped records.
8. Use deterministic deduplication and appropriate date handling.
9. Add source/model descriptions and tests for grain, uniqueness,
   relationships, accepted values, chronology, nulls, and funnel mapping
   coverage.
10. Ensure all required funnel rows/order labels are represented consistently
    when justified by the data, including months/steps with zero deals if that
    is the chosen reporting contract.
11. Add a concise README or analysis document explaining source understanding,
    architecture, mappings, KPI semantics, assumptions, limitations, and how
    to run/validate the solution.
12. Use the template's native patterns (Delta/Spark/dbt on the original solve;
    SQLMesh/Trino/Iceberg here); do not replace its architecture.

## Validation requirements [Source]

- Run the full template workflow and all available checks.
- Start the stack, load real raw data, build/test the models, and query
  `rep_sales_funnel_monthly` to verify exact columns, grain, counts, and
  representative months.
- Reconcile report outputs against source-level checks.
- On the Iceberg solve specifically: run the stack end-to-end (`just
  verify-orb` on that solve; `just verify` is this template's equivalent),
  verify one row per required step per month, and confirm loader idempotency.
- Remove temporary artifacts.
- Verify `main` remains untouched; deliver on branch
  `take-home/pipedrive-sales-funnel`, committed and pushed; never merge into
  or push to `main`.
- Report branch name, commit SHA, validation results, row/count checks,
  assumptions, and blockers.

## Stack constraints (per template) [Source]

Both threads state the architecture constraint in their own template's terms.
The functional requirement — preserve the template's stack, do not replace it —
is the same in both:

- Original (Delta) wording: use Delta/Spark/dbt patterns native to that
  template.
- Iceberg wording: "Preserve SQLMesh, Trino 476, Iceberg, Lakekeeper, MinIO,
  and existing architecture. Do not convert to dbt."

## Inferred clarifications [Inferred]

The following points were settled during recovery or implementation and are
recorded here as interpretations, not original requirements:

- **Monthly semantic chosen:** entry-event counting — each reconstructed deal
  episode is counted once, in the calendar month of its first observed entry
  into each step. This is one of the semantics the assignment explicitly
  permits ("decide and explicitly document"); the assignment does not mandate
  one.
- **Zero rows:** the report fills a complete 11-step spine for every month
  from the earliest to the latest mapped event, including zero counts. The
  assignment makes this conditional ("if that is the chosen reporting
  contract").
- **KPI-to-source mapping:** stages 1–9 of `stages.csv` map directly to Steps
  1–8 and 9; Sales Call 1 (Step 2.1) maps to completed activities of type
  `meeting` and Sales Call 2 (Step 3.1) to completed activities of type
  `sc_2`, as named by `activity_types.csv`. The assignment requires evidence
  for mappings but does not prescribe them.
- **Excluded sources of KPIs:** inactive `Follow Up Call` activities do not
  stand in for Step 8; active `After Close Call` is excluded because no
  requested KPI corresponds to it. This follows directly from the
  "do not fabricate" rule but the specific exclusions are implementation
  decisions.
- **No-status consequence:** because no deals snapshot, won/lost status,
  revenue, or close result exists in the data, conversion-rate, win-rate,
  pipeline-value, and revenue KPIs are declared not derivable rather than
  approximated. This is the "do not fabricate" rule applied, not a new
  requirement.
- **Timestamps:** source timestamps carry no timezone and are treated as
  naive values throughout. The assignment does not address timezones.
- **Catalog naming:** a later instruction on the Iceberg thread superseded
  `iceberg.*` catalog references with `prod.*`, noting that the Trino catalog
  name and the Lakekeeper warehouse name are distinct concepts that both
  happen to be named `prod`.

## Original requirements vs. Iceberg implementation

| Original requirement [Source] | Where implemented |
|---|---|
| Six CSVs are the complete source data; no deals table | `data/*.csv` loaded verbatim into `prod.raw.*` by `scripts/load_raw.py`; no deals table invented |
| Use the template's native raw loader | `scripts/load_raw.py` + `just load-raw` (generic CSV-to-Iceberg loader, destructive-rebuild idempotent) |
| Define external sources with contracts | `external_models.yaml` |
| Staging / intermediate / reporting layers | `models/staging/stg_pipedrive__*` (6 views), `models/intermediate/int_pipedrive__{deal_episodes,funnel_step_events,unmapped_records}.sql`, `models/reporting/rep_sales_funnel_monthly.sql` |
| Reverse-engineer deal identity and lifecycle | `int_pipedrive__deal_episodes`: `(deal_id, add_time)` episode identity, justified by time-of-day signature analysis of reused deal IDs |
| Deterministic deduplication, no double counting | `ROW_NUMBER` over event time and stable source keys; first event per (entity, step) retained |
| Explicit, documented monthly semantic | Entry-event report; documented in `ANALYSIS.md` ("Reporting contract") |
| `rep_sales_funnel_monthly`, exact 4 columns, 11 steps | `models/reporting/rep_sales_funnel_monthly.sql` |
| Zero months/steps included | Full 11-step spine per month from earliest to latest mapped event |
| Tests/audits: grain, uniqueness, relationships, domains, chronology, nulls, mapping coverage, reconciliation | `audits/pipedrive.sql` (blocking audits), `tests/test_pipedrive_models.yaml` (SQLMesh unit tests) |
| Diagnostics for unmapped records | `int_pipedrive__unmapped_records` |
| Concise analysis documentation | `ANALYSIS.md` |
| Remove demo model after proving the environment works | `models/raw/orders.sql`, `models/staging/stg_orders.sql`, and `seeds/orders.csv` removed |
| Preserve template stack; do not convert to dbt | SQLMesh + Trino 476 + Iceberg + Lakekeeper + MinIO unchanged |
| Deliver on `take-home/pipedrive-sales-funnel`, never touch `main` | Branch-only delivery; `main` untouched |
| Verify end-to-end and reconcile | `just verify` on this template (the solve used `just verify-orb`): 154 report rows (14 months × 11 steps), 8,906 stage events + 1,128 completed Sales Calls reconciled; loader idempotency confirmed by loading twice |

## Where to read next

- `ANALYSIS.md` — the implemented solution's own analysis: profiling evidence,
  mappings, contract, limitations, and run instructions.
- `README.md` — template overview and commands.
