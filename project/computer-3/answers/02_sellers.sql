-- Вопрос 2. Снимок целиком, без ограничения по дате; только delivered.
-- Одна позиция = одна единица. Цена не включает доставку и платежи.
-- NULL price делает выручку продавца неизвестной, а не нулевой.
SELECT s.seller_id, s.seller_city, s.seller_state,
       count(DISTINCT i.order_id) AS order_count,
       count(*) AS item_units,
       CASE WHEN count(i.price) = count(*) THEN sum(i.price) END AS revenue
FROM core.order_items i
JOIN core.orders o ON o.order_id = i.order_id AND o.order_status = 'delivered'
JOIN core.sellers s ON s.seller_id = i.seller_id
GROUP BY s.seller_id, s.seller_city, s.seller_state
ORDER BY revenue DESC NULLS LAST, s.seller_id
LIMIT 10;
