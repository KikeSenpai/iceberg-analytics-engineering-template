MODEL (
  name marts.customer_activity_monthly,
  kind FULL,
  grain month_start,
  audits (
    not_null(columns = (month_start, monthly_active_users)),
    unique_values(columns = month_start)
  )
);

SELECT
  trip_month AS month_start,
  COUNT(DISTINCT customer_id) FILTER(WHERE
    is_active_order) AS monthly_active_users,
  COUNT_IF(is_active_order) AS active_order_count,
  SUM(finished_order_value_eur) AS finished_order_value_eur,
  SUM(booked_pipeline_value_eur) AS booked_pipeline_value_eur
FROM facts.fct_order
GROUP BY
  1