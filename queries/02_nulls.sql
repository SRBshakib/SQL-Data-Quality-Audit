-- ============================================================================
-- Project:  SQL Data Quality Audit (Olist Brazilian E-Commerce Dataset)
-- File:     queries/02_nulls.sql
-- Category: 2. NULL / Missing Value Checks (Checks DQ-05 through DQ-08)
-- ============================================================================

SET search_path TO olist_audit, public;

-- ----------------------------------------------------------------------------
-- Check DQ-05: Delivered orders missing customer delivery timestamp
-- Expectation: Orders with order_status = 'delivered' must have a non-null
--              order_delivered_customer_date.
-- Actual Result: 8 rows flagged.
-- ----------------------------------------------------------------------------
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL
ORDER BY order_purchase_timestamp;

INSERT INTO audit_summary (check_id, category, check_name, target_table, rows_flagged, severity)
SELECT
    'DQ-05',
    'NULLs',
    'Missing delivery date on delivered orders',
    'orders',
    COUNT(*),
    'High'
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

INSERT INTO audit_flagged_records (
    check_id, category, check_name, severity, entity_type, entity_id,
    secondary_id, issue_detail, expected_value, actual_value
)
SELECT
    'DQ-05',
    'NULLs',
    'Missing delivery date on delivered orders',
    'High',
    'order_id',
    order_id,
    customer_id,
    'Order marked delivered but order_delivered_customer_date is NULL',
    'NOT NULL timestamp',
    'NULL'
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

-- ----------------------------------------------------------------------------
-- Check DQ-06: Delivered orders missing payment approval timestamp
-- Expectation: Delivered orders must have been approved (order_approved_at IS NOT NULL).
-- Actual Result: 14 rows flagged.
-- ----------------------------------------------------------------------------
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_customer_date
FROM orders
WHERE order_status = 'delivered'
  AND order_approved_at IS NULL
ORDER BY order_purchase_timestamp;

INSERT INTO audit_summary (check_id, category, check_name, target_table, rows_flagged, severity)
SELECT
    'DQ-06',
    'NULLs',
    'Missing approval timestamp on delivered orders',
    'orders',
    COUNT(*),
    'Medium'
FROM orders
WHERE order_status = 'delivered'
  AND order_approved_at IS NULL;

INSERT INTO audit_flagged_records (
    check_id, category, check_name, severity, entity_type, entity_id,
    secondary_id, issue_detail, expected_value, actual_value
)
SELECT
    'DQ-06',
    'NULLs',
    'Missing approval timestamp on delivered orders',
    'Medium',
    'order_id',
    order_id,
    customer_id,
    'Order marked delivered but order_approved_at is NULL',
    'NOT NULL timestamp',
    'NULL'
FROM orders
WHERE order_status = 'delivered'
  AND order_approved_at IS NULL;

-- ----------------------------------------------------------------------------
-- Check DQ-07: Delivered or shipped orders missing carrier handoff timestamp
-- Expectation: Orders in 'delivered' or 'shipped' status must have a non-null
--              order_delivered_carrier_date.
-- Actual Result: 2 rows flagged (both in 'delivered' status).
-- ----------------------------------------------------------------------------
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_delivered_carrier_date,
    order_delivered_customer_date
FROM orders
WHERE order_status IN ('delivered', 'shipped')
  AND order_delivered_carrier_date IS NULL;

INSERT INTO audit_summary (check_id, category, check_name, target_table, rows_flagged, severity)
SELECT
    'DQ-07',
    'NULLs',
    'Missing carrier handoff date on delivered/shipped orders',
    'orders',
    COUNT(*),
    'High'
FROM orders
WHERE order_status IN ('delivered', 'shipped')
  AND order_delivered_carrier_date IS NULL;

INSERT INTO audit_flagged_records (
    check_id, category, check_name, severity, entity_type, entity_id,
    secondary_id, issue_detail, expected_value, actual_value
)
SELECT
    'DQ-07',
    'NULLs',
    'Missing carrier handoff date on delivered/shipped orders',
    'High',
    'order_id',
    order_id,
    customer_id,
    'Order status is ' || order_status || ' but order_delivered_carrier_date is NULL',
    'NOT NULL timestamp',
    'NULL'
FROM orders
WHERE order_status IN ('delivered', 'shipped')
  AND order_delivered_carrier_date IS NULL;

-- ----------------------------------------------------------------------------
-- Check DQ-08: Products missing category name and catalog metadata
-- Expectation: Every product in products should have a product_category_name.
-- Actual Result: 610 products have NULL product_category_name (as well as NULL
--                name length, description length, and photos quantity).
-- ----------------------------------------------------------------------------
SELECT
    product_id,
    product_category_name,
    product_name_lenght,
    product_description_lenght,
    product_photos_qty,
    product_weight_g
FROM products
WHERE product_category_name IS NULL
ORDER BY product_id;

INSERT INTO audit_summary (check_id, category, check_name, target_table, rows_flagged, severity)
SELECT
    'DQ-08',
    'NULLs',
    'Products missing product_category_name and metadata',
    'products',
    COUNT(*),
    'Medium'
FROM products
WHERE product_category_name IS NULL;

INSERT INTO audit_flagged_records (
    check_id, category, check_name, severity, entity_type, entity_id,
    secondary_id, issue_detail, expected_value, actual_value
)
SELECT
    'DQ-08',
    'NULLs',
    'Products missing product_category_name and metadata',
    'Medium',
    'product_id',
    product_id,
    NULL,
    'Product record has NULL product_category_name, name_lenght, description_lenght, and photos_qty',
    'Valid category string',
    'NULL'
FROM products
WHERE product_category_name IS NULL;

