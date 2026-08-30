MODEL (
  name marts.customer_activity_weekly,
  kind FULL,
  grain week_start,
  audits (
    not_null(columns = (week_start, weekly_active_users)),
    unique_values(columns = week_start)
  )
);

SELECT
  trip_week AS week_start,
  COUNT(DISTINCT customer_id) FILTER(WHERE
    is_active_order) AS weekly_active_users,
  COUNT_IF(is_active_order) AS active_order_count,
  SUM(finished_order_value_eur) AS finished_order_value_eur,
  SUM(booked_pipeline_value_eur) AS booked_pipeline_value_eur
FROM facts.fct_order
GROUP BY
  1