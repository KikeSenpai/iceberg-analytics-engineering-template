MODEL (
  name dimensions.dim_route,
  kind FULL,
  grain (origin_city, destination_city),
  audits (
    not_null(columns = (route_name, origin_region, destination_region)),
    unique_combination_of_columns(columns = (origin_city, destination_city))
  )
);

SELECT DISTINCT
  route_name,
  origin_city,
  origin_country,
  origin_region,
  destination_city,
  destination_country,
  destination_region
FROM intermediate.int_trip_enriched