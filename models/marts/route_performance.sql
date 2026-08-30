MODEL (
  name marts.route_performance,
  kind FULL,
  grain (origin_city, destination_city),
  audits (
    not_null(columns = (route_name, origin_region, destination_region)),
    unique_combination_of_columns(columns = (origin_city, destination_city))
  )
);

SELECT
  route_name,
  origin_city,
  origin_region,
  destination_city,
  destination_region,
  COUNT(*) AS trip_count,
  SUM(order_count) AS order_count,
  SUM(active_seat_count) AS active_seat_count,
  SUM(finished_order_value_eur) AS finished_order_value_eur,
  SUM(booked_pipeline_value_eur) AS booked_pipeline_value_eur,
  AVG(observed_seat_utilization) AS average_observed_seat_utilization
FROM facts.fct_trip
GROUP BY
  1,
  2,
  3,
  4,
  5