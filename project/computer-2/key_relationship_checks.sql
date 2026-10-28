-- Проверка сохранности ключей и обязательных связей raw -> core.
-- psql -X -v ON_ERROR_STOP=1: SQL-ошибка или FAIL дают ненулевой код.
-- Изменяются только временные таблицы текущей транзакции.
BEGIN;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM raw.orders) OR NOT EXISTS (SELECT 1 FROM core.orders) THEN
        RAISE EXCEPTION 'raw.orders или core.orders пуста: проверка невозможна';
    END IF;
END $$;

CREATE TEMP TABLE raw_keys ON COMMIT DROP AS
SELECT 'customers' AS table_name, jsonb_build_array(NULLIF(customer_id, '')) AS key FROM raw.customers UNION ALL
SELECT 'sellers', jsonb_build_array(NULLIF(seller_id, '')) FROM raw.sellers UNION ALL
SELECT 'category_translations', jsonb_build_array(NULLIF(product_category_name, '')) FROM raw.product_category_translation UNION ALL
SELECT 'products', jsonb_build_array(NULLIF(product_id, '')) FROM raw.products UNION ALL
SELECT 'orders', jsonb_build_array(NULLIF(order_id, '')) FROM raw.orders UNION ALL
SELECT 'order_items', jsonb_build_array(NULLIF(order_id, ''), NULLIF(order_item_id, '')::integer::text) FROM raw.order_items UNION ALL
SELECT 'order_payments', jsonb_build_array(NULLIF(order_id, ''), NULLIF(payment_sequential, '')::integer::text) FROM raw.order_payments UNION ALL
SELECT 'order_reviews', jsonb_build_array(NULLIF(review_id, ''), NULLIF(order_id, '')) FROM raw.order_reviews;

CREATE TEMP TABLE core_keys ON COMMIT DROP AS
SELECT 'customers' AS table_name, jsonb_build_array(customer_id) AS key FROM core.customers UNION ALL
SELECT 'sellers', jsonb_build_array(seller_id) FROM core.sellers UNION ALL
SELECT 'category_translations', jsonb_build_array(product_category_name) FROM core.category_translations UNION ALL
SELECT 'products', jsonb_build_array(product_id) FROM core.products UNION ALL
SELECT 'orders', jsonb_build_array(order_id) FROM core.orders UNION ALL
SELECT 'order_items', jsonb_build_array(order_id, order_item_id::text) FROM core.order_items UNION ALL
SELECT 'order_payments', jsonb_build_array(order_id, payment_sequential::text) FROM core.order_payments UNION ALL
SELECT 'order_reviews', jsonb_build_array(review_id, order_id) FROM core.order_reviews;

CREATE TEMP TABLE key_check_results ON COMMIT DROP AS
WITH tables(table_name) AS (VALUES ('customers'), ('sellers'), ('category_translations'), ('products'),
                                  ('orders'), ('order_items'), ('order_payments'), ('order_reviews')),
missing AS (SELECT table_name, key FROM raw_keys EXCEPT ALL SELECT table_name, key FROM core_keys),
extra AS (SELECT table_name, key FROM core_keys EXCEPT ALL SELECT table_name, key FROM raw_keys),
duplicates AS (SELECT table_name, key, count(*) - 1 AS excess FROM core_keys GROUP BY table_name, key HAVING count(*) > 1),
nulls AS (SELECT table_name, count(*) AS n FROM core_keys k
          WHERE EXISTS (SELECT 1 FROM jsonb_array_elements(k.key) x WHERE x = 'null'::jsonb)
          GROUP BY table_name)
