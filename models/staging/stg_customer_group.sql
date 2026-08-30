MODEL (
  name staging.stg_customer_group,
  kind VIEW,
  grain customer_group_id,
  audits (
    not_null(columns = (customer_group_id, group_type, group_name)),
    unique_values(columns = customer_group_id),
    valid_customer_group_type
  )
);

SELECT
  TRIM("ID")::BIGINT AS customer_group_id,
  TRIM("Type") AS group_type,
  TRIM("Name") AS group_name,
  NULLIF(TRIM("Registry number"), '') AS registry_number
FROM raw.customer_group