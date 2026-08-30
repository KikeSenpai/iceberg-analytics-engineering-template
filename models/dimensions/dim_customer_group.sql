MODEL (
  name dimensions.dim_customer_group,
  kind FULL,
  grain customer_group_id,
  audits (
    not_null(columns = (customer_group_id, group_type, group_name, member_count)),
    unique_values(columns = customer_group_id)
  )
);

SELECT
  groups.customer_group_id,
  groups.group_type,
  groups.group_name,
  groups.registry_number,
  COUNT(customers.customer_id) AS member_count
FROM staging.stg_customer_group AS groups
LEFT JOIN staging.stg_customer AS customers
  ON groups.customer_group_id = customers.customer_group_id
GROUP BY
  1,
  2,
  3,
  4