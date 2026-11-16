# Data Quality Audit Findings — Olist Brazilian E-Commerce Dataset

## Executive Summary

An end-to-end SQL data quality audit was conducted across all **9 relational tables** (~1.55 million total records) of the **Olist Brazilian E-Commerce Public Dataset** (`2016–2018`). Using **20 automated validation checks** spanning five core dimensions—**Duplicates**, **NULLs**, **Invalid Values**, **Orphan Records**, and **Cross-Table Mismatches**—we identified **264,922 total flagged rows** (or **3,091 operational anomalies** when excluding `geolocation` log duplicates).

| Audit Category | Total Checks | Checks with Issues | Total Rows Flagged | Highest Severity |
| :--- | ---: | ---: | ---: | :--- |
| **1. Duplicates** | 4 | 2 | 262,645 | High |
| **2. NULL / Missing Values** | 4 | 4 | 634 | High |
| **3. Invalid Domain / Chronological Values** | 5 | 4 | 202 | High |
| **4. Orphan / Referential Integrity** | 4 | 3 | 789 | High |
| **5. Cross-Table & Lifecycle Mismatches** | 3 | 3 | 1,675 | High |
| **Total** | **20** | **16** | **265,945** | **High** |

---

## Category 1: Duplicate Records (`queries/01_duplicates.sql`)

### DQ-01: Duplicate `order_id` in `orders`
- **Rows Flagged:** `0` (out of 99,441 rows) — *Severity: High (Baseline Pass)*
- **Issue:** Verified primary key uniqueness on `orders.order_id`.
- **Business Impact:** Confirms that order-grain aggregations on the `orders` header table do not suffer from fan-out inflation.

### DQ-02: Duplicate `review_id` in `order_reviews`
- **Rows Flagged:** `814` excess rows across `789` distinct `review_id` values (`99,224` total rows vs. `98,410` unique `review_id`s) — *Severity: High*
- **Issue:** `review_id` is not unique in `order_reviews`. When a customer places multiple split orders during a single checkout session (e.g., fulfilled by different sellers), Olist's survey system links the same `review_id` to multiple `order_id`s.
- **Concrete Example:**
  - `review_id = 'dbdf1ea31790c8ecfcc6750525661a9b'` appears **3 times**, mapped to `order_id`s `002f98c0f7efd42638ed6100ca699b42`, `6c678c38f3a914c4b22f0c3222d29119`, and `f728f03d3c8b225d049266d74f5b2286`.
- **Suggested Fix:**
  - Define the primary key of `order_reviews` as the composite `(review_id, order_id)` rather than `review_id` alone.
  - When computing global review sentiment metrics, deduplicate by `review_id` (`COUNT(DISTINCT review_id)`), or aggregate at the `(review_id, order_id)` grain when joining to `orders`.
- **Business Impact:** Treating `review_id` as a primary key causes ingestion failures in strict warehouse schemas, while naive joins without composite keys double-count review comments in NLP pipelines and distort CSAT/NPS reporting.

### DQ-03: Exact Duplicate Rows in `geolocation`
- **Rows Flagged:** `261,831` redundant rows (out of `1,000,163` total rows; `738,332` distinct coordinate tuples and `19,015` distinct zip prefixes) — *Severity: Medium*
- **Issue:** Over 26.1% of the `geolocation` table consists of byte-for-byte identical rows (`geolocation_zip_code_prefix`, `lat`, `lng`, `city`, `state`). Furthermore, single zip code prefixes map to multiple coordinate samples and unnormalized city names (e.g., `sao paulo` vs. `são paulo`).
- **Concrete Example:**
  - `geolocation_zip_code_prefix = '24220'` (`niteroi`, `RJ`) has **1,146** identical coordinate rows.
- **Suggested Fix:**
  - Materialize a deduplicated dimension table `dim_geolocation` keyed on `geolocation_zip_code_prefix` using `AVG(geolocation_lat)`, `AVG(geolocation_lng)`, and `UPPER(UNACCENT(geolocation_city))`.
