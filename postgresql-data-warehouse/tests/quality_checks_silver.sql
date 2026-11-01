/*
===============================================================================
Quality Checks - Silver Layer (PostgreSQL)
===============================================================================
Script Purpose:
    Checks data consistency, accuracy and standardization in the 'silver'
    layer: NULL/duplicate keys, unwanted spaces, standardized values,
    invalid dates and date orders, and business rule consistency.

Usage:
    Run after CALL silver.load_silver();
    Every check marked "Expectation: No Results" should return 0 rows.
===============================================================================
*/

-- ====================================================================
-- silver.crm_cust_info
-- ====================================================================
-- NULLs or duplicates in primary key | Expectation: No Results
SELECT cst_id, COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Unwanted spaces | Expectation: No Results
SELECT cst_key
FROM silver.crm_cust_info
WHERE cst_key != TRIM(cst_key)
   OR cst_firstname != TRIM(cst_firstname)
   OR cst_lastname != TRIM(cst_lastname);

-- Standardization & consistency
SELECT DISTINCT cst_marital_status FROM silver.crm_cust_info;
SELECT DISTINCT cst_gndr FROM silver.crm_cust_info;

-- ====================================================================
-- silver.crm_prd_info
-- ====================================================================
-- NULLs or duplicates in primary key | Expectation: No Results
SELECT prd_id, COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- Unwanted spaces | Expectation: No Results
SELECT prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

-- NULL or negative cost | Expectation: No Results
SELECT prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- Standardization & consistency
SELECT DISTINCT prd_line FROM silver.crm_prd_info;

-- End date before start date | Expectation: No Results
SELECT *
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

-- ====================================================================
-- silver.crm_sales_details
-- ====================================================================
-- Invalid integer dates in the source (checked on bronze)
SELECT NULLIF(sls_due_dt, 0) AS sls_due_dt
FROM bronze.crm_sales_details
WHERE sls_due_dt <= 0
   OR LENGTH(sls_due_dt::TEXT) != 8
   OR sls_due_dt > 20500101
   OR sls_due_dt < 19000101;

-- Order date after ship/due date | Expectation: No Results
SELECT *
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt
   OR sls_order_dt > sls_due_dt;

-- Sales = Quantity * Price | Expectation: No Results
SELECT DISTINCT sls_sales, sls_quantity, sls_price
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
   OR sls_sales IS NULL
   OR sls_quantity IS NULL
   OR sls_price IS NULL
   OR sls_sales <= 0
   OR sls_quantity <= 0
   OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;

-- ====================================================================
-- silver.erp_cust_az12
-- ====================================================================
-- Out-of-range birthdates | Expectation: between 1924-01-01 and today
SELECT DISTINCT bdate
FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01'
   OR bdate > CURRENT_DATE;

-- Standardization & consistency
SELECT DISTINCT gen FROM silver.erp_cust_az12;

-- ====================================================================
-- silver.erp_loc_a101
-- ====================================================================
-- Standardization & consistency
SELECT DISTINCT cntry
FROM silver.erp_loc_a101
ORDER BY cntry;

-- ====================================================================
-- silver.erp_px_cat_g1v2
-- ====================================================================
-- Unwanted spaces | Expectation: No Results
SELECT *
FROM silver.erp_px_cat_g1v2
WHERE cat != TRIM(cat)
   OR subcat != TRIM(subcat)
   OR maintenance != TRIM(maintenance);

-- Standardization & consistency
SELECT DISTINCT maintenance FROM silver.erp_px_cat_g1v2;
