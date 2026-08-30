MODEL (
  name facts.fct_order,
  kind FULL,
  grain order_id,
  audits (
    not_null(columns = (order_id, customer_id, trip_id, price_eur, order_status)),
    unique_values(columns = order_id),
    positive_order_price,
    valid_order_status,
    valid_price_tier,
    fact_order_reconciles_to_source
  )
);

SELECT
  *
FROM intermediate.int_order_enriched