- **Business Impact:** Joining `orders` or `customers` directly to `geolocation` on `zip_code_prefix` causes a massive Cartesian fan-out (multiplying 99,441 orders into ~15+ million rows), corrupting revenue totals and crashing BI dashboards.

### DQ-04: Duplicate `(order_id, payment_sequential)` in `order_payments`
- **Rows Flagged:** `0` (out of 103,886 rows) — *Severity: High (Baseline Pass)*
- **Issue:** Verified uniqueness of the composite key `(order_id, payment_sequential)`.

---

## Category 2: NULL & Missing Values (`queries/02_nulls.sql`)

### DQ-05: Missing Customer Delivery Date on Delivered Orders
- **Rows Flagged:** `8` orders — *Severity: High*
- **Issue:** Eight orders have `order_status = 'delivered'` but `order_delivered_customer_date IS NULL`.
- **Concrete Example:**
  - `order_id = '2d1e2d5bf4dc7227b3bfebb81328c15f'` (`customer_id = 'ec05a6d8558c6455f0cbbd8a420ad34f'`), purchased `2017-11-28 17:44:07`, handed to carrier `2017-11-30 18:12:23`, `order_status = 'delivered'`, `order_delivered_customer_date = NULL`.
- **Suggested Fix:**
  - Add a database `CHECK` constraint: `CHECK (order_status <> 'delivered' OR order_delivered_customer_date IS NOT NULL)`.
  - For historical analytics, exclude these 8 rows from SLA lead-time calculations or impute using `order_estimated_delivery_date` flagged with an `is_delivery_date_imputed = TRUE` boolean column.
- **Business Impact:** Corrupts On-Time Delivery (OTD) rate and average transit duration KPIs; prevents accurate seller SLA penalty calculations.

### DQ-06: Missing Payment Approval Timestamp on Delivered Orders
- **Rows Flagged:** `14` orders — *Severity: Medium*
- **Issue:** Fourteen completed (`delivered`) orders have `order_approved_at IS NULL` despite having valid payment rows and carrier/customer delivery timestamps.
- **Concrete Example:**
  - `order_id = 'e04abd8149ef81b95221e88f6ed9ab6a'`, purchased `2017-02-18 14:40:00`, delivered `2017-03-01 13:25:33`, `order_approved_at = NULL`.
- **Suggested Fix:**
  - Backfill `order_approved_at` with `order_purchase_timestamp` when `order_status = 'delivered'` and `order_approved_at IS NULL`, as payment settlement succeeded prior to shipment.
- **Business Impact:** Causes `NULL` results when decomposing order-to-delivery lead time into *Payment Approval Time* (`approved_at - purchase_timestamp`) vs. *Seller Fulfillment Time* (`carrier_date - approved_at`).

### DQ-07: Missing Carrier Handoff Date on Delivered/Shipped Orders
- **Rows Flagged:** `2` orders — *Severity: High*
- **Issue:** Two orders in `'delivered'` status are missing `order_delivered_carrier_date` (one of which is also missing `order_delivered_customer_date`).
- **Concrete Example:**
  - `order_id = '2aa91108853cecb43c84a5dc5b277475'`, purchased `2017-09-29 08:52:58`, `order_delivered_carrier_date = NULL`, `order_delivered_customer_date = '2017-11-20 18:55:00'`.
- **Suggested Fix:**
  - Enforce state-machine transition validation in the order management microservice so an order cannot transition to `shipped` or `delivered` without a valid carrier scan timestamp.
- **Business Impact:** Breaks seller dispatch SLA monitoring (comparing `order_delivered_carrier_date` against `order_items.shipping_limit_date`).

### DQ-08: Products Missing `product_category_name` and Catalog Metadata
- **Rows Flagged:** `610` products (1.85% of 32,951 products) — *Severity: Medium*
- **Issue:** 610 product records have `NULL` values for `product_category_name`, `product_name_lenght`, `product_description_lenght`, and `product_photos_qty` (and 2 of these also lack physical dimensions/weight).
- **Concrete Example:**
  - `product_id = 'a41e356c76fab66334f36de622ecbd3a'` has `product_category_name = NULL` and `0` metadata fields, though `product_weight_g = 650`.
