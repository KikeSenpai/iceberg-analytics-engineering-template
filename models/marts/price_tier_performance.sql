MODEL (
  name marts.price_tier_performance,
  kind FULL,
  grain price_tier,
  audits (
    not_null(columns = (price_tier, order_count)),
    unique_values(columns = price_tier),
    valid_price_tier
  )
);

SELECT
  price_tier,
  COUNT(*) AS order_count,
  COUNT_IF(is_active_order) AS active_order_count,
  COUNT(DISTINCT customer_id) AS customer_count,
  AVG(price_eur) AS average_order_price_eur,
  SUM(price_eur) AS gross_listed_order_value_eur,
  SUM(finished_order_value_eur) AS finished_order_value_eur,
  SUM(booked_pipeline_value_eur) AS booked_pipeline_value_eur
FROM facts.fct_order
GROUP BY
  1