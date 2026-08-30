MODEL (
  name staging.stg_trip,
  kind VIEW,
  grain trip_id,
  audits (
    not_null(
      columns = (
        trip_id,
        origin_city,
        destination_city,
        airplane_id,
        start_timestamp,
        end_timestamp
      )
    ),
    unique_values(columns = trip_id),
    trip_aircraft_relationship,
    valid_trip_route,
    valid_chronology_classification
  )
);

SELECT
  TRIM("Trip ID")::BIGINT AS trip_id,
  TRIM("Origin City") AS origin_city,
  TRIM("Destination City") AS destination_city,
  TRIM("Airplane ID")::BIGINT AS airplane_id,
  TRIM("Start Timestamp")::TIMESTAMP(6) AS start_timestamp,
  TRIM("End Timestamp")::TIMESTAMP(6) AS end_timestamp,
  CASE
    WHEN TRIM("End Timestamp")::TIMESTAMP(6) >= TRIM("Start Timestamp")::TIMESTAMP(6)
    THEN 'ordered_local_timestamps'
    ELSE 'cross_timezone_or_invalid'
  END AS chronology_status
FROM raw.trip