- **Suggested Fix:**
  - Map `NULL` category names to `'unclassified'` (`COALESCE(product_category_name, 'unclassified')`) in downstream analytical views so inner joins to category dimensions do not silently drop revenue.
- **Business Impact:** These 610 products account for **1,603 order line items** in `order_items`. Using an `INNER JOIN` to `category_translation` silently drops over R$ 170,000 in GMV from category-level financial reports.

---

## Category 3: Invalid Domain & Chronological Values (`queries/03_invalid_values.sql`)

### DQ-09: Item Price `<= 0` or Negative Freight (`< 0`) in `order_items`
- **Rows Flagged:** `0` rows — *Severity: High (Baseline Pass)*
- **Issue:** Verified that all 112,650 rows in `order_items` have `price > 0` (min `R$ 0.85`) and `freight_value >= 0` (`383` rows have `freight_value = 0.00` representing free shipping promotions).

### DQ-10: Zero or Negative Payment Amounts (`payment_value <= 0`)
- **Rows Flagged:** `9` rows — *Severity: Medium*
- **Issue:** Nine records in `order_payments` have `payment_value = 0.00` (`6` rows with `payment_type = 'voucher'` and `3` rows with `payment_type = 'not_defined'` on canceled orders). Additionally, 2 credit card rows have `payment_installments = 0`.
- **Concrete Example:**
  - `order_id = '00b1cb0320190ca0daa2c88b35206009'`, `payment_sequential = 1`, `payment_type = 'not_defined'`, `payment_value = 0.00`.
  - `order_id = '8bcbe01d44d147f90f0d71e9fbd3eb2a'`, `payment_sequential = 4`, `payment_type = 'voucher'`, `payment_value = 0.00`.
- **Suggested Fix:**
  - Filter out `payment_type = 'not_defined'` failed checkout attempts from the settled `order_payments` table and enforce `CHECK (payment_value > 0 OR payment_type = 'voucher')`.
- **Business Impact:** Skews average transaction value (ATV) metrics and introduces division-by-zero errors when computing payment fee percentages per transaction row.

### DQ-11: Customer Delivery Date Earlier Than Carrier Handoff Date
- **Rows Flagged:** `23` orders — *Severity: High*
- **Issue:** 23 orders record `order_delivered_customer_date < order_delivered_carrier_date`, a chronological impossibility where the customer appears to receive the package days before the carrier picked it up.
- **Concrete Example:**
  - `order_id = '2fb597c2f7720ab52ef16ca73d38c890'`: `order_delivered_carrier_date = '2017-07-10 19:50:48'`, `order_delivered_customer_date = '2017-07-05 15:43:29'` (`-124.12 hours` / `-5.17 days`).
- **Suggested Fix:**
  - Quarantine rows where `order_delivered_customer_date < order_delivered_carrier_date` in staging and reconcile carrier webhook ingestion timestamps (which overwrite `order_delivered_carrier_date` on late batch retries).
- **Business Impact:** Produces negative carrier transit times, distorting logistics partner performance rankings and ML delivery-time prediction models.

### DQ-12: Carrier Handoff Date Earlier Than Purchase Timestamp
- **Rows Flagged:** `166` orders — *Severity: High*
- **Issue:** 166 orders have `order_delivered_carrier_date < order_purchase_timestamp`, indicating that the seller handed the parcel to the carrier before the order was placed.
- **Concrete Example:**
  - `order_id = '7c48bb55e8e4f7e56d412e9653db37bc'`: `order_purchase_timestamp = '2018-07-16 18:40:53'`, `order_delivered_carrier_date = '2018-07-16 14:36:00'` (`-244.88 minutes`).
