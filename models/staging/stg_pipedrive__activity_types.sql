MODEL (
  name staging.stg_pipedrive__activity_types,
  kind VIEW,
  grain activity_type,
  audits (
    not_null(columns := (activity_type_id, activity_type_name, activity_type, is_active)),
    unique_values(columns := (activity_type_id, activity_type))
  )
);

SELECT
  CAST(id AS INTEGER) AS activity_type_id,
  TRIM(name) AS activity_type_name,
  LOWER(TRIM(type)) AS activity_type,
  LOWER(TRIM(active)) = 'yes' AS is_active
FROM raw.activity_types;
