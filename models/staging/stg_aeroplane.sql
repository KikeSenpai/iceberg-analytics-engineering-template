MODEL (
  name staging.stg_aeroplane,
  kind VIEW,
  grain airplane_id,
  audits (
    not_null(columns = (airplane_id, airplane_model, manufacturer)),
    unique_values(columns = airplane_id),
    aircraft_model_relationship
  )
);

SELECT
  TRIM("Airplane ID")::BIGINT AS airplane_id,
  TRIM("Airplane Model") AS airplane_model,
  TRIM("Manufacturer") AS manufacturer
FROM raw.aeroplane