- **Suggested Fix:**
  - Standardize all seller/carrier webhook timestamps to UTC (`TIMESTAMPTZ`) upon ingestion; many of these ~3–5 hour negative offsets stem from timezone conversion bugs (BRT `UTC-3` vs. `UTC`) or manual date-only entries defaulting to `00:00:00`.
- **Business Impact:** Corrupts seller fulfillment speed metrics and inflates apparent same-day shipping rates.

### DQ-13: Physical Products with Zero Weight (`product_weight_g <= 0`)
- **Rows Flagged:** `4` products — *Severity: Medium*
- **Issue:** Four physical products in category `cama_mesa_banho` (bed/bath/table) have `product_weight_g = 0`.
- **Concrete Example:**
  - `product_id = '09ff539a621711667c43eba6a3bd8466'` (`cama_mesa_banho`, dimensions `30x25x10 cm`, `product_weight_g = 0`).
- **Suggested Fix:**
  - Enforce `CHECK (product_weight_g > 0)` in the catalog service and impute missing/zero weights using the median weight of `cama_mesa_banho` (`1,000g`).
- **Business Impact:** Undercharges freight fees at checkout since Correios/carrier shipping rates scale by volumetric and physical weight.

---

## Category 4: Orphan Records & Referential Integrity (`queries/04_orphan_records.sql`)

### DQ-14: Orders With No Matching Customer in `customers`
- **Rows Flagged:** `0` rows — *Severity: High (Baseline Pass)*
- **Issue:** Confirmed 100% referential integrity between `orders.customer_id` and `customers.customer_id`.

### DQ-15: Orders Missing Payment Records in `order_payments`
- **Rows Flagged:** `1` order — *Severity: High*
- **Issue:** One delivered order exists in `orders` and `order_items` (`3` items totaling `R$ 143.46`) but has **zero rows** in `order_payments`.
- **Concrete Example:**
  - `order_id = 'bfbd0f9bdef84302105ad712db648a6c'` (`customer_id = '86dc2ffce2dfff336de2f386a786e574'`, `order_status = 'delivered'`, purchased `2016-09-15 12:16:38`).
- **Suggested Fix:**
  - Wrap order creation, line-item insertion, and initial payment ledger creation in an atomic database transaction (`BEGIN ... COMMIT`) or enforce reconciliation alerts between the Payment Gateway and Order Service.
- **Business Impact:** Represents direct revenue leakage (merchandise shipped and delivered without a recorded payment settlement) and causes discrepancies between `orders` and `order_payments` counts (`99,441` vs. `99,440` distinct orders).

### DQ-16: Orders With No Line Items in `order_items`
- **Rows Flagged:** `775` orders (`99,441` total orders vs. `98,666` distinct `order_id`s in `order_items`) — *Severity: Medium*
- **Issue:** 775 orders in `orders` have no child rows in `order_items` (`603` status `'unavailable'`, `164` `'canceled'`, `5` `'created'`, `2` `'invoiced'`, `1` `'shipped'`). However, almost all of these 775 orders **do** have payment records in `order_payments`!
- **Concrete Example:**
  - `order_id = '8e24261a7e58791d10cb1bf9da94df5c'` (`order_status = 'unavailable'`) has a recorded payment in `order_payments` but `0` rows in `order_items`.
- **Suggested Fix:**
  - Do not hard-delete `order_items` rows when an order transitions to `'unavailable'` or `'canceled'`; instead, retain the line items with an `item_status` column (`'canceled'`, `'out_of_stock'`).
- **Business Impact:** Impossible to analyze which products or sellers caused the 603 `'unavailable'` stockout events, blinding inventory and seller reliability teams.

### DQ-17: Products With Category Missing From `category_translation`
- **Rows Flagged:** `13` products (across `2` categories) — *Severity: Low*
- **Issue:** Thirteen products have a non-null `product_category_name` in `products` that is absent from `category_translation`:
  - `portateis_cozinha_e_preparadores_de_alimentos` (`10` products)
  - `pc_gamer` (`3` products)
- **Concrete Example:**
  - `product_id = '0105b5323d24fc655f73052694dbbb3a'` (`product_category_name = 'pc_gamer'`).
