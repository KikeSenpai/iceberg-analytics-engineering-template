MODEL (
  name intermediate.int_order_enriched,
  kind VIEW,
  grain order_id,
  audits (
    not_null(columns = (order_id, customer_id, trip_id, price_tier, trip_date)),
    unique_values(columns = order_id),
    valid_price_tier
  )
);

SELECT
  orders.order_id,
  orders.customer_id,
  customer.customer_name,
  customer.customer_group_id,
  customer.group_name,
  customer.group_type,
  customer.group_reference_status,
  orders.trip_id,
  trip.trip_date,
  trip.trip_week,
  trip.trip_month,
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
  orders.price_eur,
  CASE
    WHEN orders.price_eur < 1000
    THEN 'under_1000_eur'
    WHEN orders.price_eur < 2000
    THEN '1000_to_1999_eur'
    ELSE '2000_eur_and_over'
  END AS price_tier,
  orders.seat_number,
  orders.order_status,
  orders.order_status IN ('booked', 'finished') AS is_active_order,
  CASE
    WHEN orders.order_status = 'finished'
    THEN orders.price_eur
    ELSE 0::DECIMAL(18, 2)
  END AS finished_order_value_eur,
  CASE
    WHEN orders.order_status = 'booked'
    THEN orders.price_eur
    ELSE 0::DECIMAL(18, 2)
  END AS booked_pipeline_value_eur,
  CASE
    WHEN orders.order_status IN ('booked', 'finished')
    THEN orders.price_eur
    ELSE 0::DECIMAL(18, 2)
  END AS active_order_value_eur
FROM staging.stg_order AS orders
JOIN intermediate.int_customer_enriched AS customer
  ON orders.customer_id = customer.customer_id
JOIN intermediate.int_trip_enriched AS trip
  ON orders.trip_id = trip.trip_id