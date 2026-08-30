MODEL (
  name dimensions.dim_aircraft,
  kind FULL,
  grain airplane_id,
  audits (
    not_null(columns = (airplane_id, manufacturer, airplane_model, max_seats)),
    unique_values(columns = airplane_id)
  )
);

SELECT
  aircraft.airplane_id,
  aircraft.manufacturer,
  aircraft.airplane_model,
  model.max_seats,
  model.max_weight,
  model.max_distance,
  model.engine_type
FROM staging.stg_aeroplane AS aircraft
JOIN staging.stg_aeroplane_model AS model
  ON aircraft.manufacturer = model.manufacturer
  AND aircraft.airplane_model = model.model