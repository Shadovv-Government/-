-- Компьютер 4: сохранность и обработка особенностей исходной выгрузки (см. qa/README.md).
-- Читает raw (только для сверки) и core. Ничего не изменяет: read-only транзакция.
-- Запуск из project/:  psql -X -v ON_ERROR_STOP=1 --csv -f quality/computer-4/01_feature_preservation.sql
-- Столбцы: id, feature, check_name, expected (raw / ожидание QA), actual (core), status, comment.
-- Статусы: PASS -- условие выполнено; WARN -- особенность данных сохранена и объяснена;
--          FAIL -- потеря данных, дубли ключа, сломанная связь.
BEGIN TRANSACTION READ ONLY;
WITH
raw_blank_cat AS (SELECT count(*) n FROM raw.products WHERE NULLIF(btrim(product_category_name),'') IS NULL),
core_blank_cat AS (SELECT count(*) n FROM core.products WHERE product_category_name IS NULL),
raw_untr AS (
    SELECT count(*) n_products, count(DISTINCT p.product_category_name) n_cats
    FROM raw.products p
    WHERE NULLIF(btrim(p.product_category_name),'') IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM raw.product_category_translation t WHERE t.product_category_name = p.product_category_name)),
core_untr AS (
    SELECT count(*) n_products, count(DISTINCT p.product_category_name) n_cats
    FROM core.products p
    WHERE p.product_category_name IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM core.category_translations t WHERE t.product_category_name = p.product_category_name)),
raw_noitems AS (SELECT count(*) n FROM raw.orders o WHERE NOT EXISTS (SELECT 1 FROM raw.order_items i WHERE i.order_id = o.order_id)),
core_noitems AS (SELECT count(*) n FROM core.orders o WHERE NOT EXISTS (SELECT 1 FROM core.order_items i WHERE i.order_id = o.order_id)),
raw_nopay AS (SELECT count(*) n FROM raw.orders o WHERE NOT EXISTS (SELECT 1 FROM raw.order_payments p WHERE p.order_id = o.order_id)),
core_nopay AS (SELECT count(*) n FROM core.orders o WHERE NOT EXISTS (SELECT 1 FROM core.order_payments p WHERE p.order_id = o.order_id)),
raw_nodate AS (SELECT count(*) n FROM raw.orders WHERE order_status='delivered' AND NULLIF(btrim(order_delivered_customer_date),'') IS NULL),
core_nodate AS (SELECT count(*) n FROM core.orders WHERE order_status='delivered' AND order_delivered_customer_date IS NULL),
raw_multi AS (SELECT count(*) n FROM (SELECT order_id FROM raw.order_reviews GROUP BY 1 HAVING count(*)>1) x),
core_multi AS (SELECT count(*) n FROM (SELECT order_id FROM core.order_reviews GROUP BY 1 HAVING count(*)>1) x),
raw_dupid AS (SELECT count(*) - count(DISTINCT review_id) n FROM raw.order_reviews),
core_dupid AS (SELECT count(*) - count(DISTINCT review_id) n FROM core.order_reviews),
-- Выручка delivered-позиций, которая приходится на «особые» товары: показывает цену потери при INNER JOIN.
rev AS (
    SELECT
      SUM(i.price) AS total,
      SUM(i.price) FILTER (WHERE p.product_category_name IS NULL) AS blank_cat,
      SUM(i.price) FILTER (WHERE p.product_category_name IS NOT NULL AND t.product_category_name IS NULL) AS untranslated
    FROM core.order_items i
    JOIN core.orders o ON o.order_id = i.order_id AND o.order_status='delivered'
    LEFT JOIN core.products p ON p.product_id = i.product_id
    LEFT JOIN core.category_translations t ON t.product_category_name = p.product_category_name),
nodate_rev AS (
    SELECT COALESCE(SUM(i.price),0) AS s, count(DISTINCT o.order_id) AS orders
    FROM core.orders o JOIN core.order_items i USING (order_id)
    WHERE o.order_status='delivered' AND o.order_delivered_customer_date IS NULL),
