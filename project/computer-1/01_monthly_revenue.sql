-- Вопрос 1. Все оформленные заказы по дате покупки; выручка — только
-- товарные цены delivered-заказов. Один заказ считается один раз.
WITH months AS (
    SELECT month_start::date AS month_start
    FROM generate_series(
        timestamp '2016-09-01', timestamp '2018-08-01', interval '1 month'
    ) AS series(month_start)
), order_totals AS (
    SELECT order_id, sum(price) AS goods_total
    FROM core.order_items
    GROUP BY order_id
), monthly AS (
    SELECT date_trunc('month', o.order_purchase_timestamp)::date AS month_start,
           count(*) AS order_count,
           sum(CASE WHEN o.order_status = 'delivered'
                    THEN COALESCE(i.goods_total, 0) ELSE 0 END) AS revenue
    FROM core.orders AS o
    LEFT JOIN order_totals AS i USING (order_id)
    WHERE o.order_purchase_timestamp >= timestamp '2016-09-01'
      AND o.order_purchase_timestamp <  timestamp '2018-09-01'
    GROUP BY 1
)
SELECT m.month_start AS month,
       COALESCE(a.order_count, 0) AS order_count,
       COALESCE(a.revenue, 0::numeric) AS revenue
FROM months AS m
LEFT JOIN monthly AS a USING (month_start)
ORDER BY m.month_start;
