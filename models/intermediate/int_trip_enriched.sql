MODEL (
  name intermediate.int_trip_enriched,
  kind VIEW,
  grain trip_id,
  audits (
    not_null(
      columns = (trip_id, origin_region, destination_region, manufacturer, airplane_model)
    ),
    unique_values(columns = trip_id)
  )
);

SELECT
  trip.trip_id,
  trip.origin_city,
  origin.country AS origin_country,
  origin.region AS origin_region,
  trip.destination_city,
  destination.country AS destination_country,
  destination.region AS destination_region,
  CONCAT(trip.origin_city, ' / ', trip.destination_city) AS route_name,
  trip.airplane_id,
  aircraft.manufacturer,
  aircraft.airplane_model,
  aircraft_model.max_seats,
  aircraft_model.max_weight,
  aircraft_model.max_distance,
  aircraft_model.engine_type,
  trip.start_timestamp,
  trip.end_timestamp,
  trip.start_timestamp::DATE AS trip_date,
  DATE_TRUNC('WEEK', trip.start_timestamp)::DATE AS trip_week,
  DATE_TRUNC('MONTH', trip.start_timestamp)::DATE AS trip_month,
  trip.chronology_status
FROM staging.stg_trip AS trip
JOIN staging.stg_aeroplane AS aircraft
  ON trip.airplane_id = aircraft.airplane_id
JOIN staging.stg_aeroplane_model AS aircraft_model
  ON aircraft.manufacturer = aircraft_model.manufacturer
  AND aircraft.airplane_model = aircraft_model.model
JOIN intermediate.int_city_geography AS origin
  ON trip.origin_city = origin.city
JOIN intermediate.int_city_geography AS destination
  ON trip.destination_city = destination.city