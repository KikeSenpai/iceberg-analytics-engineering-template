MODEL (
  name analytics.rep_sales_funnel_monthly,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column month
  ),
  interval_unit MONTH,
  cron '@monthly',
  start '2024-01-01',
  grain (month, kpi_name, funnel_step),
  audits (
    not_null(columns := (month, kpi_name, funnel_step, deals_count)),
    unique_combination_of_columns(columns := (month, kpi_name, funnel_step)),
    assert_report_contract,
    assert_report_reconciliation
  )
);

WITH funnel_definition (kpi_name, funnel_step, step_order) AS (
  VALUES
    ('Lead Generation', 'Step 1', 1),
    ('Qualified Lead', 'Step 2', 2),
    ('Sales Call 1', 'Step 2.1', 3),
    ('Needs Assessment', 'Step 3', 4),
    ('Sales Call 2', 'Step 3.1', 5),
    ('Proposal/Quote Preparation', 'Step 4', 6),
    ('Negotiation', 'Step 5', 7),
    ('Closing', 'Step 6', 8),
    ('Implementation/Onboarding', 'Step 7', 9),
    ('Follow-up/Customer Success', 'Step 8', 10),
    ('Renewal/Expansion', 'Step 9', 11)
),

event_bounds AS (
  SELECT
    CAST(DATE_TRUNC('month', MIN(event_at)) AS DATE) AS first_month,
    CAST(DATE_TRUNC('month', MAX(event_at)) AS DATE) AS last_month
  FROM intermediate.int_pipedrive__funnel_step_events
),

months AS (
  SELECT generated.month
  FROM event_bounds
  CROSS JOIN UNNEST(
    SEQUENCE(first_month, last_month, INTERVAL '1' MONTH)
  ) AS generated(month)
),

monthly_counts AS (
  SELECT
    CAST(DATE_TRUNC('month', event_at) AS DATE) AS month,
    kpi_name,
    funnel_step,
    COUNT(*) AS deals_count
  FROM intermediate.int_pipedrive__funnel_step_events
  GROUP BY 1, 2, 3
)

SELECT
  months.month,
  funnel_definition.kpi_name,
  funnel_definition.funnel_step,
  COALESCE(monthly_counts.deals_count, 0) AS deals_count
FROM months
CROSS JOIN funnel_definition
LEFT JOIN monthly_counts
  ON months.month = monthly_counts.month
  AND funnel_definition.kpi_name = monthly_counts.kpi_name
  AND funnel_definition.funnel_step = monthly_counts.funnel_step
WHERE months.month BETWEEN CAST(@start_ds AS DATE) AND CAST(@end_ds AS DATE);
