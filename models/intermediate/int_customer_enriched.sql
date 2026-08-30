MODEL (
  name intermediate.int_customer_enriched,
  kind VIEW,
  grain customer_id,
  audits (
    not_null(columns = (customer_id, customer_name, group_reference_status)),
    unique_values(columns = customer_id),
    valid_group_reference_status
  )
);

SELECT
  customer.customer_id,
  customer.customer_name,
  customer.customer_group_id,
  customer.email,
  customer.phone_number,
  customer_group.group_name,
  customer_group.group_type,
  customer_group.registry_number,
  CASE
    WHEN customer.customer_group_id IS NULL
    THEN 'individual'
    WHEN NOT customer_group.customer_group_id IS NULL
    THEN 'resolved'
    ELSE 'unresolved'
  END AS group_reference_status
FROM staging.stg_customer AS customer
LEFT JOIN staging.stg_customer_group AS customer_group
  ON customer.customer_group_id = customer_group.customer_group_id