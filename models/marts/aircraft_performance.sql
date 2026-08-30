MODEL (
  name marts.aircraft_performance,
  kind FULL,
  grain (manufacturer, airplane_model),
  audits (
    not_null(columns = (manufacturer, airplane_model, max_seats)),
    unique_combination_of_columns(columns = (manufacturer, airplane_model))
  )
);

SELECT
  manufacturer,
  airplane_model,
  max_seats,
  max_distance,
  engine_type,
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