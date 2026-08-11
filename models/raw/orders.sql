MODEL (
  name raw.orders,
  kind SEED (
    path '$root/seeds/orders.csv'
  ),
  columns (
    order_id INT,
    customer_id INT,
    order_date DATE,
    amount DECIMAL(10, 2),
    status VARCHAR
  )
)