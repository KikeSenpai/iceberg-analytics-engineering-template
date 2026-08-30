MODEL (
  name dimensions.dim_customer,
  kind FULL,
  grain customer_id,
  audits (
    not_null(columns = (customer_id, customer_name, group_reference_status)),
    unique_values(columns = customer_id),
    valid_group_reference_status
  )
);

SELECT
  *
FROM intermediate.int_customer_enriched