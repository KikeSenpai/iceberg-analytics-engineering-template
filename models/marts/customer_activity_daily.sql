MODEL (
  name marts.customer_activity_daily,
  kind FULL,
  grain activity_date,
  audits (
    not_null(columns = (activity_date, dau, wau, mau_30d)),
    unique_values(columns = activity_date)
  )
);

SELECT
  dates.date_day AS activity_date,
  COUNT(DISTINCT orders.customer_id) FILTER(WHERE
    orders.is_active_order AND orders.trip_date = dates.date_day) AS dau,
  COUNT(DISTINCT orders.customer_id) FILTER(WHERE
    orders.is_active_order
    AND orders.trip_date >= DATE_ADD('DAY', -6, dates.date_day)) AS wau,
  COUNT(DISTINCT orders.customer_id) FILTER(WHERE
    orders.is_active_order) AS mau_30d
FROM dimensions.dim_date AS dates
LEFT JOIN facts.fct_order AS orders
  ON orders.trip_date BETWEEN DATE_ADD('DAY', -29, dates.date_day) AND dates.date_day
GROUP BY
  1