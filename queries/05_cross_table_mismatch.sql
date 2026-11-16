-- ============================================================================
-- Project:  SQL Data Quality Audit (Olist Brazilian E-Commerce Dataset)
-- File:     queries/05_cross_table_mismatch.sql
-- Category: 5. Cross-Table & State Reconciliation Mismatches (DQ-18 to DQ-20)
-- ============================================================================

SET search_path TO olist_audit, public;

-- ----------------------------------------------------------------------------
-- Check DQ-18: Order items total (price + freight) != sum of payments
-- Expectation: For any order present in both order_items and order_payments,
--              SUM(price + freight_value) should equal SUM(payment_value)
--              within a R$ 0.05 installment rounding tolerance.
-- Actual Result: 310 orders have a discrepancy > R$ 0.05 between line-item
--                totals and recorded payment totals (579 orders if using R$ 0.01).
-- ----------------------------------------------------------------------------
WITH item_totals AS (
    SELECT
        order_id,
        COUNT(*) AS item_count,
        ROUND(SUM(price + freight_value), 2) AS expected_order_total
    FROM order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        COUNT(*) AS payment_rows,
        ROUND(SUM(payment_value), 2) AS actual_payment_total
    FROM order_payments
    GROUP BY order_id
)
SELECT
    i.order_id,
    i.item_count,
    p.payment_rows,
    i.expected_order_total,
    p.actual_payment_total,
    ROUND(p.actual_payment_total - i.expected_order_total, 2) AS payment_diff
FROM item_totals i
INNER JOIN payment_totals p ON i.order_id = p.order_id
WHERE ABS(i.expected_order_total - p.actual_payment_total) > 0.05
ORDER BY ABS(i.expected_order_total - p.actual_payment_total) DESC;

INSERT INTO audit_summary (check_id, category, check_name, target_table, rows_flagged, severity)
WITH item_totals AS (
    SELECT order_id, ROUND(SUM(price + freight_value), 2) AS expected_order_total
    FROM order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT order_id, ROUND(SUM(payment_value), 2) AS actual_payment_total
    FROM order_payments
    GROUP BY order_id
)
SELECT
    'DQ-18',
    'Cross-Table Mismatch',
    'Payment total != order items total (diff > R$ 0.05)',
    'order_items <-> order_payments',
    COUNT(*),
    'Medium'
FROM item_totals i
INNER JOIN payment_totals p ON i.order_id = p.order_id
WHERE ABS(i.expected_order_total - p.actual_payment_total) > 0.05;

INSERT INTO audit_flagged_records (
    check_id, category, check_name, severity, entity_type, entity_id,
    secondary_id, issue_detail, expected_value, actual_value
)
WITH item_totals AS (
    SELECT order_id, ROUND(SUM(price + freight_value), 2) AS expected_order_total
    FROM order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT order_id, ROUND(SUM(payment_value), 2) AS actual_payment_total
    FROM order_payments
    GROUP BY order_id
)
SELECT
    'DQ-18',
    'Cross-Table Mismatch',
    'Payment total != order items total (diff > R$ 0.05)',
    'Medium',
    'order_id',
    i.order_id,
    'diff=' || CAST(ROUND(p.actual_payment_total - i.expected_order_total, 2) AS VARCHAR),
    'Sum of order_payments.payment_value does not match sum of order_items.(price + freight_value)',
    CAST(i.expected_order_total AS VARCHAR),
    CAST(p.actual_payment_total AS VARCHAR)
FROM item_totals i
INNER JOIN payment_totals p ON i.order_id = p.order_id
WHERE ABS(i.expected_order_total - p.actual_payment_total) > 0.05;

-- ----------------------------------------------------------------------------
-- Check DQ-19: Carrier handoff recorded before payment approval timestamp
-- Expectation: Fulfillment should not hand off parcels to the carrier before
--              payment approval (order_delivered_carrier_date >= order_approved_at).
-- Actual Result: 1,359 orders flagged where carrier handoff precedes approval.
-- ----------------------------------------------------------------------------
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    ROUND(EXTRACT(EPOCH FROM (order_delivered_carrier_date - order_approved_at)) / 3600.0, 2) AS hours_before_approval
FROM orders
WHERE order_delivered_carrier_date < order_approved_at
ORDER BY hours_before_approval ASC;

INSERT INTO audit_summary (check_id, category, check_name, target_table, rows_flagged, severity)
SELECT
    'DQ-19',
    'Cross-Table Mismatch',
    'Carrier handoff timestamp precedes payment approval',
    'orders',
    COUNT(*),
    'Medium'
FROM orders
WHERE order_delivered_carrier_date < order_approved_at;

INSERT INTO audit_flagged_records (
    check_id, category, check_name, severity, entity_type, entity_id,
    secondary_id, issue_detail, expected_value, actual_value
)
SELECT
    'DQ-19',
    'Cross-Table Mismatch',
    'Carrier handoff timestamp precedes payment approval',
    'Medium',
    'order_id',
    order_id,
    customer_id,
    'order_delivered_carrier_date is earlier than order_approved_at',
    '>= ' || CAST(order_approved_at AS VARCHAR),
    CAST(order_delivered_carrier_date AS VARCHAR)
FROM orders
WHERE order_delivered_carrier_date < order_approved_at;

-- ----------------------------------------------------------------------------
-- Check DQ-20: Canceled orders with a completed customer delivery timestamp
-- Expectation: Orders with order_status = 'canceled' should not have a
--              non-null order_delivered_customer_date.
-- Actual Result: 6 orders are marked 'canceled' despite having a recorded
--                customer delivery timestamp.
-- ----------------------------------------------------------------------------
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    COALESCE(SUM(p.payment_value), 0) AS total_paid
FROM orders o
LEFT JOIN order_payments p ON o.order_id = p.order_id
WHERE o.order_status = 'canceled'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date
ORDER BY o.order_purchase_timestamp;

INSERT INTO audit_summary (check_id, category, check_name, target_table, rows_flagged, severity)
SELECT
    'DQ-20',
    'Cross-Table Mismatch',
    'Canceled orders with a non-null customer delivery date',
    'orders',
    COUNT(*),
    'High'
FROM orders
WHERE order_status = 'canceled'
  AND order_delivered_customer_date IS NOT NULL;

INSERT INTO audit_flagged_records (
    check_id, category, check_name, severity, entity_type, entity_id,
    secondary_id, issue_detail, expected_value, actual_value
)
SELECT
    'DQ-20',
    'Cross-Table Mismatch',
    'Canceled orders with a non-null customer delivery date',
    'High',
    'order_id',
    order_id,
    customer_id,
    'Order has order_status = canceled but order_delivered_customer_date is populated',
    'NULL delivery date (or status = delivered)',
    CAST(order_delivered_customer_date AS VARCHAR)
FROM orders
WHERE order_status = 'canceled'
  AND order_delivered_customer_date IS NOT NULL;

-- ============================================================================
-- FINAL AUDIT SUMMARY & CSV EXPORT
-- ============================================================================
SELECT
    check_id,
    category,
    check_name,
    target_table,
    rows_flagged,
    severity
FROM audit_summary
ORDER BY check_id;

/*
-- Export summary and representative flagged rows to output/discrepancy_report.csv:
\copy (SELECT * FROM olist_audit.audit_flagged_records ORDER BY check_id, entity_id) TO 'output/discrepancy_report.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
*/

