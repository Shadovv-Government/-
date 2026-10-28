-- Проверки вопроса 5 (ожидания взяты из docs/tasks.md и qa/control_results.csv).
-- Каждая строка: проверка, ожидание, факт, статус.
WITH delivered_items AS (
    SELECT i.order_id, i.order_item_id, i.price,
           COALESCE(t.product_category_name_english, p.product_category_name, 'UNKNOWN') AS category
    FROM core.order_items i
    JOIN core.orders o ON o.order_id = i.order_id AND o.order_status = 'delivered'
    LEFT JOIN core.products p ON p.product_id = i.product_id
    LEFT JOIN core.category_translations t ON t.product_category_name = p.product_category_name
), by_category AS (
    SELECT category, SUM(price) AS revenue FROM delivered_items GROUP BY category
), checks AS (
    SELECT 1 AS n, 'число категорий (включая UNKNOWN)' AS check_name, '74' AS expected,
           (SELECT count(*) FROM by_category)::text AS actual
    UNION ALL SELECT 2, 'выручка крупнейшей категории', '1233131.72',
           (SELECT max(revenue) FROM by_category)::text
    UNION ALL SELECT 3, 'сумма по категориям', '13221498.11',
           (SELECT SUM(revenue) FROM by_category)::text
    UNION ALL SELECT 4, 'общая выручка из core.order_items (без категорий)', '13221498.11',
           (SELECT SUM(i.price) FROM core.order_items i JOIN core.orders o USING (order_id)
            WHERE o.order_status = 'delivered')::text
    UNION ALL SELECT 5, 'позиций delivered в расчёте = позиций в core', 
           (SELECT count(*) FROM core.order_items i JOIN core.orders o USING (order_id)
            WHERE o.order_status = 'delivered')::text,
           (SELECT count(*) FROM delivered_items)::text
    UNION ALL SELECT 6, 'сумма долей, %', '100.00',
           (SELECT SUM(ROUND(100.0 * revenue / (SELECT SUM(revenue) FROM by_category), 2)) FROM by_category)::text
    UNION ALL SELECT 7, 'выручка UNKNOWN (пустая категория) не равна 0', '>0',
           (SELECT COALESCE(SUM(revenue),0) FROM by_category WHERE category = 'UNKNOWN')::text
)
SELECT n, check_name, expected, actual,
       CASE WHEN n = 6 THEN CASE WHEN abs(actual::numeric - 100) <= 0.05 THEN 'PASS' ELSE 'WARN' END
            WHEN n = 7 THEN CASE WHEN actual::numeric > 0 THEN 'PASS' ELSE 'FAIL' END
            WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS status
FROM checks ORDER BY n;
