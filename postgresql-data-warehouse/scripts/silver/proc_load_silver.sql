/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver) (PostgreSQL)
===============================================================================
Script Purpose:
    ETL from the 'bronze' schema into the 'silver' schema (full load):
    - Truncates each silver table.
    - Inserts cleaned, standardized and enriched data from bronze.

Main transformations:
    crm_cust_info     : keep latest record per customer, trim names,
                        decode marital status and gender codes
    crm_prd_info      : split prd_key into category id + product key,
                        NULL cost -> 0, decode product line,
                        end date = day before the next start date
    crm_sales_details : integer dates -> DATE (invalid -> NULL),
                        recalculate sales / derive price when invalid
    erp_cust_az12     : remove 'NAS' prefix, future birthdates -> NULL,
                        normalize gender
    erp_loc_a101      : remove '-' from id, normalize country names
    erp_px_cat_g1v2   : loaded as-is (already clean)

Usage Example:
    CALL silver.load_silver();
===============================================================================
*/
CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_time        TIMESTAMP;
    v_end_time          TIMESTAMP;
    v_batch_start_time  TIMESTAMP;
    v_batch_end_time    TIMESTAMP;
    v_rows              BIGINT;
BEGIN
    v_batch_start_time := clock_timestamp();
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Loading Silver Layer';
    RAISE NOTICE '================================================';

    RAISE NOTICE '------------------------------------------------';
    RAISE NOTICE 'Loading CRM Tables';
    RAISE NOTICE '------------------------------------------------';

    -- ------------------------------------------------------------------
    -- silver.crm_cust_info
    -- ------------------------------------------------------------------
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.crm_cust_info';
    TRUNCATE TABLE silver.crm_cust_info;
    RAISE NOTICE '>> Inserting Data Into: silver.crm_cust_info';
    INSERT INTO silver.crm_cust_info (
        cst_id,
        cst_key,
        cst_firstname,
        cst_lastname,
        cst_marital_status,
        cst_gndr,
        cst_create_date
    )
    SELECT
        cst_id,
        cst_key,
        TRIM(cst_firstname) AS cst_firstname,
        TRIM(cst_lastname)  AS cst_lastname,
        CASE
            WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
            WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
            ELSE 'n/a'
        END AS cst_marital_status,          -- normalize marital status codes
        CASE
            WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
            WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
            ELSE 'n/a'
        END AS cst_gndr,                    -- normalize gender codes
        cst_create_date
    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
        FROM bronze.crm_cust_info
        WHERE cst_id IS NOT NULL
    ) t
    WHERE flag_last = 1;                    -- keep the most recent record per customer
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Rows Loaded: %', v_rows;
    RAISE NOTICE '>> Load Duration: % seconds', ROUND(EXTRACT(EPOCH FROM v_end_time - v_start_time)::NUMERIC, 2);
    RAISE NOTICE '>> -------------';

    -- ------------------------------------------------------------------
    -- silver.crm_prd_info
    -- ------------------------------------------------------------------
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.crm_prd_info';
    TRUNCATE TABLE silver.crm_prd_info;
    RAISE NOTICE '>> Inserting Data Into: silver.crm_prd_info';
    INSERT INTO silver.crm_prd_info (
        prd_id,
        cat_id,
        prd_key,
        prd_nm,
        prd_cost,
        prd_line,
        prd_start_dt,
        prd_end_dt
    )
    SELECT
        prd_id,
        REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,   -- extract category id
        SUBSTRING(prd_key, 7, LENGTH(prd_key))      AS prd_key,  -- extract product key
        prd_nm,
        COALESCE(prd_cost, 0) AS prd_cost,
        CASE
            WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
            WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
            WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
            WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
            ELSE 'n/a'
        END AS prd_line,                    -- map product line codes
        CAST(prd_start_dt AS DATE) AS prd_start_dt,
        CAST(
            LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt)
            - INTERVAL '1 day'
            AS DATE
        ) AS prd_end_dt                     -- end date = one day before next start date
    FROM bronze.crm_prd_info;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Rows Loaded: %', v_rows;
    RAISE NOTICE '>> Load Duration: % seconds', ROUND(EXTRACT(EPOCH FROM v_end_time - v_start_time)::NUMERIC, 2);
    RAISE NOTICE '>> -------------';

    -- ------------------------------------------------------------------
    -- silver.crm_sales_details
    -- ------------------------------------------------------------------
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.crm_sales_details';
    TRUNCATE TABLE silver.crm_sales_details;
    RAISE NOTICE '>> Inserting Data Into: silver.crm_sales_details';
    INSERT INTO silver.crm_sales_details (
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        sls_order_dt,
        sls_ship_dt,
        sls_due_dt,
        sls_sales,
        sls_quantity,
        sls_price
    )
    SELECT
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        CASE
            WHEN sls_order_dt = 0 OR LENGTH(sls_order_dt::TEXT) != 8 THEN NULL
            ELSE TO_DATE(sls_order_dt::TEXT, 'YYYYMMDD')
        END AS sls_order_dt,
        CASE
            WHEN sls_ship_dt = 0 OR LENGTH(sls_ship_dt::TEXT) != 8 THEN NULL
            ELSE TO_DATE(sls_ship_dt::TEXT, 'YYYYMMDD')
        END AS sls_ship_dt,
        CASE
            WHEN sls_due_dt = 0 OR LENGTH(sls_due_dt::TEXT) != 8 THEN NULL
            ELSE TO_DATE(sls_due_dt::TEXT, 'YYYYMMDD')
        END AS sls_due_dt,
        CASE
            WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
                THEN sls_quantity * ABS(sls_price)
            ELSE sls_sales
        END AS sls_sales,                   -- recalculate sales if missing or wrong
        sls_quantity,
        CASE
            WHEN sls_price IS NULL OR sls_price <= 0
                THEN sls_sales / NULLIF(sls_quantity, 0)
            ELSE sls_price
        END AS sls_price                    -- derive price if invalid
    FROM bronze.crm_sales_details;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Rows Loaded: %', v_rows;
    RAISE NOTICE '>> Load Duration: % seconds', ROUND(EXTRACT(EPOCH FROM v_end_time - v_start_time)::NUMERIC, 2);
    RAISE NOTICE '>> -------------';

    RAISE NOTICE '------------------------------------------------';
    RAISE NOTICE 'Loading ERP Tables';
    RAISE NOTICE '------------------------------------------------';

    -- ------------------------------------------------------------------
    -- silver.erp_cust_az12
    -- ------------------------------------------------------------------
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.erp_cust_az12';
    TRUNCATE TABLE silver.erp_cust_az12;
    RAISE NOTICE '>> Inserting Data Into: silver.erp_cust_az12';
    INSERT INTO silver.erp_cust_az12 (
        cid,
        bdate,
        gen
    )
    SELECT
        CASE
            WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LENGTH(cid))  -- remove 'NAS' prefix
            ELSE cid
        END AS cid,
        CASE
            WHEN bdate > CURRENT_DATE THEN NULL
            ELSE bdate
        END AS bdate,                       -- future birthdates -> NULL
        CASE
            WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
            WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN 'Male'
            ELSE 'n/a'
        END AS gen                          -- normalize gender
    FROM bronze.erp_cust_az12;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Rows Loaded: %', v_rows;
    RAISE NOTICE '>> Load Duration: % seconds', ROUND(EXTRACT(EPOCH FROM v_end_time - v_start_time)::NUMERIC, 2);
    RAISE NOTICE '>> -------------';

    -- ------------------------------------------------------------------
    -- silver.erp_loc_a101
    -- ------------------------------------------------------------------
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.erp_loc_a101';
    TRUNCATE TABLE silver.erp_loc_a101;
    RAISE NOTICE '>> Inserting Data Into: silver.erp_loc_a101';
    INSERT INTO silver.erp_loc_a101 (
        cid,
        cntry
    )
    SELECT
        REPLACE(cid, '-', '') AS cid,
        CASE
            WHEN TRIM(cntry) = 'DE' THEN 'Germany'
            WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
            WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
            ELSE TRIM(cntry)
        END AS cntry                        -- normalize / fill missing countries
    FROM bronze.erp_loc_a101;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Rows Loaded: %', v_rows;
    RAISE NOTICE '>> Load Duration: % seconds', ROUND(EXTRACT(EPOCH FROM v_end_time - v_start_time)::NUMERIC, 2);
    RAISE NOTICE '>> -------------';

    -- ------------------------------------------------------------------
    -- silver.erp_px_cat_g1v2
    -- ------------------------------------------------------------------
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.erp_px_cat_g1v2';
    TRUNCATE TABLE silver.erp_px_cat_g1v2;
    RAISE NOTICE '>> Inserting Data Into: silver.erp_px_cat_g1v2';
    INSERT INTO silver.erp_px_cat_g1v2 (
        id,
        cat,
        subcat,
        maintenance
    )
    SELECT
        id,
        cat,
        subcat,
        maintenance
    FROM bronze.erp_px_cat_g1v2;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Rows Loaded: %', v_rows;
    RAISE NOTICE '>> Load Duration: % seconds', ROUND(EXTRACT(EPOCH FROM v_end_time - v_start_time)::NUMERIC, 2);
    RAISE NOTICE '>> -------------';

    v_batch_end_time := clock_timestamp();
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Loading Silver Layer is Completed';
    RAISE NOTICE '   - Total Load Duration: % seconds',
        ROUND(EXTRACT(EPOCH FROM v_batch_end_time - v_batch_start_time)::NUMERIC, 2);
    RAISE NOTICE '==========================================';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '==========================================';
        RAISE NOTICE 'ERROR OCCURRED DURING LOADING SILVER LAYER';
        RAISE NOTICE 'Error Message: %', SQLERRM;
        RAISE NOTICE 'Error Code: %', SQLSTATE;
        RAISE NOTICE '==========================================';
        RAISE;  -- re-throw so the caller sees that the load failed
END;
$$;
