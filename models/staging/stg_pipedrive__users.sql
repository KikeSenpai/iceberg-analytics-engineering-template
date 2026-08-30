MODEL (
  name staging.stg_pipedrive__users,
  kind VIEW,
  grain user_id,
  audits (
    not_null(columns := (user_id, user_name, email, modified_at)),
    unique_values(columns := (user_id))
  )
);

SELECT
  CAST(id AS BIGINT) AS user_id,
  TRIM(name) AS user_name,
  LOWER(TRIM(email)) AS email,
  CAST(modified AS TIMESTAMP(6)) AS modified_at
FROM raw.users;
