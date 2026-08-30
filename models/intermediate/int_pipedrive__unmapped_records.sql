MODEL (
  name intermediate.int_pipedrive__unmapped_records,
  kind FULL,
  grain (issue_type, source_record_key),
  audits (
    not_null(columns := (issue_type, source_record_key, details)),
    unique_combination_of_columns(columns := (issue_type, source_record_key))
  )
);

SELECT
  'activity_deal_not_in_deal_changes' AS issue_type,
  activities.activity_record_key AS source_record_key,
  CONCAT('activity deal_id=', CAST(activities.deal_id AS VARCHAR)) AS details
FROM staging.stg_pipedrive__activities AS activities
LEFT JOIN (
  SELECT DISTINCT deal_id
  FROM staging.stg_pipedrive__deal_changes
) AS changed_deals
  ON activities.deal_id = changed_deals.deal_id
WHERE changed_deals.deal_id IS NULL

UNION ALL

SELECT
  'activity_type_not_requested_kpi' AS issue_type,
  activities.activity_record_key AS source_record_key,
  CONCAT('activity_type=', activities.activity_type) AS details
FROM staging.stg_pipedrive__activities AS activities
INNER JOIN staging.stg_pipedrive__activity_types AS activity_types
  ON activities.activity_type = activity_types.activity_type
WHERE activity_types.activity_type_name NOT IN ('Sales Call 1', 'Sales Call 2');
