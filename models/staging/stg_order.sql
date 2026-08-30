MODEL (
  name staging.stg_order,
  kind VIEW,
  grain order_id,
  audits (
    not_null(columns = (order_id, customer_id, trip_id, price_eur, seat_number, order_status)),
    unique_values(columns = order_id),
    positive_order_price,
    valid_order_status,
    order_customer_relationship,
    order_trip_relationship
  )
);

SELECT
  TRIM("Order ID")::BIGINT AS order_id,
  TRIM("Customer ID")::BIGINT AS customer_id,
  TRIM("Trip ID")::BIGINT AS trip_id,
  TRIM("Price (EUR)")::DECIMAL(18, 2) AS price_eur,
  UPPER(TRIM("Seat No")) AS seat_number,
  LOWER(TRIM("Status")) AS order_status
FROM raw."order"