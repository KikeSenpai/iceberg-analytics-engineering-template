MODEL (
  name staging.stg_pipedrive__activities,
  kind VIEW,
  grain activity_record_key,
  depends_on (
    staging.stg_pipedrive__activity_types,
    staging.stg_pipedrive__users
  ),
  audits (
    not_null(columns := (activity_record_key, activity_id, activity_type, assigned_user_id, deal_id, is_done, due_at)),
    unique_values(columns := (activity_record_key)),
    assert_activity_relationships
  )
);

SELECT
  TO_HEX(
    SHA256(
      TO_UTF8(
        CONCAT_WS('||', activity_id, type, assigned_to_user, deal_id, done, due_to)
      )
    )
  ) AS activity_record_key,
  CAST(activity_id AS BIGINT) AS activity_id,
  LOWER(TRIM(type)) AS activity_type,
  CAST(assigned_to_user AS BIGINT) AS assigned_user_id,
  CAST(deal_id AS BIGINT) AS deal_id,
  LOWER(TRIM(done)) = 'true' AS is_done,
  CAST(REPLACE(due_to, 'T', ' ') AS TIMESTAMP(6)) AS due_at
FROM raw.activity;
