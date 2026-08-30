AUDIT (
  name positive_aircraft_specifications
);

SELECT
  *
FROM @this_model
WHERE
  max_seats <= 0 OR max_weight <= 0 OR max_distance <= 0;

AUDIT (
  name positive_order_price
);

SELECT
  *
FROM @this_model
WHERE
  price_eur <= 0;

AUDIT (
  name valid_order_status
);

SELECT
  *
FROM @this_model
WHERE
  NOT order_status IN ('booked', 'cancelled', 'finished');

AUDIT (
  name valid_customer_group_type
);

SELECT
  *
FROM @this_model
WHERE
  NOT group_type IN ('Company', 'Organisation', 'Private Group');

AUDIT (
  name customer_group_reference_classified
);

SELECT
  *
FROM @this_model
WHERE
  NOT customer_group_id IS NULL AND customer_group_id <= 0;

AUDIT (
  name valid_trip_route
);

SELECT
  *
FROM @this_model
WHERE
  origin_city = destination_city;

AUDIT (
  name valid_chronology_classification
);

SELECT
  *
FROM @this_model
WHERE
  NOT chronology_status IN ('ordered_local_timestamps', 'cross_timezone_or_invalid');

AUDIT (
  name valid_group_reference_status
);

SELECT
  *
FROM @this_model
WHERE
  NOT group_reference_status IN ('individual', 'resolved', 'unresolved');

AUDIT (
  name valid_price_tier
);

SELECT
  *
FROM @this_model
WHERE
  NOT price_tier IN ('under_1000_eur', '1000_to_1999_eur', '2000_eur_and_over')