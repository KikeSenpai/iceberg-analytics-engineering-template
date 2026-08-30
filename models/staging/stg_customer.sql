MODEL (
  name staging.stg_customer,
  kind VIEW,
  grain customer_id,
  audits (
    not_null(columns = (customer_id, customer_name)),
    unique_values(columns = customer_id),
    customer_group_reference_classified
  )
);

SELECT
  TRIM("Customer ID")::BIGINT AS customer_id,
  TRIM("Name") AS customer_name,
  TRY_CAST(NULLIF(TRIM("Customer Group ID"), '') AS BIGINT) AS customer_group_id,
  LOWER(NULLIF(TRIM("Email"), '')) AS email,
  NULLIF(TRIM("Phone Number"), '') AS phone_number
FROM raw.customer