-- ============================================================================
-- Project:  SQL Data Quality Audit (Olist Brazilian E-Commerce Dataset)
-- File:     queries/04_orphan_records.sql
-- Category: 4. Orphan & Referential Integrity Checks (Checks DQ-14 through DQ-17)
-- ============================================================================

SET search_path TO olist_audit, public;

-- ----------------------------------------------------------------------------
-- Check DQ-14: Orphan orders with no matching customer in customers
-- Expectation: Every order.customer_id must exist in customers.customer_id.
-- Actual Result: 0 rows flagged.
-- ----------------------------------------------------------------------------
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

INSERT INTO audit_summary (check_id, category, check_name, target_table, rows_flagged, severity)
SELECT
    'DQ-14',
    'Orphan Records',
    'Orders with no matching customer record',
    'orders -> customers',
    COUNT(*),
    'High'
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- ----------------------------------------------------------------------------
-- Check DQ-15: Orders with no payment record (or orphan payments with no order)
-- Expectation: Every order must have >= 1 payment record in order_payments,
--              and every payment must reference a valid order in orders.
-- Actual Result: 1 delivered order (bfbd0f9bdef84302105ad712db648a6c) has 0
--                payment records in order_payments (0 payments lack an order).
-- ----------------------------------------------------------------------------
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date
FROM orders o
LEFT JOIN order_payments p ON o.order_id = p.order_id
WHERE p.order_id IS NULL;

INSERT INTO audit_summary (check_id, category, check_name, target_table, rows_flagged, severity)
SELECT
    'DQ-15',
    'Orphan Records',
    'Orders missing payment records in order_payments',
    'orders -> order_payments',
    COUNT(*),
    'High'
FROM orders o
LEFT JOIN order_payments p ON o.order_id = p.order_id
WHERE p.order_id IS NULL;

INSERT INTO audit_flagged_records (
    check_id, category, check_name, severity, entity_type, entity_id,
    secondary_id, issue_detail, expected_value, actual_value
)
SELECT
    'DQ-15',
    'Orphan Records',
    'Orders missing payment records in order_payments',
    'High',
    'order_id',
    o.order_id,
    o.customer_id,
    'Order (status=' || o.order_status || ') has no matching rows in order_payments',
    '>= 1 payment row',
    '0 payment rows'
FROM orders o
LEFT JOIN order_payments p ON o.order_id = p.order_id
WHERE p.order_id IS NULL;

-- ----------------------------------------------------------------------------
-- Check DQ-16: Orders with no line items in order_items
-- Expectation: Orders should have at least one item in order_items.
-- Actual Result: 775 orders have no matching rows in order_items (603 status
--                'unavailable', 164 'canceled', 5 'created', 2 'invoiced',
--                1 'shipped').
-- ----------------------------------------------------------------------------
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL
ORDER BY o.order_status, o.order_purchase_timestamp;

INSERT INTO audit_summary (check_id, category, check_name, target_table, rows_flagged, severity)
SELECT
    'DQ-16',
    'Orphan Records',
    'Orders with no line items in order_items',
    'orders -> order_items',
    COUNT(*),
    'Medium'
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL;

INSERT INTO audit_flagged_records (
    check_id, category, check_name, severity, entity_type, entity_id,
    secondary_id, issue_detail, expected_value, actual_value
)
SELECT
    'DQ-16',
    'Orphan Records',
    'Orders with no line items in order_items',
    'Medium',
    'order_id',
    o.order_id,
    o.order_status,
    'Order exists in orders table (status=' || o.order_status || ') with 0 rows in order_items',
    '>= 1 order_item row',
    '0 order_item rows'
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL;

-- ----------------------------------------------------------------------------
-- Check DQ-17: Products with category missing from category_translation
-- Expectation: Every non-null product_category_name in products should exist
--              in category_translation.
-- Actual Result: 13 products across 2 untranslated categories:
--                'portateis_cozinha_e_preparadores_de_alimentos' (10 products)
--                and 'pc_gamer' (3 products).
-- ----------------------------------------------------------------------------
SELECT
    p.product_id,
    p.product_category_name,
    ct.product_category_name_english
FROM products p
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name IS NULL
ORDER BY p.product_category_name, p.product_id;

INSERT INTO audit_summary (check_id, category, check_name, target_table, rows_flagged, severity)
SELECT
    'DQ-17',
    'Orphan Records',
    'Products with category missing in category_translation',
    'products -> category_translation',
    COUNT(*),
    'Low'
FROM products p
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name IS NULL;

INSERT INTO audit_flagged_records (
    check_id, category, check_name, severity, entity_type, entity_id,
    secondary_id, issue_detail, expected_value, actual_value
)
SELECT
    'DQ-17',
    'Orphan Records',
    'Products with category missing in category_translation',
    'Low',
    'product_id',
    p.product_id,
    p.product_category_name,
    'Non-null product_category_name has no English mapping in category_translation',
    'English category translation',
    'Missing in category_translation'
FROM products p
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name IS NULL;

