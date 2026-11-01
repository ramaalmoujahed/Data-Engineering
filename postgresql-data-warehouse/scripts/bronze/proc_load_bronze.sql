/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze) (PostgreSQL)
===============================================================================
Script Purpose:
    Loads the bronze tables from the CSV files (full load):
    - Truncates each bronze table.
    - Loads the CSV with COPY (PostgreSQL's equivalent of BULK INSERT).
    - Prints progress and the load duration of each table and the batch.

Parameters:
    p_base_path : folder that contains 'source_crm' and 'source_erp'.
                  Use forward slashes. The PostgreSQL service must be able
                  to read this folder.

Usage Example:
    CALL bronze.load_bronze();
    CALL bronze.load_bronze('C:/Users/Public/dwh_datasets');
===============================================================================
*/
CREATE OR REPLACE PROCEDURE bronze.load_bronze(
    p_base_path TEXT DEFAULT 'C:/Users/Public/dwh_datasets'
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_time        TIMESTAMP;
    v_end_time          TIMESTAMP;
    v_batch_start_time  TIMESTAMP;
    v_batch_end_time    TIMESTAMP;
    v_rows              BIGINT;
    v_load              RECORD;
BEGIN
    v_batch_start_time := clock_timestamp();
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Loading Bronze Layer';
    RAISE NOTICE '================================================';

    -- target table + source file for each load (CRM first, then ERP)
    FOR v_load IN
        SELECT * FROM (VALUES
            (1, 'CRM', 'bronze.crm_cust_info',     'source_crm/cust_info.csv'),
            (2, 'CRM', 'bronze.crm_prd_info',      'source_crm/prd_info.csv'),
            (3, 'CRM', 'bronze.crm_sales_details', 'source_crm/sales_details.csv'),
            (4, 'ERP', 'bronze.erp_loc_a101',      'source_erp/LOC_A101.csv'),
            (5, 'ERP', 'bronze.erp_cust_az12',     'source_erp/CUST_AZ12.csv'),
            (6, 'ERP', 'bronze.erp_px_cat_g1v2',   'source_erp/PX_CAT_G1V2.csv')
        ) AS t(seq, source_system, table_name, file_name)
        ORDER BY seq
    LOOP
        IF v_load.seq IN (1, 4) THEN
            RAISE NOTICE '------------------------------------------------';
            RAISE NOTICE 'Loading % Tables', v_load.source_system;
            RAISE NOTICE '------------------------------------------------';
        END IF;

        v_start_time := clock_timestamp();

        RAISE NOTICE '>> Truncating Table: %', v_load.table_name;
        EXECUTE format('TRUNCATE TABLE %s', v_load.table_name);

        RAISE NOTICE '>> Inserting Data Into: %', v_load.table_name;
        EXECUTE format(
            'COPY %s FROM %L WITH (FORMAT csv, HEADER true, DELIMITER '','', ENCODING ''UTF8'')',
            v_load.table_name,
            p_base_path || '/' || v_load.file_name
        );
        GET DIAGNOSTICS v_rows = ROW_COUNT;

        v_end_time := clock_timestamp();
        RAISE NOTICE '>> Rows Loaded: %', v_rows;
        RAISE NOTICE '>> Load Duration: % seconds',
            ROUND(EXTRACT(EPOCH FROM v_end_time - v_start_time)::NUMERIC, 2);
        RAISE NOTICE '>> -------------';
    END LOOP;

    v_batch_end_time := clock_timestamp();
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Loading Bronze Layer is Completed';
    RAISE NOTICE '   - Total Load Duration: % seconds',
        ROUND(EXTRACT(EPOCH FROM v_batch_end_time - v_batch_start_time)::NUMERIC, 2);
    RAISE NOTICE '==========================================';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '==========================================';
        RAISE NOTICE 'ERROR OCCURRED DURING LOADING BRONZE LAYER';
        RAISE NOTICE 'Error Message: %', SQLERRM;
        RAISE NOTICE 'Error Code: %', SQLSTATE;
        RAISE NOTICE '==========================================';
        RAISE;  -- re-throw so the caller sees that the load failed
END;
$$;
