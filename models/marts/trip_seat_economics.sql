MODEL (
  name marts.trip_seat_economics,
  kind FULL,
  grain trip_id,
  audits (
    not_null(columns = (trip_id, max_seats, active_seat_count, observed_seat_utilization)),
    unique_values(columns = trip_id)
  )
);

SELECT
  trip_id,
  trip_date,
  route_name,
  manufacturer,
  airplane_model,
  max_seats,
  order_count,
  active_seat_count,
  max_seats - active_seat_count AS unobserved_or_available_seats,
  observed_seat_utilization,
  finished_order_value_eur,
  booked_pipeline_value_eur,
  active_order_value_eur,
  CASE
    WHEN active_seat_count = 0
    THEN NULL::DECIMAL(18, 2)
    ELSE active_order_value_eur / active_seat_count
  END AS active_value_per_booked_seat_eur
FROM facts.fct_trip