MODEL (
  name staging.stg_pipedrive__fields,
  kind VIEW,
  grain field_key,
  audits (
    not_null(columns := (field_id, field_key, field_name)),
    unique_values(columns := (field_id, field_key)),
    accepted_values(column := field_key, is_in := ('add_time', 'user_id', 'stage_id', 'lost_reason'))
  )
);

SELECT
  CAST(id AS INTEGER) AS field_id,
  LOWER(TRIM(field_key)) AS field_key,
  TRIM(name) AS field_name,
  field_value_options
FROM raw.fields;
