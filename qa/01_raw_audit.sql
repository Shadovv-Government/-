-- PostgreSQL 16. Запускать psql с -v ON_ERROR_STOP=1.
-- Скрипт не изменяет исходные данные. Контроли относятся к начальной выгрузке.
\pset pager off
\timing on
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;

\echo '01. Число строк: отклонение от начальной выгрузки не равно ошибке после вброса'
WITH counts(table_name, actual, initial_expected) AS (
 SELECT 'orders', count(*), 99441 FROM raw.orders UNION ALL
 SELECT 'order_items', count(*), 112650 FROM raw.order_items UNION ALL
 SELECT 'order_payments', count(*), 103886 FROM raw.order_payments UNION ALL
 SELECT 'order_reviews', count(*), 99224 FROM raw.order_reviews UNION ALL
 SELECT 'products', count(*), 32951 FROM raw.products UNION ALL
 SELECT 'sellers', count(*), 3095 FROM raw.sellers UNION ALL
 SELECT 'customers', count(*), 99441 FROM raw.customers UNION ALL
 SELECT 'product_category_translation', count(*), 71 FROM raw.product_category_translation
)
SELECT *, actual - initial_expected AS delta FROM counts ORDER BY table_name;

\echo '02. Пустые ключи и повторения кандидатов (для review_id ожидается аномалия)'
WITH keys(table_name, key_parts) AS (
 SELECT 'orders', ARRAY[order_id] FROM raw.orders UNION ALL
 SELECT 'order_items', ARRAY[order_id,order_item_id] FROM raw.order_items UNION ALL
 SELECT 'order_payments', ARRAY[order_id,payment_sequential] FROM raw.order_payments UNION ALL
 SELECT 'reviews_review_id_only', ARRAY[review_id] FROM raw.order_reviews UNION ALL
 SELECT 'reviews_review_id_order_id', ARRAY[review_id,order_id] FROM raw.order_reviews UNION ALL
 SELECT 'products', ARRAY[product_id] FROM raw.products UNION ALL
 SELECT 'sellers', ARRAY[seller_id] FROM raw.sellers UNION ALL
 SELECT 'customers', ARRAY[customer_id] FROM raw.customers UNION ALL
 SELECT 'product_category_translation', ARRAY[product_category_name] FROM raw.product_category_translation
), grouped AS (
 SELECT table_name, key_parts, count(*) AS n,
        EXISTS (SELECT 1 FROM unnest(key_parts) v WHERE NULLIF(btrim(v),'') IS NULL) AS missing
 FROM keys GROUP BY table_name,key_parts
)
SELECT table_name, COALESCE(sum(n) FILTER (WHERE missing),0) AS missing_key_rows,
       count(*) FILTER (WHERE n>1) AS duplicate_groups,
       sum(n-1) AS excess_duplicate_rows
FROM grouped GROUP BY table_name ORDER BY table_name;

\echo '03. Нарушенные связи; отсутствие перевода категории само по себе не повод удалять товар'
SELECT 'orders -> customers' AS relation, count(*) AS unmatched_rows
FROM raw.orders c WHERE NOT EXISTS (SELECT 1 FROM raw.customers p WHERE p.customer_id=c.customer_id)
UNION ALL SELECT 'items -> orders', count(*) FROM raw.order_items c
 WHERE NOT EXISTS (SELECT 1 FROM raw.orders p WHERE p.order_id=c.order_id)
UNION ALL SELECT 'items -> products', count(*) FROM raw.order_items c
 WHERE NOT EXISTS (SELECT 1 FROM raw.products p WHERE p.product_id=c.product_id)
UNION ALL SELECT 'items -> sellers', count(*) FROM raw.order_items c
 WHERE NOT EXISTS (SELECT 1 FROM raw.sellers p WHERE p.seller_id=c.seller_id)
UNION ALL SELECT 'payments -> orders', count(*) FROM raw.order_payments c
 WHERE NOT EXISTS (SELECT 1 FROM raw.orders p WHERE p.order_id=c.order_id)
UNION ALL SELECT 'reviews -> orders', count(*) FROM raw.order_reviews c
 WHERE NOT EXISTS (SELECT 1 FROM raw.orders p WHERE p.order_id=c.order_id)
UNION ALL SELECT 'products -> category translation', count(*) FROM raw.products c
 WHERE NOT EXISTS (SELECT 1 FROM raw.product_category_translation p WHERE p.product_category_name=c.product_category_name);

\echo '04. Пустые и некорректные значения; pg_input_is_valid доступна в PostgreSQL 16'
WITH values_to_check(field_name, value, target_type) AS (
 SELECT 'items.price', price, 'numeric' FROM raw.order_items UNION ALL
 SELECT 'items.freight_value', freight_value, 'numeric' FROM raw.order_items UNION ALL
 SELECT 'items.order_item_id', order_item_id, 'integer' FROM raw.order_items UNION ALL
 SELECT 'payments.payment_value', payment_value, 'numeric' FROM raw.order_payments UNION ALL
 SELECT 'payments.payment_sequential', payment_sequential, 'integer' FROM raw.order_payments UNION ALL
 SELECT 'payments.payment_installments', payment_installments, 'integer' FROM raw.order_payments UNION ALL
 SELECT 'reviews.review_score', review_score, 'integer' FROM raw.order_reviews UNION ALL
 SELECT 'orders.purchase', order_purchase_timestamp, 'timestamp' FROM raw.orders UNION ALL
 SELECT 'orders.approved', order_approved_at, 'timestamp' FROM raw.orders UNION ALL
 SELECT 'orders.carrier', order_delivered_carrier_date, 'timestamp' FROM raw.orders UNION ALL
 SELECT 'orders.delivered', order_delivered_customer_date, 'timestamp' FROM raw.orders UNION ALL
 SELECT 'orders.estimated', order_estimated_delivery_date, 'timestamp' FROM raw.orders UNION ALL
 SELECT 'items.shipping_limit', shipping_limit_date, 'timestamp' FROM raw.order_items UNION ALL
 SELECT 'reviews.creation', review_creation_date, 'timestamp' FROM raw.order_reviews UNION ALL
 SELECT 'reviews.answer', review_answer_timestamp, 'timestamp' FROM raw.order_reviews
)
SELECT field_name, count(*) AS total,
 count(*) FILTER (WHERE NULLIF(btrim(value),'') IS NULL) AS missing,
 count(*) FILTER (WHERE NULLIF(btrim(value),'') IS NOT NULL
                  AND NOT pg_input_is_valid(value,target_type)) AS invalid_nonempty
