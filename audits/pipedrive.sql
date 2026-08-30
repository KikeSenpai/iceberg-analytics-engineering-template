AUDIT (
  name assert_deal_change_relationships
);

SELECT changes.*
FROM @this_model AS changes
LEFT JOIN staging.stg_pipedrive__fields AS fields
  ON changes.changed_field_key = fields.field_key
LEFT JOIN staging.stg_pipedrive__stages AS stages
  ON changes.changed_field_key = 'stage_id'
  AND TRY_CAST(changes.new_value AS INTEGER) = stages.stage_id
LEFT JOIN staging.stg_pipedrive__users AS users
  ON changes.changed_field_key = 'user_id'
  AND TRY_CAST(changes.new_value AS BIGINT) = users.user_id
WHERE
  fields.field_key IS NULL
  OR (changes.changed_field_key = 'stage_id' AND stages.stage_id IS NULL)
  OR (changes.changed_field_key = 'user_id' AND users.user_id IS NULL);

AUDIT (
  name assert_activity_relationships
);

SELECT activities.*
FROM @this_model AS activities
LEFT JOIN staging.stg_pipedrive__activity_types AS activity_types
  ON activities.activity_type = activity_types.activity_type
LEFT JOIN staging.stg_pipedrive__users AS users
  ON activities.assigned_user_id = users.user_id
WHERE activity_types.activity_type IS NULL OR users.user_id IS NULL;

AUDIT (
  name assert_deal_episode_reconciliation
);

WITH assigned_changes AS (
  SELECT
    changes.deal_change_key,
    changes.changed_field_key,
    changes.changed_at,
    COUNT(episodes.deal_episode_key) AS episode_matches,
    MIN(episodes.created_at) AS created_at
  FROM staging.stg_pipedrive__deal_changes AS changes
  LEFT JOIN @this_model AS episodes
    ON changes.deal_id = episodes.deal_id
    AND EXTRACT(HOUR FROM changes.changed_at) * 3600
      + EXTRACT(MINUTE FROM changes.changed_at) * 60
      + EXTRACT(SECOND FROM changes.changed_at) = episodes.lifecycle_time_signature
  GROUP BY 1, 2, 3
)

SELECT *
FROM assigned_changes
WHERE
  episode_matches <> 1
  OR (changed_field_key = 'stage_id' AND changed_at < created_at);

AUDIT (
  name assert_funnel_event_contract
);

SELECT events.*
FROM @this_model AS events
LEFT JOIN intermediate.int_pipedrive__deal_episodes AS episodes
  ON events.funnel_entity_key = CONCAT('deal_episode|', episodes.deal_episode_key)
WHERE
  NOT (
    (events.kpi_name = 'Lead Generation' AND events.funnel_step = 'Step 1')
    OR (events.kpi_name = 'Qualified Lead' AND events.funnel_step = 'Step 2')
    OR (events.kpi_name = 'Sales Call 1' AND events.funnel_step = 'Step 2.1')
    OR (events.kpi_name = 'Needs Assessment' AND events.funnel_step = 'Step 3')
    OR (events.kpi_name = 'Sales Call 2' AND events.funnel_step = 'Step 3.1')
    OR (events.kpi_name = 'Proposal/Quote Preparation' AND events.funnel_step = 'Step 4')
    OR (events.kpi_name = 'Negotiation' AND events.funnel_step = 'Step 5')
    OR (events.kpi_name = 'Closing' AND events.funnel_step = 'Step 6')
    OR (events.kpi_name = 'Implementation/Onboarding' AND events.funnel_step = 'Step 7')
    OR (events.kpi_name = 'Follow-up/Customer Success' AND events.funnel_step = 'Step 8')
    OR (events.kpi_name = 'Renewal/Expansion' AND events.funnel_step = 'Step 9')
  )
  OR (
    events.event_source = 'deal_stage'
    AND (episodes.deal_episode_key IS NULL OR events.event_at < episodes.created_at)
  );

AUDIT (
  name assert_funnel_event_reconciliation
);

WITH expected AS (
  SELECT 'deal_stage' AS event_source, COUNT(*) AS event_count
  FROM staging.stg_pipedrive__deal_changes
  WHERE changed_field_key = 'stage_id'

  UNION ALL

  SELECT 'completed_activity' AS event_source, COUNT(*) AS event_count
  FROM staging.stg_pipedrive__activities AS activities
  INNER JOIN staging.stg_pipedrive__activity_types AS activity_types
    ON activities.activity_type = activity_types.activity_type
  WHERE
    activities.is_done
    AND activity_types.is_active
    AND activity_types.activity_type_name IN ('Sales Call 1', 'Sales Call 2')
),

actual AS (
  SELECT event_source, COUNT(*) AS event_count
  FROM @this_model
  GROUP BY 1
)

SELECT expected.event_source, expected.event_count, actual.event_count AS actual_count
FROM expected
LEFT JOIN actual ON expected.event_source = actual.event_source
WHERE expected.event_count <> COALESCE(actual.event_count, 0);

AUDIT (
  name assert_report_contract
);

SELECT month
FROM @this_model
GROUP BY month
HAVING COUNT(*) <> 11 OR MIN(deals_count) < 0;

AUDIT (
  name assert_report_reconciliation
);

WITH report_counts AS (
  SELECT kpi_name, funnel_step, SUM(deals_count) AS deals_count
  FROM @this_model
  GROUP BY 1, 2
),

event_counts AS (
  SELECT kpi_name, funnel_step, COUNT(*) AS deals_count
  FROM intermediate.int_pipedrive__funnel_step_events
  WHERE CAST(DATE_TRUNC('month', event_at) AS DATE)
    BETWEEN CAST(@start_ds AS DATE) AND CAST(@end_ds AS DATE)
  GROUP BY 1, 2
)

SELECT
  event_counts.kpi_name,
  event_counts.funnel_step,
  event_counts.deals_count AS expected_count,
  report_counts.deals_count AS actual_count
FROM event_counts
LEFT JOIN report_counts
  ON event_counts.kpi_name = report_counts.kpi_name
  AND event_counts.funnel_step = report_counts.funnel_step
WHERE event_counts.deals_count <> COALESCE(report_counts.deals_count, 0);
