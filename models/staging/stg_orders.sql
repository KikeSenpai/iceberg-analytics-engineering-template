MODEL (
  name staging.stg_orders,
  kind FULL,
  audits (not_null(columns = order_id), unique_values(columns = order_id))
);

SELECT
  order_id,
  customer_id,
  order_date,
  amount,
  status
FROM raw.orders
WHERE
  status = 'completed'