FROM values_to_check GROUP BY field_name ORDER BY field_name;

\echo '05. Статусы и категории без перевода'
SELECT order_status,count(*) FROM raw.orders GROUP BY 1 ORDER BY 2 DESC;
SELECT p.product_category_name,count(*) AS products
FROM raw.products p
WHERE NOT EXISTS (SELECT 1 FROM raw.product_category_translation t
                  WHERE t.product_category_name=p.product_category_name)
GROUP BY 1 ORDER BY 2 DESC;
SELECT count(*) AS delivered_without_delivery_date FROM raw.orders
WHERE order_status='delivered' AND NULLIF(btrim(order_delivered_customer_date),'') IS NULL;

\echo '06. Покупатель: customer_id и стабильный customer_unique_id'
SELECT count(*) AS customer_records, count(DISTINCT customer_id) AS customer_ids,
       count(DISTINCT customer_unique_id) AS unique_customer_ids
FROM raw.customers;
WITH customer_orders AS (
 SELECT c.customer_unique_id,count(DISTINCT o.order_id) AS n
 FROM raw.orders o JOIN raw.customers c USING(customer_id)
 GROUP BY c.customer_unique_id
)
SELECT count(*) AS customers, count(*) FILTER(WHERE n>=2) AS repeat_customers,
       round(100.0*count(*) FILTER(WHERE n>=2)/NULLIF(count(*),0),6) AS repeat_pct
FROM customer_orders;

\echo '07. Кратности: позиции нельзя напрямую умножать на платежи и отзывы'
WITH i AS (SELECT order_id,count(*) AS n FROM raw.order_items GROUP BY 1),
 p AS (SELECT order_id,count(*) AS n FROM raw.order_payments GROUP BY 1),
 r AS (SELECT order_id,count(*) AS n FROM raw.order_reviews GROUP BY 1)
SELECT (SELECT count(*) FROM raw.order_items) AS item_rows,
       (SELECT sum(i.n*p.n) FROM i JOIN p USING(order_id)) AS item_payment_join_rows,
       (SELECT sum(i.n*p.n*r.n) FROM i JOIN p USING(order_id) JOIN r USING(order_id)) AS triple_join_rows;
SELECT count(*) AS orders_without_items FROM raw.orders o
WHERE NOT EXISTS (SELECT 1 FROM raw.order_items i WHERE i.order_id=o.order_id);
SELECT count(*) AS orders_without_payments FROM raw.orders o
WHERE NOT EXISTS (SELECT 1 FROM raw.order_payments p WHERE p.order_id=o.order_id);

\echo '08. Диагностика платежей: агрегаты ДО соединения; не автоматический FAIL'
WITH i AS (
 SELECT order_id,sum(CASE WHEN pg_input_is_valid(price,'numeric')
                          AND pg_input_is_valid(freight_value,'numeric')
                         THEN price::numeric+freight_value::numeric END) AS item_total,
        bool_and(COALESCE(pg_input_is_valid(price,'numeric'),false)
                 AND COALESCE(pg_input_is_valid(freight_value,'numeric'),false)) AS valid
 FROM raw.order_items GROUP BY 1
), p AS (
 SELECT order_id,sum(CASE WHEN pg_input_is_valid(payment_value,'numeric')
                          THEN payment_value::numeric END) AS payment_total,
        bool_and(COALESCE(pg_input_is_valid(payment_value,'numeric'),false)) AS valid
 FROM raw.order_payments GROUP BY 1
)
SELECT count(*) AS comparable_orders,
       count(*) FILTER(WHERE i.item_total<>p.payment_total) AS any_difference,
       count(*) FILTER(WHERE abs(i.item_total-p.payment_total)>0.01) AS difference_over_one_cent
FROM i JOIN p USING(order_id) WHERE i.valid AND p.valid;

\echo '09. Независимые финансовые агрегаты raw: только диагностическая сверка, не сдаваемые ответы'
WITH delivered AS (
 SELECT i.order_id,
 CASE WHEN pg_input_is_valid(i.price,'numeric') THEN i.price::numeric END AS price,
 CASE WHEN pg_input_is_valid(i.freight_value,'numeric') THEN i.freight_value::numeric END AS freight
 FROM raw.order_items i JOIN raw.orders o USING(order_id)
 WHERE o.order_status='delivered'
), order_totals AS (
 SELECT order_id,sum(price+freight) AS total FROM delivered GROUP BY 1
)
SELECT (SELECT sum(price) FROM delivered) AS goods_revenue_expected_13221498_11,
       (SELECT round(avg(total),2) FROM order_totals) AS average_order_expected_159_88;

\echo '10. Пример повторного review_id: не удаляйте отзывы только по этому полю'
SELECT review_id,count(*) AS rows,count(DISTINCT order_id) AS orders
FROM raw.order_reviews GROUP BY 1 HAVING count(*)>1 ORDER BY rows DESC,review_id LIMIT 20;

COMMIT;
