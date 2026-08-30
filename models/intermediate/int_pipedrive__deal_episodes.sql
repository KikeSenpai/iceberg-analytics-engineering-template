MODEL (
  name intermediate.int_pipedrive__deal_episodes,
  kind FULL,
  grain deal_episode_key,
  audits (
    not_null(columns := (deal_episode_key, deal_id, created_at, lifecycle_time_signature)),
    unique_values(columns := (deal_episode_key)),
    assert_deal_episode_reconciliation
  )
);

SELECT
  CONCAT(
    CAST(deal_id AS VARCHAR),
    '|',
    CAST(CAST(REPLACE(new_value, 'T', ' ') AS TIMESTAMP(6)) AS VARCHAR)
  ) AS deal_episode_key,
  deal_id,
  CAST(REPLACE(new_value, 'T', ' ') AS TIMESTAMP(6)) AS created_at,
  EXTRACT(HOUR FROM CAST(REPLACE(new_value, 'T', ' ') AS TIMESTAMP(6))) * 3600
    + EXTRACT(MINUTE FROM CAST(REPLACE(new_value, 'T', ' ') AS TIMESTAMP(6))) * 60
    + EXTRACT(SECOND FROM CAST(REPLACE(new_value, 'T', ' ') AS TIMESTAMP(6))) AS lifecycle_time_signature
FROM staging.stg_pipedrive__deal_changes
WHERE changed_field_key = 'add_time';
