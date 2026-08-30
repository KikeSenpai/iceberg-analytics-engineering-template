MODEL (
  name marts.regional_monthly,
  kind FULL,
  grain (trip_month, origin_region),
  audits (
    not_null(columns = (trip_month, origin_region)),
    unique_combination_of_columns(columns = (trip_month, origin_region))
  )
);

SELECT
  trips.trip_month,
  trips.origin_region,
  COUNT(DISTINCT trips.trip_id) AS trip_count,
  COUNT(DISTINCT CASE WHEN trips.order_count > 0 THEN trips.trip_id END) AS trips_with_orders,
  COUNT(DISTINCT CASE WHEN orders.is_active_order THEN orders.customer_id END) AS active_customers,
  COALESCE(SUM(orders.finished_order_value_eur), 0) AS finished_order_value_eur,
  COALESCE(SUM(orders.booked_pipeline_value_eur), 0) AS booked_pipeline_value_eur,
  COALESCE(SUM(orders.active_order_value_eur), 0) AS active_order_value_eur
FROM facts.fct_trip AS trips
LEFT JOIN facts.fct_order AS orders
  ON trips.trip_id = orders.trip_id
GROUP BY
  1,
  2