SELECT t.table_name,
       (SELECT count(*) FROM raw_keys r WHERE r.table_name = t.table_name) AS raw_rows,
       (SELECT count(*) FROM core_keys c WHERE c.table_name = t.table_name) AS core_rows,
       (SELECT count(*) FROM missing m WHERE m.table_name = t.table_name) AS missing_keys,
       (SELECT count(*) FROM extra e WHERE e.table_name = t.table_name) AS extra_keys,
       COALESCE((SELECT sum(excess) FROM duplicates d WHERE d.table_name = t.table_name), 0) AS duplicate_key_excess,
       COALESCE((SELECT n FROM nulls WHERE nulls.table_name = t.table_name), 0) AS null_key_rows
FROM tables t;

CREATE TEMP TABLE relationship_check_results ON COMMIT DROP AS
SELECT 'orders -> customers' AS relationship, count(*) AS errors FROM core.orders c
 WHERE c.customer_id IS NULL OR NOT EXISTS (SELECT 1 FROM core.customers p WHERE p.customer_id = c.customer_id)
UNION ALL SELECT 'items -> orders', count(*) FROM core.order_items c
 WHERE c.order_id IS NULL OR NOT EXISTS (SELECT 1 FROM core.orders p WHERE p.order_id = c.order_id)
UNION ALL SELECT 'items -> products', count(*) FROM core.order_items c
 WHERE c.product_id IS NULL OR NOT EXISTS (SELECT 1 FROM core.products p WHERE p.product_id = c.product_id)
UNION ALL SELECT 'items -> sellers', count(*) FROM core.order_items c
 WHERE c.seller_id IS NULL OR NOT EXISTS (SELECT 1 FROM core.sellers p WHERE p.seller_id = c.seller_id)
UNION ALL SELECT 'payments -> orders', count(*) FROM core.order_payments c
 WHERE c.order_id IS NULL OR NOT EXISTS (SELECT 1 FROM core.orders p WHERE p.order_id = c.order_id)
UNION ALL SELECT 'reviews -> orders', count(*) FROM core.order_reviews c
 WHERE c.order_id IS NULL OR NOT EXISTS (SELECT 1 FROM core.orders p WHERE p.order_id = c.order_id)
UNION ALL SELECT 'customers -> person id', count(*) FROM core.customers
 WHERE customer_unique_id IS NULL OR customer_unique_id = ''
UNION ALL SELECT 'raw/core customer -> person mapping', count(*) FROM raw.customers r
 JOIN core.customers c ON c.customer_id = NULLIF(r.customer_id, '')
 WHERE NULLIF(r.customer_unique_id, '') IS DISTINCT FROM c.customer_unique_id
UNION ALL SELECT 'raw/core order -> customer mapping', count(*) FROM raw.orders r
 JOIN core.orders c ON c.order_id = NULLIF(r.order_id, '')
 WHERE NULLIF(r.customer_id, '') IS DISTINCT FROM c.customer_id
UNION ALL SELECT 'raw/core item -> product mapping', count(*) FROM raw.order_items r
 JOIN core.order_items c ON c.order_id = NULLIF(r.order_id, '') AND c.order_item_id = NULLIF(r.order_item_id, '')::integer
 WHERE NULLIF(r.product_id, '') IS DISTINCT FROM c.product_id
UNION ALL SELECT 'raw/core item -> seller mapping', count(*) FROM raw.order_items r
 JOIN core.order_items c ON c.order_id = NULLIF(r.order_id, '') AND c.order_item_id = NULLIF(r.order_item_id, '')::integer
 WHERE NULLIF(r.seller_id, '') IS DISTINCT FROM c.seller_id;

SELECT * FROM key_check_results ORDER BY table_name;
SELECT * FROM relationship_check_results ORDER BY relationship;

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM key_check_results
               WHERE missing_keys <> 0 OR extra_keys <> 0 OR duplicate_key_excess <> 0 OR null_key_rows <> 0)
       OR EXISTS (SELECT 1 FROM relationship_check_results WHERE errors <> 0) THEN
        RAISE EXCEPTION 'FAIL: несохранённые или неверные ключи либо нарушенные связи core';
    END IF;
    RAISE NOTICE 'PASS: ключи сохранены, обязательные связи найдены';
END $$;
ROLLBACK;
