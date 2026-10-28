-- Сравнивайте до/после сборки core на одном и том же наборе raw.
-- Не включает _loaded_at и _source_file; фиксирует содержимое бизнес-полей.
-- Два снимка равны при одинаковом составе строк независимо от их порядка.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
WITH rows(table_name,row_hash) AS (
 SELECT 'orders',md5((to_jsonb(t)-'_loaded_at'-'_source_file')::text) FROM raw.orders t UNION ALL
 SELECT 'order_items',md5((to_jsonb(t)-'_loaded_at'-'_source_file')::text) FROM raw.order_items t UNION ALL
 SELECT 'order_payments',md5((to_jsonb(t)-'_loaded_at'-'_source_file')::text) FROM raw.order_payments t UNION ALL
 SELECT 'order_reviews',md5((to_jsonb(t)-'_loaded_at'-'_source_file')::text) FROM raw.order_reviews t UNION ALL
 SELECT 'products',md5((to_jsonb(t)-'_loaded_at'-'_source_file')::text) FROM raw.products t UNION ALL
 SELECT 'sellers',md5((to_jsonb(t)-'_loaded_at'-'_source_file')::text) FROM raw.sellers t UNION ALL
 SELECT 'customers',md5((to_jsonb(t)-'_loaded_at'-'_source_file')::text) FROM raw.customers t UNION ALL
 SELECT 'product_category_translation',md5((to_jsonb(t)-'_loaded_at'-'_source_file')::text) FROM raw.product_category_translation t
)
SELECT table_name,count(*) AS rows,md5(string_agg(row_hash,'' ORDER BY row_hash)) AS content_md5
FROM rows GROUP BY table_name ORDER BY table_name;
COMMIT;
