# Dataset: Olist Brazilian E-Commerce Public Dataset

Raw CSV files are intentionally excluded from version control to keep the repository lightweight. Download the dataset directly from Kaggle and place the CSV files in this `data/` directory before running the load scripts.

## Official Dataset Source

- **Dataset Name:** Brazilian E-Commerce Public Dataset by Olist
- **Kaggle Link:** [https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
- **Kaggle CLI Command:**
  ```bash
  kaggle datasets download -d olistbr/brazilian-ecommerce -p data/ --unzip
  ```

## Expected CSV Files in `data/`

| File Name | Target Table | Total Rows | Primary / Composite Key | Description |
| :--- | :--- | ---: | :--- | :--- |
| `olist_customers_dataset.csv` | `customers` | 99,441 | `customer_id` | Customer order-scoped IDs, unique customer IDs (`customer_unique_id`), and location metadata |
| `olist_orders_dataset.csv` | `orders` | 99,441 | `order_id` | Core order lifecycle statuses and purchase/approval/carrier/delivery timestamps |
| `olist_order_items_dataset.csv` | `order_items` | 112,650 | `(order_id, order_item_id)` | Line items within each order, item price (`price`), and shipping charges (`freight_value`) |
| `olist_order_payments_dataset.csv` | `order_payments` | 103,886 | `(order_id, payment_sequential)` | Payment methods, installments, and transaction amounts (`payment_value`) per order |
| `olist_order_reviews_dataset.csv` | `order_reviews` | 99,224 | `(review_id, order_id)` | Customer satisfaction scores (1–5), review comments, and survey timestamps |
| `olist_products_dataset.csv` | `products` | 32,951 | `product_id` | Product categories, text metadata lengths, weight (`g`), and dimensions (`cm`) |
| `olist_sellers_dataset.csv` | `sellers` | 3,095 | `seller_id` | Seller location metadata (zip prefix, city, state) |
| `olist_geolocation_dataset.csv` | `geolocation` | 1,000,163 | *None (log table)* | Brazilian zip code prefixes mapped to latitude/longitude coordinates |
| `product_category_name_translation.csv` | `category_translation` | 71 | `product_category_name` | Portuguese-to-English product category mapping |

