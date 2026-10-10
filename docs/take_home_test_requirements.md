# Pipedrive Senior Analytics Engineer — Take-Home Exercise

Welcome. This is the assignment for the Senior Analytics Engineer role. You
will build a monthly sales-funnel report from a Pipedrive CRM extract on our
Iceberg analytics platform. Everything you need is in this document and in the
supplied data.

## Business context

You are completing this exercise for Vattenfall. Vattenfall's sales leadership
reviews pipeline movement month by month. They want a single trustworthy
report that shows, for each calendar month, how many deals entered each stage
of the sales funnel. The data comes from Vattenfall's Pipedrive CRM, but as a
raw change-and-activity extract rather than a clean deal snapshot: you will
need to reconstruct deal identity and funnel progression from the change
history and activity log yourself.

## Inputs

Six CSV extracts are the complete source data. There is **no deals table** —
do not invent one. Deal-level truth lives in the change history and activity
log.

| File | Contents |
|---|---|
| `data/users.csv` | CRM users (owners) |
| `data/stages.csv` | Pipeline stage definitions |
| `data/fields.csv` | Custom field metadata |
| `data/deal_changes.csv` | Deal change history (stage moves, owner changes, creation) |
| `data/activity.csv` | Activities (calls, meetings) |
| `data/activity_types.csv` | Activity type definitions |

A reference loading script, `load_data.sh`, may be provided alongside the
data. Use it to understand source semantics only; load the CSVs through this
template's native raw loader.

## Required output

Build one reporting model:

- **Name:** `rep_sales_funnel_monthly`
- **Intervals:** monthly
- **Exact columns:** `month`, `kpi_name`, `funnel_step`, `deals_count`
- **Rows:** one row per month per funnel step, with these funnel steps and KPI
  names in this exact order and wording:

| funnel_step | kpi_name |
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

You decide and must document what each monthly count means — for example,
entry events, distinct deals reaching a step, or a month-end snapshot. Whichever
semantic you choose, it must be defensible from the data and must not
double-count repeated changes or activities.

If a KPI cannot be derived faithfully from the supplied data, do not fabricate
it. Implement the most defensible evidence-based mapping, flag the limitation
in your documentation, and expose unmapped records in a diagnostic so the gap
is visible rather than silent.

## Deliverables

1. A working `rep_sales_funnel_monthly` model built with SQLMesh on the
   template's Trino/Iceberg stack.
2. Data loaded into the raw layer through the template's native raw loader.
3. External model declarations plus maintainable staging, intermediate, and
   reporting layers with appropriate model kinds.
4. Tests and audits covering grain, uniqueness, relationships, accepted
   values, chronology, nulls, and funnel mapping coverage.
5. A solution document explaining your source understanding, architecture,
   funnel-step mappings, KPI semantics, assumptions, and limitations.
6. All work committed to the `take-home/pipedrive-sales-funnel` branch. Never
   merge into or push to `main`.

## Constraints

- Preserve the template stack: SQLMesh, Trino 476, Iceberg, Lakekeeper, and
  MinIO. Do not convert to dbt or replace the architecture.
- The six CSVs are the complete source data; do not fabricate a deals dataset.
- Use deterministic deduplication and correct date handling.
- Use the template's existing commands (`just` recipes) for loading, planning,
  running, testing, and verification rather than ad-hoc scripts.

## Validation

Before submitting, run the template's full verification workflow, confirm the
raw tables load idempotently, query `rep_sales_funnel_monthly` to confirm the
exact columns, grain, and representative months, and reconcile report totals
against source-level counts.

## Acceptance criteria

You will be evaluated on:

1. **Correct contract** — `rep_sales_funnel_monthly` exists with the exact
   four columns and all eleven steps, correctly named and ordered.
2. **Evidence-based modeling** — deal identity and funnel-step mappings are
   reconstructed from the data and documented with evidence, not guessed.
3. **Data integrity** — no double counting; deterministic deduplication;
   relationships and chronology hold; tests and audits pass.
4. **Honesty about limits** — non-derivable KPIs are flagged, not fabricated;
   unmapped records are visible.
5. **Craft** — clean layering, maintainable models, documentation a colleague
   can follow, and a green end-to-end verification run.
