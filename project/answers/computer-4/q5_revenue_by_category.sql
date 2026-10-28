-- Вопрос 5. Выручка по категориям товаров с долей в общей выручке.
-- Источник: только core. Запуск (из project/):
--   psql -X -v ON_ERROR_STOP=1 --csv -f answers/computer-4/q5_revenue_by_category.sql
--
-- Определения:
--   Уровень строки: товарная позиция (order_id, order_item_id) -> агрегат по категории.
--   Выручка: SUM(order_items.price) по заказам со статусом 'delivered'; доставка (freight_value) не входит.
--     Тот же критерий, что у вопроса 1 (контроль 13 221 498.11).
--   Категория: английский перевод; если перевода нет -- исходное португальское название;
--     если категория у товара пуста (NULL) -- 'UNKNOWN'. Товары не теряются: везде LEFT JOIN.
--   Доля: выручка категории / общая выручка (знаменатель считается над теми же позициями,
--     а не над суммой уже отфильтрованных категорий), округление до 2 знаков.
--   Деньги: numeric, без приведения к float.
WITH delivered_items AS (
    SELECT i.order_id, i.order_item_id, i.price,
           COALESCE(t.product_category_name_english,
                    p.product_category_name,
                    'UNKNOWN') AS category
    FROM core.order_items i
    JOIN core.orders o            ON o.order_id = i.order_id AND o.order_status = 'delivered'
    LEFT JOIN core.products p     ON p.product_id = i.product_id
    LEFT JOIN core.category_translations t
                                  ON t.product_category_name = p.product_category_name
), by_category AS (
    SELECT category, SUM(price) AS revenue
    FROM delivered_items
    GROUP BY category
)
SELECT category,
       revenue,
       ROUND(100.0 * revenue / SUM(revenue) OVER (), 2) AS share_pct
FROM by_category
ORDER BY revenue DESC, category;
