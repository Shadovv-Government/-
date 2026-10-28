-- Показывает, почему нельзя считать людей по customer_id и что входит в метрику.
SELECT count(*) AS customer_records,
       count(DISTINCT customer_id) AS customer_ids,
       count(DISTINCT customer_unique_id) AS people_ids,
       count(*) FILTER (WHERE customer_unique_id IS NULL) AS missing_people_ids
FROM core.customers;

SELECT order_status, count(*) AS orders
FROM core.orders
GROUP BY order_status ORDER BY order_status;
