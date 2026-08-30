MODEL (
  name staging.stg_aeroplane_model,
  kind VIEW,
  grain (manufacturer, model),
  audits (
    not_null(
      columns = (manufacturer, model, max_seats, max_weight, max_distance, engine_type)
    ),
    unique_combination_of_columns(columns = (manufacturer, model)),
    positive_aircraft_specifications
  )
);

SELECT
  TRIM(manufacturer) AS manufacturer,
  TRIM(model) AS model,
  TRIM(max_seats)::INTEGER AS max_seats,
  TRIM(max_weight)::BIGINT AS max_weight,
  TRIM(max_distance)::INTEGER AS max_distance,
  TRIM(engine_type) AS engine_type
FROM raw.aeroplane_model