- **Suggested Fix:**
  - Insert the two missing rows into `category_translation` (`'pc_gamer' -> 'gaming_pc'` and `'portateis_cozinha_e_preparadores_de_alimentos' -> 'portable_kitchen_food_preparers'`) and add a foreign key from `products.product_category_name` to `category_translation`.
- **Business Impact:** English-language executive dashboards drop these two categories when using an `INNER JOIN` to `category_translation`.

---

## Category 5: Cross-Table & State Reconciliation Mismatches (`queries/05_cross_table_mismatch.sql`)

### DQ-18: Order Total (`order_items`) ≠ Sum of Payments (`order_payments`)
- **Rows Flagged:** `310` orders (with discrepancy `> R$ 0.05`; `579` orders if using `> R$ 0.01`) — *Severity: Medium*
- **Issue:** Comparing `SUM(price + freight_value)` from `order_items` against `SUM(payment_value)` from `order_payments` reveals 310 orders where the settled payment differs from the item + freight total by more than `R$ 0.05` (up to `R$ 182.81`).
- **Concrete Example:**
  - `order_id = 'ce6d150fb29ada17d2f83422e0014370'`: `SUM(price + freight_value) = R$ 1,399.03`, `SUM(payment_value) = R$ 1,581.84` (difference of **`+R$ 182.81`** due to financing interest on 10 credit-card installments).
  - `order_id = '70b742795bc441e94a44a084b6d9ce7a'`: `SUM(price + freight_value) = R$ 151.62`, `SUM(payment_value) = R$ 100.00` (difference of **`-R$ 51.62`** due to partial item cancellation/discount not reflected in `order_items`).
- **Suggested Fix:**
  - Add explicit `interest_amount` and `discount_amount` columns to `order_payments` (or `orders`) so `SUM(price + freight_value) - discount_amount + interest_amount = SUM(payment_value)` reconciles to the cent.
- **Business Impact:** Finance and accounting teams see conflicting GMV numbers depending on whether reports pull from `order_items` (`R$ 15.84M`) or `order_payments` (`R$ 16.01M`).

### DQ-19: Carrier Handoff Timestamp Precedes Payment Approval
- **Rows Flagged:** `1,359` orders — *Severity: Medium*
- **Issue:** 1,359 orders have `order_delivered_carrier_date < order_approved_at`, meaning the package was logged as handed to the carrier before payment approval was recorded.
- **Concrete Example:**
  - `order_id = '51b0d5dc527a2051212f7e4a56b963d9'`: `order_approved_at = '2018-04-24 18:25:22'`, `order_delivered_carrier_date = '2018-04-20 20:19:21'` (`-94.1 hours`).
- **Suggested Fix:**
  - Separate initial payment authorization timestamp (`first_approved_at`) from subsequent re-approval or boleto settlement webhook updates so re-approvals do not overwrite `order_approved_at` after dispatch.
- **Business Impact:** Creates negative *Seller Fulfillment Time* (`order_delivered_carrier_date - order_approved_at`), skewing warehouse/seller SLA metrics.

### DQ-20: Canceled Orders With a Populated Customer Delivery Timestamp
- **Rows Flagged:** `6` orders — *Severity: High*
- **Issue:** Six orders have `order_status = 'canceled'` even though `order_delivered_customer_date IS NOT NULL` (the customer received the shipment).
- **Concrete Example:**
  - `order_id = '1950d777989f6a877539f53795b4c3c3'`: `order_status = 'canceled'`, `order_delivered_customer_date = '2018-03-21 22:03:51'`.
- **Suggested Fix:**
  - Introduce distinct post-delivery statuses (`'returned'`, `'refunded_after_delivery'`) rather than overwriting `order_status` to `'canceled'` after physical delivery has occurred.
- **Business Impact:** Causes chargeback/refund leakage if an order is refunded as `'canceled'` without triggering a return merchandise authorization (RMA) for goods already delivered to the customer.

