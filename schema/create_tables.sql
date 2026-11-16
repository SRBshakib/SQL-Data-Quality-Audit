-- ============================================================================
-- Project: SQL Data Quality Audit (Olist Brazilian E-Commerce Dataset)
-- File:    schema/create_tables.sql
-- Purpose: Create raw audit tables (unconstrained to allow dirty data ingestion
--          for auditing), performance indexes, CSV load commands, and the
--          unified audit results tables.
-- Target:  PostgreSQL 14+ (compatible with DBeaver CSV Import & psql \copy)
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS olist_audit;
SET search_path TO olist_audit, public;

-- Drop tables if re-running the audit from scratch
DROP TABLE IF EXISTS audit_flagged_records CASCADE;
DROP TABLE IF EXISTS audit_summary CASCADE;
DROP TABLE IF EXISTS category_translation CASCADE;
DROP TABLE IF EXISTS geolocation CASCADE;
DROP TABLE IF EXISTS order_reviews CASCADE;
DROP TABLE IF EXISTS order_payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS sellers CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

-- ============================================================================
-- 1. CORE E-COMMERCE TABLES (Staging mode: permissive constraints for auditing)
-- ============================================================================

CREATE TABLE customers (
    customer_id               VARCHAR(64),
    customer_unique_id       VARCHAR(64),
    customer_zip_code_prefix VARCHAR(10),
    customer_city            VARCHAR(100),
    customer_state           CHAR(2)
);

CREATE TABLE sellers (
    seller_id                VARCHAR(64),
    seller_zip_code_prefix   VARCHAR(10),
    seller_city              VARCHAR(100),
    seller_state             CHAR(2)
);

CREATE TABLE products (
    product_id                 VARCHAR(64),
    product_category_name      VARCHAR(100),
    product_name_lenght        INTEGER,      -- Note: typo preserved from source CSV header
    product_description_lenght INTEGER,      -- Note: typo preserved from source CSV header
    product_photos_qty         INTEGER,
    product_weight_g           NUMERIC(12, 2),
    product_length_cm          NUMERIC(10, 2),
    product_height_cm          NUMERIC(10, 2),
    product_width_cm           NUMERIC(10, 2)
);

CREATE TABLE orders (
    order_id                      VARCHAR(64),
    customer_id                   VARCHAR(64),
    order_status                  VARCHAR(32),
    order_purchase_timestamp      TIMESTAMP,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

CREATE TABLE order_items (
    order_id            VARCHAR(64),
    order_item_id       INTEGER,
    product_id          VARCHAR(64),
    seller_id           VARCHAR(64),
    shipping_limit_date TIMESTAMP,
    price               NUMERIC(12, 2),
    freight_value       NUMERIC(12, 2)
);

CREATE TABLE order_payments (
    order_id             VARCHAR(64),
    payment_sequential   INTEGER,
    payment_type         VARCHAR(32),
    payment_installments INTEGER,
    payment_value        NUMERIC(12, 2)
);

CREATE TABLE order_reviews (
    review_id               VARCHAR(64),
    order_id                VARCHAR(64),
    review_score            INTEGER,
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

CREATE TABLE geolocation (
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat             NUMERIC(12, 8),
    geolocation_lng             NUMERIC(12, 8),
    geolocation_city            VARCHAR(100),
    geolocation_state           CHAR(2)
);

CREATE TABLE category_translation (
    product_category_name         VARCHAR(100),
    product_category_name_english VARCHAR(100)
);

-- ============================================================================
-- 2. AUDIT REPORTING TABLES
-- ============================================================================

CREATE TABLE audit_summary (
    check_id        VARCHAR(16) PRIMARY KEY,
    category        VARCHAR(40) NOT NULL,
    check_name      VARCHAR(120) NOT NULL,
    target_table    VARCHAR(64) NOT NULL,
    rows_flagged    INTEGER NOT NULL,
    severity        VARCHAR(16) NOT NULL,
    audited_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE audit_flagged_records (
    check_id        VARCHAR(16) NOT NULL,
    category        VARCHAR(40) NOT NULL,
    check_name      VARCHAR(120) NOT NULL,
    severity        VARCHAR(16) NOT NULL,
    entity_type     VARCHAR(32) NOT NULL,
    entity_id       VARCHAR(128) NOT NULL,
    secondary_id    VARCHAR(128),
    issue_detail    TEXT NOT NULL,
    expected_value  VARCHAR(128),
    actual_value    VARCHAR(128)
);

-- ============================================================================
-- 3. INDEXES FOR FAST AUDIT EXECUTION
-- ============================================================================

CREATE INDEX idx_customers_id          ON customers (customer_id);
CREATE INDEX idx_customers_unique_id   ON customers (customer_unique_id);
CREATE INDEX idx_orders_id             ON orders (order_id);
CREATE INDEX idx_orders_customer_id    ON orders (customer_id);
CREATE INDEX idx_orders_status         ON orders (order_status);
CREATE INDEX idx_order_items_order_id  ON order_items (order_id);
CREATE INDEX idx_order_items_prod_id   ON order_items (product_id);
CREATE INDEX idx_order_items_seller_id ON order_items (seller_id);
CREATE INDEX idx_payments_order_id     ON order_payments (order_id);
CREATE INDEX idx_reviews_order_id      ON order_reviews (order_id);
CREATE INDEX idx_reviews_review_id     ON order_reviews (review_id);
CREATE INDEX idx_products_id           ON products (product_id);
CREATE INDEX idx_sellers_id            ON sellers (seller_id);
CREATE INDEX idx_geo_zip               ON geolocation (geolocation_zip_code_prefix);

-- ============================================================================
-- 4. DATA INGESTION (PostgreSQL psql CLI commands)
--    If using DBeaver: Right-click each table -> Import Data -> CSV
-- ============================================================================
/*
\copy olist_audit.customers            FROM 'data/olist_customers_dataset.csv'            WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy olist_audit.sellers              FROM 'data/olist_sellers_dataset.csv'              WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy olist_audit.products             FROM 'data/olist_products_dataset.csv'             WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy olist_audit.orders               FROM 'data/olist_orders_dataset.csv'               WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy olist_audit.order_items          FROM 'data/olist_order_items_dataset.csv'          WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy olist_audit.order_payments       FROM 'data/olist_order_payments_dataset.csv'       WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy olist_audit.order_reviews        FROM 'data/olist_order_reviews_dataset.csv'        WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy olist_audit.geolocation          FROM 'data/olist_geolocation_dataset.csv'          WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy olist_audit.category_translation FROM 'data/product_category_name_translation.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
*/

