MODEL (
  name marts.customer_segments,
  kind FULL,
  grain (group_reference_status, group_type),
  audits (
    not_null(columns = (group_reference_status, customer_count)),
    unique_combination_of_columns(columns = (group_reference_status, group_type))
  )
);

SELECT
  customers.group_reference_status,
  COALESCE(customers.group_type, 'not_available') AS group_type,
  COUNT(DISTINCT customers.customer_id) AS customer_count,
  COUNT(DISTINCT CASE WHEN orders.is_active_order THEN customers.customer_id END) AS active_customer_count,
  COUNT(DISTINCT orders.order_id) AS order_count,
  COALESCE(SUM(orders.finished_order_value_eur), 0) AS finished_order_value_eur,
  COALESCE(SUM(orders.booked_pipeline_value_eur), 0) AS booked_pipeline_value_eur,
  COALESCE(SUM(orders.active_order_value_eur), 0) AS active_order_value_eur
FROM dimensions.dim_customer AS customers
LEFT JOIN facts.fct_order AS orders
  ON customers.customer_id = orders.customer_id
GROUP BY
  1,
  2