-- Компьютер 4: независимая сверка ответа на вопрос 5 -- raw против core по каждой категории.
-- raw читается ТОЛЬКО для проверки (сдаваемый ответ строится из core).
-- Запуск из project/:  psql -X -v ON_ERROR_STOP=1 --csv -f quality/computer-4/02_q5_raw_vs_core.sql
-- Ожидание: ни одной строки с расхождением (diff <> 0) и совпадающее число категорий.
BEGIN TRANSACTION READ ONLY;
WITH raw_side AS (
    SELECT COALESCE(NULLIF(t.product_category_name_english,''), NULLIF(p.product_category_name,''), 'UNKNOWN') AS category,
           SUM(i.price::numeric) AS revenue
    FROM raw.order_items i
    JOIN raw.orders o ON o.order_id = i.order_id AND o.order_status = 'delivered'
    LEFT JOIN raw.products p ON p.product_id = i.product_id
    LEFT JOIN raw.product_category_translation t ON t.product_category_name = p.product_category_name
    GROUP BY 1),
core_side AS (
    SELECT COALESCE(t.product_category_name_english, p.product_category_name, 'UNKNOWN') AS category,
           SUM(i.price) AS revenue
    FROM core.order_items i
    JOIN core.orders o ON o.order_id = i.order_id AND o.order_status = 'delivered'
    LEFT JOIN core.products p ON p.product_id = i.product_id
    LEFT JOIN core.category_translations t ON t.product_category_name = p.product_category_name
    GROUP BY 1)
SELECT COUNT(*) AS categories_compared,
       COUNT(*) FILTER (WHERE r.category IS NULL OR c.category IS NULL) AS categories_only_on_one_side,
       COUNT(*) FILTER (WHERE r.revenue IS DISTINCT FROM c.revenue) AS categories_with_diff,
       SUM(r.revenue) AS raw_total, SUM(c.revenue) AS core_total,
       CASE WHEN COUNT(*) = 74
             AND COUNT(*) FILTER (WHERE r.category IS NULL OR c.category IS NULL) = 0
             AND COUNT(*) FILTER (WHERE r.revenue IS DISTINCT FROM c.revenue) = 0
             AND SUM(r.revenue) = SUM(c.revenue) THEN 'PASS' ELSE 'FAIL' END AS status
FROM raw_side r FULL JOIN core_side c USING (category);
COMMIT;
