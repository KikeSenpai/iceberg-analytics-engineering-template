MODEL (
  name intermediate.int_city_geography,
  kind VIEW,
  grain city,
  audits (not_null(columns = (city, country, region)), unique_values(columns = city))
);

SELECT
  city,
  country,
  region
FROM (VALUES
  ('Amsterdam', 'Netherlands', 'Europe'),
  ('Auckland', 'New Zealand', 'Oceania'),
  ('Bangkok', 'Thailand', 'Asia'),
  ('Beijing', 'China', 'Asia'),
  ('Berlin', 'Germany', 'Europe'),
  ('Cape Town', 'South Africa', 'Africa'),
  ('Chicago', 'United States', 'North America'),
  ('Dubai', 'United Arab Emirates', 'Middle East'),
  ('Frankfurt', 'Germany', 'Europe'),
  ('Hong Kong', 'China', 'Asia'),
  ('Johannesburg', 'South Africa', 'Africa'),
  ('London', 'United Kingdom', 'Europe'),
  ('Los Angeles', 'United States', 'North America'),
  ('Madrid', 'Spain', 'Europe'),
  ('Melbourne', 'Australia', 'Oceania'),
  ('Mexico City', 'Mexico', 'Latin America'),
  ('Miami', 'United States', 'North America'),
  ('Moscow', 'Russia', 'Europe'),
  ('Mumbai', 'India', 'Asia'),
  ('New York', 'United States', 'North America'),
  ('Paris', 'France', 'Europe'),
  ('Rio de Janeiro', 'Brazil', 'Latin America'),
  ('San Francisco', 'United States', 'North America'),
  ('Sao Paulo', 'Brazil', 'Latin America'),
  ('Singapore', 'Singapore', 'Asia'),
  ('Sydney', 'Australia', 'Oceania'),
  ('Tokyo', 'Japan', 'Asia'),
  ('Toronto', 'Canada', 'North America'),
  ('Vancouver', 'Canada', 'North America')) AS geography(city, country, region)