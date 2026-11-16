# SQL Data Quality Audit — Olist Brazilian E-Commerce

An end-to-end SQL data quality audit of the **Olist Brazilian E-Commerce Public Dataset** (~100k orders across 9 linked relational tables). This project systematically detects, quantifies, and documents **20 data quality checks across 5 audit categories**: **Duplicates**, **NULLs**, **Invalid Values**, **Orphan Records**, and **Cross-Table Mismatches**.

---

## 1. Problem, Dataset & Tools

### The Problem
Raw transactional exports from distributed e-commerce microservices (checkout, payment gateways, seller portals, carrier webhooks, and customer surveys) frequently contain silent data anomalies:
- Chronological inversions (e.g., packages marked delivered to the customer days *before* the carrier picked them up, or handed to the carrier before purchase).
- Referential orphans (e.g., delivered orders missing payment records, or canceled/unavailable orders stripped of line-item details).
- Financial discrepancies between order line-item totals (`price + freight_value`) and settled payment amounts (`payment_value`).
- Unconstrained duplicate keys (`review_id` mapped to multiple orders, or 261k+ redundant `geolocation` rows causing massive join fan-outs).

Without a structured SQL data quality audit prior to warehouse modeling, these defects corrupt Gross Merchandise Value (GMV) reporting, On-Time Delivery (OTD) SLAs, and downstream ML features.

