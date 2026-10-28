-- Вопрос 3. Весь снимок, delivered по статусу, без фильтра по дате.
-- Сначала агрегируем позиции до заказа; заказы без позиций включены с 0.
-- NULL суммы позиции делает чек неизвестным, а итоговый средний чек NULL.
WITH per_order AS (
    SELECT o.order_id, count(i.order_item_id) AS item_rows,
           count(i.order_item_id) AS item_units,
           CASE WHEN count(i.order_item_id) = count(i.price)
                  AND count(i.order_item_id) = count(i.freight_value)
                THEN coalesce(sum(i.price + i.freight_value), 0::numeric)
           END AS order_value
    FROM core.orders o
    LEFT JOIN core.order_items i ON i.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.order_id
)
SELECT count(*) AS delivered_orders,
       count(*) FILTER (WHERE item_rows = 0) AS orders_without_items,
       count(*) FILTER (WHERE order_value IS NULL) AS orders_with_unknown_value,
       CASE WHEN count(*) = count(order_value) THEN round(avg(order_value), 2) END AS average_order_value,
       round(avg(item_rows), 4) AS average_item_rows,
       round(avg(item_units), 4) AS average_item_units
FROM per_order;
