AUDIT (
  name aircraft_model_relationship
);

SELECT
  aircraft.*
FROM @this_model AS aircraft
LEFT JOIN raw.aeroplane_model AS model
  ON aircraft.manufacturer = TRIM(model.manufacturer)
  AND aircraft.airplane_model = TRIM(model.model)
WHERE
  model.model IS NULL;

AUDIT (
  name order_customer_relationship
);

SELECT
  orders.*
FROM @this_model AS orders
LEFT JOIN raw.customer AS customers
  ON orders.customer_id = TRIM(customers."Customer ID")::BIGINT
WHERE
  customers."Customer ID" IS NULL;

AUDIT (
  name order_trip_relationship
);

SELECT
  orders.*
FROM @this_model AS orders
LEFT JOIN raw.trip AS trips
  ON orders.trip_id = TRIM(trips."Trip ID")::BIGINT
WHERE
  trips."Trip ID" IS NULL;

AUDIT (
  name trip_aircraft_relationship
);

SELECT
  trips.*
FROM @this_model AS trips
LEFT JOIN raw.aeroplane AS aircraft
  ON trips.airplane_id = TRIM(aircraft."Airplane ID")::BIGINT
WHERE
  aircraft."Airplane ID" IS NULL;

AUDIT (
  name fact_order_reconciles_to_source
);

SELECT
  'row_count' AS failed_check
WHERE
  (
    SELECT
      COUNT(*)
    FROM @this_model
  ) <> (
    SELECT
      COUNT(*)
    FROM raw."order"
  )
UNION ALL
SELECT
  'price_total' AS failed_check
WHERE
  (
    SELECT
      SUM(price_eur)
    FROM @this_model
  ) <> (
    SELECT
      SUM(TRIM("Price (EUR)")::DECIMAL(18, 2))
    FROM raw."order"
  );

AUDIT (
  name fact_trip_reconciles_to_source
);

SELECT
  'row_count' AS failed_check
WHERE
  (
    SELECT
      COUNT(*)
    FROM @this_model
  ) <> (
    SELECT
      COUNT(*)
    FROM raw.trip
  )