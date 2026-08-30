MODEL (
  name dimensions.dim_date,
  kind FULL,
  grain date_day,
  audits (
    not_null(columns = (date_day, week_start, month_start)),
    unique_values(columns = date_day)
  )
);

SELECT
  date_day,
  DATE_TRUNC('WEEK', date_day::TIMESTAMP)::DATE AS week_start,
  DATE_TRUNC('MONTH', date_day::TIMESTAMP)::DATE AS month_start,
  DAY_OF_WEEK(date_day) AS iso_day_of_week
FROM (
  SELECT
    date_day
  FROM (
    SELECT
      SEQUENCE(MIN(trip_date), MAX(trip_date)) AS date_days
    FROM intermediate.int_trip_enriched
  ) AS bounds
  CROSS JOIN UNNEST(date_days) AS calendar(date_day)
)