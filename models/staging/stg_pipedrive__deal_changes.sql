MODEL (
  name staging.stg_pipedrive__deal_changes,
  kind VIEW,
  grain deal_change_key,
  depends_on (
    staging.stg_pipedrive__fields,
    staging.stg_pipedrive__stages,
    staging.stg_pipedrive__users
  ),
  audits (
    not_null(columns := (deal_change_key, deal_id, changed_at, changed_field_key, new_value)),
    unique_values(columns := (deal_change_key)),
    accepted_values(column := changed_field_key, is_in := ('add_time', 'user_id', 'stage_id', 'lost_reason')),
    assert_deal_change_relationships
  )
);

SELECT
  TO_HEX(SHA256(TO_UTF8(CONCAT_WS('||', deal_id, change_time, changed_field_key, new_value)))) AS deal_change_key,
  CAST(deal_id AS BIGINT) AS deal_id,
  CAST(REPLACE(change_time, 'T', ' ') AS TIMESTAMP(6)) AS changed_at,
  LOWER(TRIM(changed_field_key)) AS changed_field_key,
  TRIM(new_value) AS new_value
FROM raw.deal_changes;
