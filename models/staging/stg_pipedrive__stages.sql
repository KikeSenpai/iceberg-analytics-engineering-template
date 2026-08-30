MODEL (
  name staging.stg_pipedrive__stages,
  kind VIEW,
  grain stage_id,
  audits (
    not_null(columns := (stage_id, stage_name)),
    unique_values(columns := (stage_id)),
    forall(criteria := (stage_id BETWEEN 1 AND 9))
  )
);

SELECT
  CAST(stage_id AS INTEGER) AS stage_id,
  TRIM(stage_name) AS stage_name
FROM raw.stages;
