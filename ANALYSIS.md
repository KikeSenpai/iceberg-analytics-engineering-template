# Pipedrive sales funnel analysis

## Reporting contract

`analytics.rep_sales_funnel_monthly` has exact grain `(month, kpi_name,
funnel_step)`. It counts each reconstructed entity once, in the calendar month
of its first observed entry into that step. This is an entry-event report, not
a month-end pipeline snapshot. Every month from the earliest through latest
mapped event contains all 11 required steps; absent events produce zero.

Stage event time is `deal_changes.change_time`. Sales Calls count only active,
completed activities; `activity.due_to` is their event-time proxy because no
completion timestamp exists. `ROW_NUMBER` ordered by event time and stable
source key prevents repeated entity/step events from double-counting.

## Profile and identity evidence

- `deal_changes`: 15,406 rows, 1,995 literal `deal_id` values, 2,000 `add_time`
  records, 8,906 stage events, and no exact duplicate rows.
- Five deal IDs are reused for two lifecycles. Every one of 15,406 changes has
  exactly one creation record with the same time-of-day signature; each
  signature's stage sequence is monotonic and has no repeated stage. Therefore
  `(deal_id, add_time)` is the deal episode identity. A normal effective-date
  range would be wrong because reused episodes overlap in calendar time.
- All stage changes occur on or after episode creation and resolve to one of
  the nine supplied stages. All owner changes resolve to supplied users.
- `activity`: 4,579 rows, 4,568 activity IDs, and no exact duplicate rows. The
  11 reused activity IDs represent different full records, so the stable row
  key hashes every supplied field instead of discarding valid records.
- Only 8 activity rows have a `deal_id` present in `deal_changes`; 4,571 do not.
  Calls retain their supplied deal identity in an independent namespace rather
  than claiming false continuity with stage episodes.
- All activity owner and type references resolve. The extract spans mapped
  events from January 2024 through February 2025.

## Evidence-based mapping

| Funnel step | KPI | Source evidence |
|---|---|---|
| Step 1 | Lead Generation | `deal_changes.stage_id=1`; stages and field metadata |
| Step 2 | Qualified Lead | `stage_id=2`; source stage name differs only in case |
| Step 2.1 | Sales Call 1 | done activity type `meeting`, named by activity types |
| Step 3 | Needs Assessment | `stage_id=3` |
| Step 3.1 | Sales Call 2 | done activity type `sc_2`, named by activity types |
| Step 4 | Proposal/Quote Preparation | `stage_id=4` |
| Step 5 | Negotiation | `stage_id=5` |
| Step 6 | Closing | `stage_id=6` |
| Step 7 | Implementation/Onboarding | `stage_id=7` |
| Step 8 | Follow-up/Customer Success | `stage_id=8` |
| Step 9 | Renewal/Expansion | `stage_id=9` |

Inactive `Follow Up Call` does not substitute for stage 8. Active `After Close
Call` has no requested KPI and is excluded. `lost_reason`, owner changes, user
details, and field metadata support lifecycle interpretation and integrity but
are not funnel entry events. `intermediate.int_pipedrive__unmapped_records`
exposes unlinked activity deals and activity types excluded from requested KPIs.

## Architecture and controls

The native loader creates six Iceberg v2/Parquet tables in `prod.raw`.
`external_models.yaml` declares that boundary. Typed staging views feed full
deal-episode, funnel-event, and exception tables. Monthly reporting uses
SQLMesh `INCREMENTAL_BY_TIME_RANGE` with monthly intervals.

Blocking audits enforce nullability, grains, keys, field domains, user/stage/
activity-type relationships, one lifecycle assignment per change, chronology,
mapping contract, event reconciliation, 11-row month completeness, and report
reconciliation. SQLMesh unit tests cover reused-step deduplication and a
zero-filled report month. Loader unit tests cover identifier and literal safety.

`just verify-orb` produced 10,034 reconciled events: 8,906 stage entries and
1,128 completed Sales Calls. The report contains 154 rows (14 months × 11
steps). Lifetime counts in funnel order are 2,000; 1,483; 568; 1,308; 560;
1,087; 895; 741; 588; 479; and 325. The exception model exposes 4,571 activity
rows lacking a deal-change counterpart and 2,310 activity rows whose types are
not requested KPIs. Loading all six CSVs twice leaves source row counts
unchanged, demonstrating destructive-rebuild idempotency.

Run end to end:

```bash
just orb-setup
just verify-orb
```

For an already-running stack: `just load-raw && just plan-auto && just run &&
just test`. Query with `just orb-trino-query "SELECT * FROM
prod.analytics.rep_sales_funnel_monthly"`.

## Limitations

- No deals snapshot, status, revenue, won time, or explicit close result exists.
  Current pipeline, conversion, revenue, and win-rate metrics cannot be derived.
- `due_to` is scheduled time, not proven completion time. Calls are completed
  as of extract but grouped by scheduled month.
- Missing cross-source deal continuity means per-step volume is defensible;
  end-to-end journeys and call-to-stage conversion are not.
- Source timestamps have no timezone. They are treated consistently as naive
  timestamps and should not be presented as UTC without source confirmation.
