MODEL (
  name marts.business_overview,
  kind FULL,
  grain reporting_period,
  audits (
    not_null(columns = reporting_period)
  )
);

WITH trip_metrics AS (
  SELECT
    COUNT(*) AS trip_count,
    COUNT_IF(order_count > 0) AS trips_with_orders,
    COUNT_IF(order_count = 0) AS trips_without_orders
  FROM facts.fct_trip
), order_metrics AS (
  SELECT
    COUNT(*) AS order_count,
    COUNT_IF(is_active_order) AS active_order_count,
    COUNT_IF(order_status = 'finished') AS finished_order_count,
    COUNT_IF(order_status = 'booked') AS booked_order_count,
    COUNT_IF(order_status = 'cancelled') AS cancelled_order_count,
    SUM(price_eur) AS gross_listed_order_value_eur,
    SUM(finished_order_value_eur) AS finished_order_value_eur,
    SUM(booked_pipeline_value_eur) AS booked_pipeline_value_eur,
    SUM(active_order_value_eur) AS active_order_value_eur
  FROM facts.fct_order
)
SELECT
  'all_available_data' AS reporting_period,
  trips.trip_count,
  orders.order_count,
  (
    SELECT
      COUNT(*)
    FROM dimensions.dim_customer
  ) AS customer_count,
  (
    SELECT
      COUNT(*)
    FROM dimensions.dim_customer_group
  ) AS customer_group_count,
  (
    SELECT
      COUNT(*)
    FROM dimensions.dim_aircraft
  ) AS aircraft_count,
  orders.active_order_count,
  orders.finished_order_count,
  orders.booked_order_count,
  orders.cancelled_order_count,
  trips.trips_with_orders,
  trips.trips_without_orders,
  orders.gross_listed_order_value_eur,
  orders.finished_order_value_eur,
  orders.booked_pipeline_value_eur,
  orders.active_order_value_eur,
  trips.trips_with_orders::DOUBLE / NULLIF(trips.trip_count, 0) AS trip_order_coverage_rate,
  orders.active_order_count::DOUBLE / NULLIF(trips.trip_count, 0) AS active_orders_per_trip,
  orders.finished_order_value_eur / NULLIF(trips.trip_count, 0) AS finished_order_value_per_trip_eur,
  orders.active_order_value_eur / NULLIF(orders.active_order_count, 0) AS active_value_per_active_order_eur
FROM trip_metrics AS trips
CROSS JOIN order_metrics AS orders