-- Пересборка восьми таблиц текущего снимка из raw. psql должен запускаться
-- с ON_ERROR_STOP=1; BEGIN/COMMIT обеспечивают откат всей сборки при ошибке.
BEGIN;

CREATE SCHEMA IF NOT EXISTS core;

DROP TABLE IF EXISTS core.order_reviews;
DROP TABLE IF EXISTS core.order_payments;
DROP TABLE IF EXISTS core.order_items;
DROP TABLE IF EXISTS core.orders;
DROP TABLE IF EXISTS core.products;
DROP TABLE IF EXISTS core.category_translations;
DROP TABLE IF EXISTS core.sellers;
DROP TABLE IF EXISTS core.customers;

CREATE TABLE core.customers (
    customer_id text PRIMARY KEY,
    customer_unique_id text NOT NULL,
    customer_zip_code_prefix text,
    customer_city text,
    customer_state text
);
CREATE TABLE core.sellers (
    seller_id text PRIMARY KEY,
    seller_zip_code_prefix text,
    seller_city text,
    seller_state text
);
CREATE TABLE core.category_translations (
    product_category_name text PRIMARY KEY,
    product_category_name_english text
);
CREATE TABLE core.products (
    product_id text PRIMARY KEY,
    product_category_name text,
    product_name_length integer,
    product_description_length integer,
    product_photos_qty integer,
    product_weight_g numeric,
    product_length_cm numeric,
    product_height_cm numeric,
    product_width_cm numeric
);
CREATE TABLE core.orders (
    order_id text PRIMARY KEY,
    customer_id text NOT NULL REFERENCES core.customers(customer_id),
    order_status text NOT NULL,
    order_purchase_timestamp timestamp,
    order_approved_at timestamp,
    order_delivered_carrier_date timestamp,
    order_delivered_customer_date timestamp,
    order_estimated_delivery_date timestamp
);
CREATE TABLE core.order_items (
    order_id text NOT NULL REFERENCES core.orders(order_id),
    order_item_id integer NOT NULL,
    product_id text NOT NULL REFERENCES core.products(product_id),
    seller_id text NOT NULL REFERENCES core.sellers(seller_id),
    shipping_limit_date timestamp,
    price numeric,
    freight_value numeric,
    PRIMARY KEY (order_id, order_item_id)
);
CREATE TABLE core.order_payments (
    order_id text NOT NULL REFERENCES core.orders(order_id),
    payment_sequential integer NOT NULL,
    payment_type text,
    payment_installments integer,
    payment_value numeric,
    PRIMARY KEY (order_id, payment_sequential)
);
CREATE TABLE core.order_reviews (
    review_id text NOT NULL,
    order_id text NOT NULL REFERENCES core.orders(order_id),
    review_score integer,
    review_comment_title text,
    review_comment_message text,
    review_creation_date timestamp,
    review_answer_timestamp timestamp,
    PRIMARY KEY (review_id, order_id)
);

INSERT INTO core.customers
SELECT NULLIF(customer_id, ''), NULLIF(customer_unique_id, ''),
       NULLIF(customer_zip_code_prefix, ''), NULLIF(customer_city, ''), NULLIF(customer_state, '')
FROM raw.customers;

INSERT INTO core.sellers
SELECT NULLIF(seller_id, ''), NULLIF(seller_zip_code_prefix, ''),
       NULLIF(seller_city, ''), NULLIF(seller_state, '')
FROM raw.sellers;

INSERT INTO core.category_translations
SELECT NULLIF(product_category_name, ''), NULLIF(product_category_name_english, '')
FROM raw.product_category_translation;

INSERT INTO core.products
SELECT NULLIF(product_id, ''), NULLIF(product_category_name, ''),
       NULLIF(product_name_lenght, '')::integer, NULLIF(product_description_lenght, '')::integer,
       NULLIF(product_photos_qty, '')::integer, NULLIF(product_weight_g, '')::numeric,
       NULLIF(product_length_cm, '')::numeric, NULLIF(product_height_cm, '')::numeric,
       NULLIF(product_width_cm, '')::numeric
FROM raw.products;

INSERT INTO core.orders
SELECT NULLIF(order_id, ''), NULLIF(customer_id, ''), NULLIF(order_status, ''),
       NULLIF(order_purchase_timestamp, '')::timestamp, NULLIF(order_approved_at, '')::timestamp,
       NULLIF(order_delivered_carrier_date, '')::timestamp, NULLIF(order_delivered_customer_date, '')::timestamp,
       NULLIF(order_estimated_delivery_date, '')::timestamp
FROM raw.orders;

INSERT INTO core.order_items
SELECT NULLIF(order_id, ''), NULLIF(order_item_id, '')::integer,
       NULLIF(product_id, ''), NULLIF(seller_id, ''), NULLIF(shipping_limit_date, '')::timestamp,
       NULLIF(price, '')::numeric, NULLIF(freight_value, '')::numeric
FROM raw.order_items;

INSERT INTO core.order_payments
SELECT NULLIF(order_id, ''), NULLIF(payment_sequential, '')::integer, NULLIF(payment_type, ''),
       NULLIF(payment_installments, '')::integer, NULLIF(payment_value, '')::numeric
FROM raw.order_payments;

INSERT INTO core.order_reviews
SELECT NULLIF(review_id, ''), NULLIF(order_id, ''), NULLIF(review_score, '')::integer,
       NULLIF(review_comment_title, ''), NULLIF(review_comment_message, ''),
       NULLIF(review_creation_date, '')::timestamp, NULLIF(review_answer_timestamp, '')::timestamp
FROM raw.order_reviews;

CREATE INDEX customers_unique_id_idx ON core.customers(customer_unique_id);
CREATE INDEX orders_customer_id_idx ON core.orders(customer_id);
CREATE INDEX orders_purchase_timestamp_idx ON core.orders(order_purchase_timestamp);
CREATE INDEX order_items_product_id_idx ON core.order_items(product_id);
CREATE INDEX order_items_seller_id_idx ON core.order_items(seller_id);
CREATE INDEX order_reviews_order_id_idx ON core.order_reviews(order_id);

-- Непустая база и сохранность числа строк: ошибка откатит всю сборку.
DO $$
DECLARE source_table text; model_table text; raw_count bigint; core_count bigint;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM raw.orders) THEN
        RAISE EXCEPTION 'raw.orders пустая: сначала загрузите исходные данные';
    END IF;
    FOR source_table, model_table IN
        SELECT * FROM (VALUES
            ('customers', 'customers'), ('sellers', 'sellers'),
            ('product_category_translation', 'category_translations'), ('products', 'products'),
            ('orders', 'orders'), ('order_items', 'order_items'),
            ('order_payments', 'order_payments'), ('order_reviews', 'order_reviews')
        ) AS mapping(source_name, model_name)
    LOOP
        EXECUTE format('SELECT count(*) FROM raw.%I', source_table) INTO raw_count;
        EXECUTE format('SELECT count(*) FROM core.%I', model_table) INTO core_count;
        IF raw_count <> core_count THEN
            RAISE EXCEPTION 'Несовпадение числа строк raw.% (%) и core.% (%)',
                source_table, raw_count, model_table, core_count;
        END IF;
        RAISE NOTICE 'raw.% → core.%: % строк', source_table, model_table, core_count;
    END LOOP;
END $$;

ANALYZE core.customers;
ANALYZE core.sellers;
ANALYZE core.category_translations;
ANALYZE core.products;
ANALYZE core.orders;
ANALYZE core.order_items;
ANALYZE core.order_payments;
ANALYZE core.order_reviews;

COMMIT;
