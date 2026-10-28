-- Сравнение содержимого core между сборками, независимо от порядка строк.
-- MD5 — практическая диагностика, а не криптографическое доказательство.
WITH rows(table_name, row_hash) AS (
    SELECT 'customers', md5(to_jsonb(t)::text) FROM core.customers t UNION ALL
    SELECT 'sellers', md5(to_jsonb(t)::text) FROM core.sellers t UNION ALL
    SELECT 'category_translations', md5(to_jsonb(t)::text) FROM core.category_translations t UNION ALL
    SELECT 'products', md5(to_jsonb(t)::text) FROM core.products t UNION ALL
    SELECT 'orders', md5(to_jsonb(t)::text) FROM core.orders t UNION ALL
    SELECT 'order_items', md5(to_jsonb(t)::text) FROM core.order_items t UNION ALL
    SELECT 'order_payments', md5(to_jsonb(t)::text) FROM core.order_payments t UNION ALL
    SELECT 'order_reviews', md5(to_jsonb(t)::text) FROM core.order_reviews t
)
SELECT table_name, count(*) AS row_count,
       md5(string_agg(row_hash, '' ORDER BY row_hash)) AS content_md5
FROM rows
GROUP BY table_name
ORDER BY table_name;
