-- Диагностика raw/core; временные таблицы удаляются при ROLLBACK.
-- Запуск через psql -X -v ON_ERROR_STOP=1. Любое расхождение даёт ошибку.
BEGIN;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM raw.orders) OR NOT EXISTS (SELECT 1 FROM core.orders) THEN
        RAISE EXCEPTION 'raw.orders или core.orders пуст: сверка невозможна';
    END IF;
END $$;

-- Позиции, классифицированные независимо на обеих сторонах. LEFT JOIN
-- сохраняет отсутствующие ссылки и NULL категории; сравниваем все статусы.
CREATE TEMP TABLE raw_items AS
SELECT i.order_id, i.seller_id, nullif(p.product_category_name, '') AS category,
       nullif(o.order_status, '') AS status,
       nullif(i.price, '')::numeric AS price,
       nullif(i.freight_value, '')::numeric AS freight
FROM raw.order_items i
LEFT JOIN raw.orders o ON o.order_id = i.order_id
LEFT JOIN raw.products p ON p.product_id = i.product_id;
CREATE TEMP TABLE core_items AS
SELECT i.order_id, i.seller_id, p.product_category_name AS category,
       o.order_status AS status, i.price, i.freight_value AS freight
FROM core.order_items i
LEFT JOIN core.orders o ON o.order_id = i.order_id
LEFT JOIN core.products p ON p.product_id = i.product_id;

-- Ключ включает статус: изменение статуса не маскируется общим итогом.
CREATE TEMP TABLE raw_financial AS
SELECT 'order' AS dimension, jsonb_build_array(order_id, status) AS key,
       count(*) AS rows, count(price) AS priced_rows, count(freight) AS freight_rows,
       sum(price) AS price, sum(freight) AS freight
FROM raw_items GROUP BY order_id, status
UNION ALL
SELECT 'seller', jsonb_build_array(seller_id, status), count(*), count(price), count(freight), sum(price), sum(freight)
FROM raw_items GROUP BY seller_id, status
UNION ALL
SELECT 'category', jsonb_build_array(category, status), count(*), count(price), count(freight), sum(price), sum(freight)
FROM raw_items GROUP BY category, status;
CREATE TEMP TABLE core_financial AS
SELECT 'order' AS dimension, jsonb_build_array(order_id, status) AS key,
       count(*) AS rows, count(price) AS priced_rows, count(freight) AS freight_rows,
       sum(price) AS price, sum(freight) AS freight
FROM core_items GROUP BY order_id, status
UNION ALL
SELECT 'seller', jsonb_build_array(seller_id, status), count(*), count(price), count(freight), sum(price), sum(freight)
FROM core_items GROUP BY seller_id, status
UNION ALL
SELECT 'category', jsonb_build_array(category, status), count(*), count(price), count(freight), sum(price), sum(freight)
FROM core_items GROUP BY category, status;

CREATE TEMP TABLE financial_differences AS
SELECT coalesce(r.dimension, c.dimension) AS dimension, coalesce(r.key, c.key) AS key,
       r.rows AS raw_rows, c.rows AS core_rows,
       r.priced_rows AS raw_priced_rows, c.priced_rows AS core_priced_rows,
       r.freight_rows AS raw_freight_rows, c.freight_rows AS core_freight_rows,
       r.price AS raw_price, c.price AS core_price,
       r.freight AS raw_freight, c.freight AS core_freight
FROM raw_financial r FULL JOIN core_financial c
  ON r.dimension = c.dimension AND r.key = c.key
WHERE r.rows IS DISTINCT FROM c.rows OR r.priced_rows IS DISTINCT FROM c.priced_rows
   OR r.freight_rows IS DISTINCT FROM c.freight_rows OR r.price IS DISTINCT FROM c.price
   OR r.freight IS DISTINCT FROM c.freight;

-- Платежи сверяются независимо от позиций, на уровне заказа.
CREATE TEMP TABLE payment_differences AS
WITH r AS (
    SELECT order_id, count(*) AS rows, count(nullif(payment_value, '')) AS valued_rows,
           sum(nullif(payment_value, '')::numeric) AS amount
    FROM raw.order_payments GROUP BY order_id
), c AS (
    SELECT order_id, count(*) AS rows, count(payment_value) AS valued_rows,
           sum(payment_value) AS amount
    FROM core.order_payments GROUP BY order_id
)
SELECT coalesce(r.order_id, c.order_id) AS order_id,
       r.rows AS raw_rows, c.rows AS core_rows, r.valued_rows AS raw_valued_rows,
       c.valued_rows AS core_valued_rows, r.amount AS raw_amount, c.amount AS core_amount
FROM r FULL JOIN c USING (order_id)
WHERE r.rows IS DISTINCT FROM c.rows OR r.valued_rows IS DISTINCT FROM c.valued_rows
   OR r.amount IS DISTINCT FROM c.amount;

SELECT dimension, count(*) AS mismatched_groups FROM financial_differences GROUP BY dimension ORDER BY dimension;
SELECT * FROM financial_differences ORDER BY dimension, key LIMIT 50;
SELECT count(*) AS mismatched_payment_orders FROM payment_differences;
SELECT * FROM payment_differences ORDER BY order_id LIMIT 50;
SELECT 'raw_delivered' AS source, count(*) AS item_rows, count(price) AS priced_rows,
       count(freight) AS freight_rows, sum(price) AS goods, sum(freight) AS freight
FROM raw_items WHERE status = 'delivered'
UNION ALL
SELECT 'core_delivered', count(*), count(price), count(freight), sum(price), sum(freight)
FROM core_items WHERE status = 'delivered';
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM financial_differences) OR EXISTS (SELECT 1 FROM payment_differences) THEN
        RAISE EXCEPTION 'Финансовые данные raw/core расходятся; подробности выше';
    END IF;
    RAISE NOTICE 'PASS: группы заказов, продавцов, категорий и платежей совпадают';
END $$;
ROLLBACK;
