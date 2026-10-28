-- Вопрос 4: все заказы снимка независимо от статуса и даты.
-- Покупатель — customer_unique_id, повторный — >= 2 разных заказа.
WITH orders_per_customer AS (
    SELECT c.customer_unique_id, count(DISTINCT o.order_id) AS order_count
    FROM core.orders AS o
    JOIN core.customers AS c ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT count(*) AS customers,
       count(*) FILTER (WHERE order_count >= 2) AS repeat_customers,
       round(100.0 * count(*) FILTER (WHERE order_count >= 2)
             / NULLIF(count(*), 0), 2) AS repeat_pct
FROM orders_per_customer;
