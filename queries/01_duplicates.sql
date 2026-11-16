-- ============================================================================
-- Project:  SQL Data Quality Audit (Olist Brazilian E-Commerce Dataset)
-- File:     queries/01_duplicates.sql
-- Category: 1. Duplicate Records (Checks DQ-01 through DQ-04)
-- ============================================================================

SET search_path TO olist_audit, public;

-- ----------------------------------------------------------------------------
-- Check DQ-01: Duplicate order_id in orders
-- Expectation: order_id is the primary key of orders (0 duplicates expected).
-- Actual Result: 0 rows flagged.
-- ----------------------------------------------------------------------------
SELECT
    order_id,
    COUNT(*) AS occurrence_count
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

INSERT INTO audit_summary (check_id, category, check_name, target_table, rows_flagged, severity)
SELECT
    'DQ-01',
    'Duplicates',
    'Duplicate order_id in orders',
    'orders',
    COUNT(*),
    'High'
FROM (
    SELECT order_id
    FROM orders
    GROUP BY order_id
    HAVING COUNT(*) > 1
) dup_orders;

-- ----------------------------------------------------------------------------
-- Check DQ-02: Duplicate review_id in order_reviews
-- Expectation: Each review_id should uniquely identify one review event.
-- Actual Result: 789 distinct review_ids appear multiple times (814 excess
--                rows out of 99,224 total rows; 98,410 distinct review_ids).
--                Occurs when a single customer review is mapped across multiple
--                related orders by the same customer.
-- ----------------------------------------------------------------------------
SELECT
    review_id,
    COUNT(*) AS review_row_count,
    COUNT(DISTINCT order_id) AS distinct_orders_linked,
    STRING_AGG(order_id, ', ' ORDER BY order_id) AS linked_order_ids
FROM order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY review_row_count DESC, review_id;

INSERT INTO audit_summary (check_id, category, check_name, target_table, rows_flagged, severity)
SELECT
    'DQ-02',
    'Duplicates',
    'Duplicate review_id in order_reviews (excess rows)',
    'order_reviews',
    COALESCE(SUM(cnt - 1), 0),
    'High'
FROM (
    SELECT review_id, COUNT(*) AS cnt
    FROM order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
) dup_reviews;

INSERT INTO audit_flagged_records (
    check_id, category, check_name, severity, entity_type, entity_id,
    secondary_id, issue_detail, expected_value, actual_value
)
SELECT
    'DQ-02',
    'Duplicates',
    'Duplicate review_id in order_reviews',
    'High',
    'review_id',
    r.review_id,
    r.order_id,
    'Same review_id linked to multiple order_id records',
    '1 row per review_id',
    CAST(dup.cnt AS VARCHAR) || ' rows'
FROM order_reviews r
INNER JOIN (
    SELECT review_id, COUNT(*) AS cnt
    FROM order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
) dup ON r.review_id = dup.review_id;

-- ----------------------------------------------------------------------------
-- Check DQ-03: Exact duplicate rows in geolocation
-- Expectation: Reference tables should not store redundant identical rows.
-- Actual Result: 261,831 exact duplicate rows out of 1,000,163 total rows.
-- ----------------------------------------------------------------------------
SELECT
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state,
    COUNT(*) AS exact_duplicate_count
FROM geolocation
GROUP BY
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
HAVING COUNT(*) > 1
ORDER BY exact_duplicate_count DESC
LIMIT 100;

INSERT INTO audit_summary (check_id, category, check_name, target_table, rows_flagged, severity)
SELECT
    'DQ-03',
    'Duplicates',
    'Exact duplicate rows in geolocation',
    'geolocation',
    COALESCE(SUM(cnt - 1), 0),
    'Medium'
FROM (
    SELECT COUNT(*) AS cnt
    FROM geolocation
    GROUP BY
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state
    HAVING COUNT(*) > 1
) dup_geo;

-- ----------------------------------------------------------------------------
-- Check DQ-04: Duplicate (order_id, payment_sequential) in order_payments
-- Expectation: Composite key (order_id, payment_sequential) must be unique.
-- Actual Result: 0 rows flagged.
-- ----------------------------------------------------------------------------
SELECT
    order_id,
    payment_sequential,
    COUNT(*) AS duplicate_count
FROM order_payments
GROUP BY order_id, payment_sequential
HAVING COUNT(*) > 1;

INSERT INTO audit_summary (check_id, category, check_name, target_table, rows_flagged, severity)
SELECT
    'DQ-04',
    'Duplicates',
    'Duplicate (order_id, payment_sequential) in order_payments',
    'order_payments',
    COUNT(*),
    'High'
FROM (
    SELECT order_id, payment_sequential
    FROM order_payments
    GROUP BY order_id, payment_sequential
    HAVING COUNT(*) > 1
) dup_pay;

