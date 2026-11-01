# Data Catalog: Gold Layer

The Gold layer is the business-facing part of the warehouse. It is a **star schema** of two dimensions and one fact, built as views on top of the Silver layer, ready for SQL analysis or Power BI.

| Object               | Type      | Grain (one row per…)              | Rows   |
|----------------------|-----------|-----------------------------------|--------|
| `gold.dim_customers` | dimension | customer                          | 18,484 |
| `gold.dim_products`  | dimension | current product                   | 295    |
| `gold.fact_sales`    | fact      | order line (order + product)      | 60,398 |

Relationships: `fact_sales.customer_key` → `dim_customers.customer_key` and `fact_sales.product_key` → `dim_products.product_key` (both one-to-many).

---

## 1. gold.dim_customers

**Purpose:** one row per customer, combining CRM customer data with ERP demographics (birthdate, gender) and location (country).

**Sources:** `silver.crm_cust_info` (master), `silver.erp_cust_az12`, `silver.erp_loc_a101`

| Column           | Data type   | Description | Example |
|------------------|-------------|-------------|---------|
| customer_key     | BIGINT      | Surrogate key of the dimension, generated in the warehouse. Used to join to the fact. | 1 |
| customer_id      | INT         | Customer ID from the CRM system. | 11000 |
| customer_number  | VARCHAR(50) | Customer business number from CRM; used to match ERP records. | AW00011000 |
| first_name       | VARCHAR(50) | First name, trimmed. | Jon |
| last_name        | VARCHAR(50) | Last name, trimmed. | Yang |
| country          | VARCHAR(50) | Country of residence from ERP, with codes standardized (DE → Germany, US/USA → United States); `n/a` when missing. | Australia |
| marital_status   | VARCHAR(50) | `Married`, `Single` or `n/a`. | Married |
| gender           | VARCHAR     | `Male`, `Female` or `n/a`. CRM is the master; ERP fills the gaps when CRM has no value. | Male |
| birthdate        | DATE        | Date of birth from ERP; future dates were set to NULL. | 1971-10-06 |
| create_date      | DATE        | Date the customer record was created in CRM. | 2025-10-06 |

---

## 2. gold.dim_products

**Purpose:** one row per **current** product (historical versions are filtered out), enriched with its category from ERP.

**Sources:** `silver.crm_prd_info`, `silver.erp_px_cat_g1v2`

| Column          | Data type   | Description | Example |
|-----------------|-------------|-------------|---------|
| product_key     | BIGINT      | Surrogate key of the dimension, generated in the warehouse. Used to join to the fact. | 1 |
| product_id      | INT         | Product ID from CRM. | 210 |
| product_number  | VARCHAR(50) | Product code (the CRM product key without its category prefix). Used to match sales. | FR-R92B-58 |
| product_name    | VARCHAR(50) | Descriptive product name including type, color and size. | HL Road Frame - Black- 58 |
| category_id     | VARCHAR(50) | Category code taken from the first part of the CRM product key. | CO_RF |
| category        | VARCHAR(50) | High-level category: Bikes, Components, Clothing, Accessories. NULL if the category code is unknown in ERP. | Components |
| subcategory     | VARCHAR(50) | More detailed product type within the category. | Road Frames |
| maintenance     | VARCHAR(50) | Whether the product needs maintenance: `Yes` / `No`. | Yes |
| cost            | INT         | Product cost; missing costs were set to 0. | 0 |
| product_line    | VARCHAR(50) | `Mountain`, `Road`, `Touring`, `Other Sales` or `n/a`. | Road |
| start_date      | DATE        | Date this version of the product became valid. | 2003-07-01 |

---

## 3. gold.fact_sales

**Purpose:** one row per order line, holding the measurable sales events and the keys to both dimensions.

**Source:** `silver.crm_sales_details`, keys looked up from `gold.dim_products` and `gold.dim_customers`

| Column         | Data type   | Description | Example |
|----------------|-------------|-------------|---------|
| order_number   | VARCHAR(50) | Sales order number. One order can have several lines. | SO43697 |
| product_key    | BIGINT      | Foreign key to `dim_products`. | 20 |
| customer_key   | BIGINT      | Foreign key to `dim_customers`. | 10769 |
| order_date     | DATE        | Date the order was placed. NULL when the source date was invalid (19 rows). | 2010-12-29 |
| shipping_date  | DATE        | Date the order was shipped. | 2011-01-05 |
| due_date       | DATE        | Date payment was due. | 2011-01-10 |
| sales_amount   | INT         | Line revenue. Recalculated as quantity × price when the source was missing, negative or inconsistent. | 3578 |
| quantity       | INT         | Units ordered. | 1 |
| price          | INT         | Unit price. Derived from sales ÷ quantity when the source was missing or not positive. | 3578 |