-- Что произойдёт при неосторожном JOIN (иллюстрация для защиты, не дефект модели).
naive AS (
    SELECT SUM(i.price) AS inner_join_revenue
    FROM core.order_items i
    JOIN core.orders o ON o.order_id = i.order_id AND o.order_status='delivered'
    JOIN core.products p ON p.product_id = i.product_id
    JOIN core.category_translations t ON t.product_category_name = p.product_category_name),
fanout AS (
    SELECT SUM(i.price) AS revenue_with_reviews_join
    FROM core.order_items i
    JOIN core.orders o ON o.order_id = i.order_id AND o.order_status='delivered'
    JOIN core.order_reviews r ON r.order_id = i.order_id)
SELECT * FROM (
 SELECT 1 AS id, 'Пустая категория' AS feature, 'число товаров без категории raw = core' AS check_name,
        (SELECT n FROM raw_blank_cat)::text AS expected, (SELECT n FROM core_blank_cat)::text AS actual,
        CASE WHEN (SELECT n FROM raw_blank_cat) = (SELECT n FROM core_blank_cat) AND (SELECT n FROM core_blank_cat) = 610 THEN 'PASS' ELSE 'FAIL' END AS status,
        'Ожидание QA: 610. Пустая строка raw приведена к NULL.' AS comment
 UNION ALL SELECT 2, 'Пустая категория', 'выручка delivered по товарам без категории попала в UNKNOWN (>0)',
        'сумма = ' || (SELECT blank_cat FROM rev)::text, (SELECT COALESCE(SUM(price),0) FROM (
            SELECT i.price FROM core.order_items i JOIN core.orders o ON o.order_id=i.order_id AND o.order_status='delivered'
            LEFT JOIN core.products p ON p.product_id=i.product_id WHERE p.product_category_name IS NULL) z)::text,
        CASE WHEN (SELECT blank_cat FROM rev) > 0 THEN 'PASS' ELSE 'FAIL' END,
        'Эти деньги нельзя терять: при INNER JOIN на перевод они исчезают.'
 UNION ALL SELECT 3, 'Категория без перевода', 'товаров с категорией без перевода raw = core',
        (SELECT n_products FROM raw_untr)::text, (SELECT n_products FROM core_untr)::text,
        CASE WHEN (SELECT n_products FROM raw_untr) = (SELECT n_products FROM core_untr) AND (SELECT n_products FROM core_untr) = 13 THEN 'PASS' ELSE 'FAIL' END,
        'Ожидание QA: 13 товаров.'
 UNION ALL SELECT 4, 'Категория без перевода', 'различных категорий без перевода raw = core',
        (SELECT n_cats FROM raw_untr)::text, (SELECT n_cats FROM core_untr)::text,
        CASE WHEN (SELECT n_cats FROM raw_untr) = (SELECT n_cats FROM core_untr) THEN 'PASS' ELSE 'FAIL' END,
        'Эти категории выводятся под исходным португальским названием, а не сливаются в UNKNOWN.'
 UNION ALL SELECT 5, 'Категория без перевода', 'выручка delivered по непереведённым категориям (>0, сохранена)',
        '>0', (SELECT untranslated FROM rev)::text,
        CASE WHEN (SELECT untranslated FROM rev) > 0 THEN 'PASS' ELSE 'WARN' END,
        'Показывает, что fallback на исходное название действительно задействован.'
 UNION ALL SELECT 6, 'Заказы без позиций', 'число заказов без позиций raw = core',
        (SELECT n FROM raw_noitems)::text, (SELECT n FROM core_noitems)::text,
        CASE WHEN (SELECT n FROM raw_noitems) = (SELECT n FROM core_noitems) AND (SELECT n FROM core_noitems) = 775 THEN 'WARN' ELSE 'FAIL' END,
        'Ожидание QA: 775. Заказы сохранены в core.orders; WARN = особенность данных, не потеря. В выручку не попадают (нет price).'
 UNION ALL SELECT 7, 'Заказы без платежей', 'число заказов без платежей raw = core',
        (SELECT n FROM raw_nopay)::text, (SELECT n FROM core_nopay)::text,
        CASE WHEN (SELECT n FROM raw_nopay) = (SELECT n FROM core_nopay) AND (SELECT n FROM core_nopay) = 1 THEN 'WARN' ELSE 'FAIL' END,
        'Ожидание QA: 1. Заказ сохранён; не удалять автоматически.'
 UNION ALL SELECT 8, 'Delivered без даты вручения', 'число delivered-заказов без даты вручения raw = core',
        (SELECT n FROM raw_nodate)::text, (SELECT n FROM core_nodate)::text,
        CASE WHEN (SELECT n FROM raw_nodate) = (SELECT n FROM core_nodate) AND (SELECT n FROM core_nodate) = 8 THEN 'WARN' ELSE 'FAIL' END,
        'Ожидание QA: 8. Статус сохранён; пустая дата остаётся NULL, а не подменяется.'
 UNION ALL SELECT 9, 'Delivered без даты вручения', 'эти заказы остаются в выручке delivered (не исключены из-за отсутствия даты)',
        (SELECT orders FROM nodate_rev)::text || ' заказов', 'выручка ' || (SELECT s FROM nodate_rev)::text,
        CASE WHEN (SELECT s FROM nodate_rev) > 0 THEN 'PASS' ELSE 'WARN' END,
        'Если бы выручка требовала order_delivered_customer_date IS NOT NULL, итог 13 221 498.11 уменьшился бы на эту сумму.'
 UNION ALL SELECT 10, 'Несколько отзывов', 'заказов с несколькими отзывами raw = core',
        (SELECT n FROM raw_multi)::text, (SELECT n FROM core_multi)::text,
        CASE WHEN (SELECT n FROM raw_multi) = (SELECT n FROM core_multi) AND (SELECT n FROM core_multi) = 547 THEN 'WARN' ELSE 'FAIL' END,
        'Ожидание QA: 547. Связь заказ-отзыв 1:N сохранена.'
 UNION ALL SELECT 11, 'Несколько отзывов', 'лишние строки по review_id (повтор review_id) raw = core',
        (SELECT n FROM raw_dupid)::text, (SELECT n FROM core_dupid)::text,
        CASE WHEN (SELECT n FROM raw_dupid) = (SELECT n FROM core_dupid) AND (SELECT n FROM core_dupid) = 814 THEN 'WARN' ELSE 'FAIL' END,
        'Ожидание QA: 814. review_id не уникален, ключ -- пара (review_id, order_id); строки не схлопнуты.'
 UNION ALL SELECT 12, 'Иллюстрация потерь', 'INNER JOIN на перевод даёт меньшую выручку, чем LEFT JOIN',
        (SELECT total FROM rev)::text, (SELECT inner_join_revenue FROM naive)::text,
        CASE WHEN (SELECT inner_join_revenue FROM naive) < (SELECT total FROM rev) THEN 'WARN' ELSE 'PASS' END,
        'Не дефект core. Разница = выручка без категории + без перевода; именно её теряет неосторожный JOIN.'
 UNION ALL SELECT 13, 'Иллюстрация размножения', 'прямой JOIN позиций с отзывами без агрегации искажает выручку',
        (SELECT total FROM rev)::text, (SELECT revenue_with_reviews_join FROM fanout)::text,
        CASE WHEN (SELECT revenue_with_reviews_join FROM fanout) <> (SELECT total FROM rev) THEN 'WARN' ELSE 'PASS' END,
        'Не дефект core. Заказы без отзыва выпадают, заказы с несколькими отзывами дублируются; отзывы сводят к уровню заказа до соединения.'
) c ORDER BY id;
COMMIT;
