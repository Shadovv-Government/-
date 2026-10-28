-- Диагностика интерпретации вопроса 1 и полноты цен в выбранном периоде.
WITH scoped AS (
    SELECT * FROM core.orders
    WHERE order_purchase_timestamp >= timestamp '2016-09-01'
      AND order_purchase_timestamp < timestamp '2018-09-01'
), delivered_items AS (
    SELECT i.price
    FROM scoped o JOIN core.order_items i USING (order_id)
    WHERE o.order_status = 'delivered'
)
SELECT (SELECT count(*) FROM scoped) AS all_orders,
       (SELECT count(*) FROM scoped WHERE order_status = 'delivered') AS delivered_orders,
       (SELECT count(*) FROM core.orders WHERE order_purchase_timestamp IS NULL) AS orders_without_purchase_date,
       (SELECT count(*) FROM delivered_items WHERE price IS NULL) AS delivered_items_with_null_price,
       (SELECT COALESCE(sum(price), 0) FROM delivered_items) AS delivered_goods_revenue;
