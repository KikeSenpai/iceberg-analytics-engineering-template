MODEL (
  name intermediate.int_pipedrive__funnel_step_events,
  kind FULL,
  grain (funnel_entity_key, funnel_step),
  audits (
    not_null(columns := (event_key, funnel_entity_key, event_at, kpi_name, funnel_step, event_source)),
    unique_values(columns := (event_key)),
    unique_combination_of_columns(columns := (funnel_entity_key, funnel_step)),
    assert_funnel_event_contract,
    assert_funnel_event_reconciliation
  )
);

WITH stage_events AS (
  SELECT
    CONCAT('stage|', source_changes.deal_change_key) AS event_key,
    CONCAT('deal_episode|', episodes.deal_episode_key) AS funnel_entity_key,
    source_changes.changed_at AS event_at,
    CASE TRY_CAST(source_changes.new_value AS INTEGER)
      WHEN 1 THEN 'Lead Generation'
      WHEN 2 THEN 'Qualified Lead'
      WHEN 3 THEN 'Needs Assessment'
      WHEN 4 THEN 'Proposal/Quote Preparation'
      WHEN 5 THEN 'Negotiation'
      WHEN 6 THEN 'Closing'
      WHEN 7 THEN 'Implementation/Onboarding'
      WHEN 8 THEN 'Follow-up/Customer Success'
      WHEN 9 THEN 'Renewal/Expansion'
    END AS kpi_name,
    CONCAT('Step ', source_changes.new_value) AS funnel_step,
    'deal_stage' AS event_source
  FROM staging.stg_pipedrive__deal_changes AS source_changes
  INNER JOIN intermediate.int_pipedrive__deal_episodes AS episodes
    ON source_changes.deal_id = episodes.deal_id
    AND EXTRACT(HOUR FROM source_changes.changed_at) * 3600
      + EXTRACT(MINUTE FROM source_changes.changed_at) * 60
      + EXTRACT(SECOND FROM source_changes.changed_at) = episodes.lifecycle_time_signature
  INNER JOIN staging.stg_pipedrive__stages AS stages
    ON TRY_CAST(source_changes.new_value AS INTEGER) = stages.stage_id
  WHERE source_changes.changed_field_key = 'stage_id'
),

sales_call_events AS (
  SELECT
    CONCAT('activity|', activities.activity_record_key) AS event_key,
    CONCAT('activity_deal|', CAST(activities.deal_id AS VARCHAR)) AS funnel_entity_key,
    activities.due_at AS event_at,
    activity_types.activity_type_name AS kpi_name,
    CASE activity_types.activity_type_name
      WHEN 'Sales Call 1' THEN 'Step 2.1'
      WHEN 'Sales Call 2' THEN 'Step 3.1'
    END AS funnel_step,
    'completed_activity' AS event_source
  FROM staging.stg_pipedrive__activities AS activities
  INNER JOIN staging.stg_pipedrive__activity_types AS activity_types
    ON activities.activity_type = activity_types.activity_type
  WHERE
    activities.is_done
    AND activity_types.is_active
    AND activity_types.activity_type_name IN ('Sales Call 1', 'Sales Call 2')
),

all_events AS (
  SELECT * FROM stage_events
  UNION ALL
  SELECT * FROM sales_call_events
),

ranked_events AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY funnel_entity_key, funnel_step
      ORDER BY event_at, event_key
    ) AS event_order
  FROM all_events
)

SELECT
  event_key,
  funnel_entity_key,
  event_at,
  kpi_name,
  funnel_step,
  event_source
FROM ranked_events
WHERE event_order = 1;
