/*
===============================================================================
Quality Checks - Gold Layer (PostgreSQL)
===============================================================================
Script Purpose:
    Validates the star schema in the 'gold' layer:
    - Uniqueness of surrogate keys in the dimensions.
    - Referential integrity between the fact and the dimensions.

Usage:
    Run after creating the gold views. Expectation: No Results for every check.
===============================================================================
*/

-- Unique customer_key in gold.dim_customers | Expectation: No Results
SELECT customer_key, COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

-- Unique product_key in gold.dim_products | Expectation: No Results
SELECT product_key, COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;

-- Every fact row finds its dimensions | Expectation: No Results
SELECT *
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
WHERE p.product_key IS NULL
   OR c.customer_key IS NULL;
