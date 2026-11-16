-- ============================================================================
-- Project:  SQL Data Quality Audit (Olist Brazilian E-Commerce Dataset)
-- File:     queries/03_invalid_values.sql
-- Category: 3. Invalid Domain & Chronological Values (Checks DQ-09 through DQ-13)
-- ============================================================================

SET search_path TO olist_audit, public;

-- ----------------------------------------------------------------------------
-- Check DQ-09: Invalid item price (<= 0) or negative freight (< 0) in order_items
-- Expectation: Item price must be strictly positive (> 0) and freight >= 0.
-- Actual Result: 0 rows flagged (lowest item price is R$ 0.85; 383 items have
--                R$ 0.00 promotional free freight, 0 have negative freight).
-- ----------------------------------------------------------------------------
SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    price,
    freight_value
FROM order_items
WHERE price <= 0
   OR freight_value < 0;

INSERT INTO audit_summary (check_id, category, check_name, target_table, rows_flagged, severity)
SELECT
    'DQ-09',
    'Invalid Values',
    'Item price <= 0 or freight_value < 0 in order_items',
    'order_items',
    COUNT(*),
    'High'
FROM order_items
WHERE price <= 0
   OR freight_value < 0;

-- ----------------------------------------------------------------------------
-- Check DQ-10: Zero or negative payment amount (payment_value <= 0)
-- Expectation: Recorded payment transactions should have payment_value > 0.
-- Actual Result: 9 rows flagged (6 voucher rows and 3 'not_defined' rows on
--                canceled orders with payment_value = 0.00).
-- ----------------------------------------------------------------------------
SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM order_payments
WHERE payment_value <= 0
ORDER BY payment_type, order_id;

INSERT INTO audit_summary (check_id, category, check_name, target_table, rows_flagged, severity)
SELECT
    'DQ-10',
    'Invalid Values',
    'Zero or negative payment_value (<= 0) in order_payments',
    'order_payments',
    COUNT(*),
    'Medium'
FROM order_payments
WHERE payment_value <= 0;

INSERT INTO audit_flagged_records (
    check_id, category, check_name, severity, entity_type, entity_id,
    secondary_id, issue_detail, expected_value, actual_value
)
SELECT
    'DQ-10',
    'Invalid Values',
    'Zero or negative payment_value (<= 0) in order_payments',
    'Medium',
    'order_id',
    order_id,
    'seq=' || CAST(payment_sequential AS VARCHAR) || ' (' || payment_type || ')',
    'Payment transaction has zero or negative value',
    '> 0.00',
    CAST(payment_value AS VARCHAR)
FROM order_payments
WHERE payment_value <= 0;

-- ----------------------------------------------------------------------------
-- Check DQ-11: Customer delivery timestamp before carrier handoff date
-- Expectation: order_delivered_customer_date >= order_delivered_carrier_date.
-- Actual Result: 23 rows flagged where customer delivery is recorded earlier
--                than logistics carrier handoff.
-- ----------------------------------------------------------------------------
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    ROUND(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_delivered_carrier_date)) / 3600.0, 2) AS hours_diff
FROM orders
WHERE order_delivered_customer_date < order_delivered_carrier_date
ORDER BY hours_diff ASC;

INSERT INTO audit_summary (check_id, category, check_name, target_table, rows_flagged, severity)
SELECT
    'DQ-11',
    'Invalid Values',
    'Customer delivery timestamp before carrier handoff date',
    'orders',
    COUNT(*),
    'High'
FROM orders
WHERE order_delivered_customer_date < order_delivered_carrier_date;

INSERT INTO audit_flagged_records (
    check_id, category, check_name, severity, entity_type, entity_id,
    secondary_id, issue_detail, expected_value, actual_value
)
SELECT
    'DQ-11',
    'Invalid Values',
    'Customer delivery timestamp before carrier handoff date',
    'High',
    'order_id',
    order_id,
    customer_id,
    'order_delivered_customer_date precedes order_delivered_carrier_date',
    '>= ' || CAST(order_delivered_carrier_date AS VARCHAR),
    CAST(order_delivered_customer_date AS VARCHAR)
FROM orders
WHERE order_delivered_customer_date < order_delivered_carrier_date;

-- ----------------------------------------------------------------------------
-- Check DQ-12: Carrier handoff date before order purchase timestamp
-- Expectation: An order cannot be handed to the carrier before purchase
--              (order_delivered_carrier_date >= order_purchase_timestamp).
-- Actual Result: 166 rows flagged.
-- ----------------------------------------------------------------------------
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_delivered_carrier_date,
    ROUND(EXTRACT(EPOCH FROM (order_delivered_carrier_date - order_purchase_timestamp)) / 60.0, 2) AS minutes_diff
FROM orders
WHERE order_delivered_carrier_date < order_purchase_timestamp
ORDER BY minutes_diff ASC;

INSERT INTO audit_summary (check_id, category, check_name, target_table, rows_flagged, severity)
SELECT
    'DQ-12',
    'Invalid Values',
    'Carrier handoff date before purchase timestamp',
    'orders',
    COUNT(*),
    'High'
FROM orders
WHERE order_delivered_carrier_date < order_purchase_timestamp;

INSERT INTO audit_flagged_records (
    check_id, category, check_name, severity, entity_type, entity_id,
    secondary_id, issue_detail, expected_value, actual_value
)
SELECT
    'DQ-12',
    'Invalid Values',
    'Carrier handoff date before purchase timestamp',
    'High',
    'order_id',
    order_id,
    customer_id,
    'order_delivered_carrier_date precedes order_purchase_timestamp',
    '>= ' || CAST(order_purchase_timestamp AS VARCHAR),
    CAST(order_delivered_carrier_date AS VARCHAR)
FROM orders
WHERE order_delivered_carrier_date < order_purchase_timestamp;

-- ----------------------------------------------------------------------------
-- Check DQ-13: Products with zero or negative weight (product_weight_g <= 0)
-- Expectation: Physical shipped merchandise must have weight > 0 grams.
-- Actual Result: 4 products flagged with product_weight_g = 0 (all in category
--                'cama_mesa_banho' / bed_bath_table).
-- ----------------------------------------------------------------------------
SELECT
    product_id,
    product_category_name,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM products
WHERE product_weight_g <= 0;

INSERT INTO audit_summary (check_id, category, check_name, target_table, rows_flagged, severity)
SELECT
    'DQ-13',
    'Invalid Values',
    'Product weight <= 0 grams in products',
    'products',
    COUNT(*),
    'Medium'
FROM products
WHERE product_weight_g <= 0;

INSERT INTO audit_flagged_records (
    check_id, category, check_name, severity, entity_type, entity_id,
    secondary_id, issue_detail, expected_value, actual_value
)
SELECT
    'DQ-13',
    'Invalid Values',
    'Product weight <= 0 grams in products',
    'Medium',
    'product_id',
    product_id,
    product_category_name,
    'Physical product has zero weight (0g) affecting freight calculation',
    '> 0g',
    CAST(product_weight_g AS VARCHAR) || 'g'
FROM products
WHERE product_weight_g <= 0;