### Dataset
- **Source:** [Olist Brazilian E-Commerce Public Dataset (Kaggle)](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
- **Scope:** 99,441 orders placed between September 2016 and October 2018 across 9 linked tables (`orders`, `customers`, `order_items`, `order_payments`, `order_reviews`, `products`, `sellers`, `geolocation`, and `category_translation`).

### Tools Used
- **Database:** PostgreSQL 14+ (compatible with MySQL 8.0+)
- **SQL Client:** DBeaver & `psql` CLI
- **Reporting:** Markdown (`docs/findings.md`) & CSV (`output/discrepancy_report.csv`)

---

## 2. Project Structure

```text
sql-data-quality-audit/
├── data/            # Dataset download instructions & table manifest (raw CSVs excluded from Git)
├── schema/
│   └── create_tables.sql          # Staging table DDL, indexes, and audit logging tables
├── queries/
│   ├── 01_duplicates.sql          # Checks DQ-01 to DQ-04 (Key & row-level duplicates)
│   ├── 02_nulls.sql               # Checks DQ-05 to DQ-08 (Lifecycle & catalog NULLs)
│   ├── 03_invalid_values.sql      # Checks DQ-09 to DQ-13 (Prices, weights & inverted timestamps)
│   ├── 04_orphan_records.sql      # Checks DQ-14 to DQ-17 (Missing parent/child foreign keys)
│   └── 05_cross_table_mismatch.sql# Checks DQ-18 to DQ-20 (Payment vs. order totals & state conflicts)
├── output/
│   └── discrepancy_report.csv     # Exported sample of flagged anomalous records across checks
├── docs/
│   └── findings.md                # Full audit report: issue, count, example, fix & business impact
└── README.md
```

---

## 3. Audit Results Summary

All counts below reflect the exact numbers from the Olist Brazilian E-Commerce dataset across our **20 SQL checks**:

| Check ID | Category | Check | Target Table(s) | Rows Flagged | Severity |
| :--- | :--- | :--- | :--- | ---: | :--- |
| **DQ-01** | Duplicates | Duplicate `order_id` in `orders` | `orders` | 0 | High |
| **DQ-02** | Duplicates | Duplicate `review_id` in `order_reviews` (789 distinct IDs) | `order_reviews` | 814 | High |
| **DQ-03** | Duplicates | Exact duplicate rows in `geolocation` | `geolocation` | 261,831 | Medium |
| **DQ-04** | Duplicates | Duplicate `(order_id, payment_sequential)` key | `order_payments` | 0 | High |
| **DQ-05** | NULLs | Missing customer delivery date on `delivered` orders | `orders` | 8 | High |
| **DQ-06** | NULLs | Missing payment approval date on `delivered` orders | `orders` | 14 | Medium |
| **DQ-07** | NULLs | Missing carrier handoff date on `delivered`/`shipped` orders | `orders` | 2 | High |
| **DQ-08** | NULLs | Products missing `product_category_name` & metadata | `products` | 610 | Medium |
| **DQ-09** | Invalid Values | Item `price <= 0` or `freight_value < 0` | `order_items` | 0 | High |
| **DQ-10** | Invalid Values | Zero or negative payment (`payment_value <= 0`) | `order_payments` | 9 | Medium |
| **DQ-11** | Invalid Values | Customer delivery date before carrier handoff date | `orders` | 23 | High |
| **DQ-12** | Invalid Values | Carrier handoff date before order purchase timestamp | `orders` | 166 | High |
| **DQ-13** | Invalid Values | Physical product weight `<= 0` grams | `products` | 4 | Medium |
| **DQ-14** | Orphans | Orders with no matching customer in `customers` | `orders -> customers` | 0 | High |
| **DQ-15** | Orphans | Orders with no payment record in `order_payments` | `orders -> order_payments` | 1 | High |
| **DQ-16** | Orphans | Orders with no line items in `order_items` | `orders -> order_items` | 775 | Medium |
| **DQ-17** | Orphans | Product categories missing from `category_translation` | `products -> category_translation` | 13 | Low |
| **DQ-18** | Mismatch | Payment total ≠ order items total (`diff > R$ 0.05`) | `order_items <-> order_payments` | 310 | Medium |
| **DQ-19** | Mismatch | Carrier handoff date before payment approval date | `orders` | 1,359 | Medium |
| **DQ-20** | Mismatch | Canceled orders with a populated delivery timestamp | `orders` | 6 | High |

> See [docs/findings.md](docs/findings.md) for concrete `order_id`/`product_id` examples, root causes, SQL remediation strategies, and business impact analysis for every check.

---

## 4. How to Run

### Step 1: Download the Dataset
Download the [Olist Brazilian E-Commerce dataset from Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) and extract the 9 CSV files into `data/` (see [data/README.md](data/README.md) for the file list).

### Step 2: Create Staging & Audit Tables
Run `schema/create_tables.sql` in **DBeaver** or via `psql`:
```bash
psql -U postgres -d olist -f schema/create_tables.sql
```

### Step 3: Load the CSV Files
In **DBeaver**, right-click each table in the `olist_audit` schema -> **Import Data** -> select the corresponding CSV in `data/`, or execute the `\copy` commands at the bottom of `schema/create_tables.sql`.

### Step 4: Execute the 5 Audit Query Scripts
Run the query scripts in order to inspect flagged rows and populate `olist_audit.audit_summary` and `olist_audit.audit_flagged_records`:
```bash
psql -U postgres -d olist -f queries/01_duplicates.sql
psql -U postgres -d olist -f queries/02_nulls.sql
psql -U postgres -d olist -f queries/03_invalid_values.sql
psql -U postgres -d olist -f queries/04_orphan_records.sql
psql -U postgres -d olist -f queries/05_cross_table_mismatch.sql
```

### Step 5: Export Flagged Rows to CSV
Export the consolidated discrepancies from `olist_audit.audit_flagged_records` to [output/discrepancy_report.csv](output/discrepancy_report.csv) using DBeaver's **Export Resultset -> CSV** or `\copy`.

---

## 5. Key Learnings

1. **Stage Unconstrained Before Enforcing Warehouse Constraints:** Had we enforced strict `PRIMARY KEY (review_id)` on `order_reviews` or `NOT NULL` constraints during initial CSV ingestion, the load would have crashed on the **814 duplicate `review_id` rows** and **610 uncategorized products**. Loading into permissive staging tables first allows SQL audits to profile and quarantine bad records cleanly.
2. **Watch Out for Fan-Out Traps in Reference Tables:** `olist_geolocation_dataset.csv` contains **261,831 exact duplicate rows** and averages ~52 rows per zip code prefix. Joining `customers` or `orders` directly to `geolocation` without first aggregating to `GROUP BY geolocation_zip_code_prefix` inflates order counts and revenue by over 50x.
3. **Distinguish Rounding Noise from True Financial Mismatches:** When comparing `SUM(price + freight_value)` in `order_items` against `SUM(payment_value)` in `order_payments`, **269 orders** differ by `R$ 0.01–0.05` purely due to credit-card installment division rounding, whereas **310 orders** have genuine financial discrepancies (`> R$ 0.05`, up to `R$ 182.81`) driven by buyer-paid installment interest or partial item cancellations.
4. **Hard Deletes on Canceled/Unavailable Child Rows Destroy Root-Cause Visibility:** Because Olist deleted the `order_items` records for **775 orders** (603 `'unavailable'` and 164 `'canceled'`) while leaving their headers in `orders` and payments in `order_payments`, analysts cannot determine which products or sellers triggered stockout cancellations. Soft-deleting line items (`is_deleted = true`) preserves full auditability.
5. **Asynchronous Webhooks Require Chronological Guardrails:** With **23 orders** marked delivered to the customer before carrier handoff, **166 orders** handed to the carrier before purchase, and **1,359 orders** handed to the carrier before payment approval, ingestion pipelines must normalize timezones (`TIMESTAMPTZ`) and quarantine negative stage durations before computing logistics SLAs.

