MODEL (
  name facts.fct_trip,
  kind FULL,
  grain trip_id,
  audits (
    not_null(columns = (trip_id, trip_date, airplane_id, order_count, active_seat_count)),
    unique_values(columns = trip_id),
    fact_trip_reconciles_to_source
  )
);

SELECT
  trip.*,
  COUNT(orders.order_id) AS order_count,
  COALESCE(COUNT_IF(orders.is_active_order), 0) AS active_seat_count,
  COALESCE(COUNT_IF(orders.order_status = 'finished'), 0) AS finished_order_count,
  COALESCE(COUNT_IF(orders.order_status = 'booked'), 0) AS booked_order_count,
  COALESCE(COUNT_IF(orders.order_status = 'cancelled'), 0) AS cancelled_order_count,
  COALESCE(SUM(orders.finished_order_value_eur), 0) AS finished_order_value_eur,
  COALESCE(SUM(orders.booked_pipeline_value_eur), 0) AS booked_pipeline_value_eur,
  COALESCE(SUM(orders.active_order_value_eur), 0) AS active_order_value_eur,
  COALESCE(COUNT_IF(orders.is_active_order), 0)::DECIMAL(18, 6) / trip.max_seats AS observed_seat_utilization
FROM intermediate.int_trip_enriched AS trip
LEFT JOIN intermediate.int_order_enriched AS orders
  ON trip.trip_id = orders.trip_id
GROUP BY
  trip.trip_id,
  trip.origin_city,
  trip.origin_country,
  trip.origin_region,
  trip.destination_city,
  trip.destination_country,
  trip.destination_region,
  trip.route_name,
  trip.airplane_id,
  trip.manufacturer,
  trip.airplane_model,
  trip.max_seats,
  trip.max_weight,
  trip.max_distance,
  trip.engine_type,
  trip.start_timestamp,
  trip.end_timestamp,
  trip.trip_date,
  trip.trip_week,
  trip.trip_month,
  trip.chronology_status