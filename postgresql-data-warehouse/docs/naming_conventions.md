# Naming Conventions

These rules apply to every schema, table, view, column and procedure in the `datawarehouse` database.

## General rules

- **snake_case**: lowercase letters, words separated by `_`.
- **English** names only.
- **No SQL reserved words** as object names.

## Schemas

| Schema   | Layer  | Holds                                    |
|----------|--------|------------------------------------------|
| `bronze` | Bronze | raw data, exactly as delivered by source |
| `silver` | Silver | cleaned and standardized data            |
| `gold`   | Gold   | business-ready star schema (views)       |

## Tables and views

### Bronze and Silver: `<source_system>_<entity>`

- `<source_system>` is the system the data comes from: `crm` or `erp`.
- `<entity>` is the original table name from that system, not renamed.
- Examples: `crm_cust_info`, `erp_loc_a101`.

Keeping the source name in Bronze and Silver makes lineage obvious: you can tell where every table comes from by its name alone.

### Gold: `<category>_<entity>`

- `<category>` describes the role of the object.
- `<entity>` is a business-friendly name.

| Prefix    | Meaning         | Example                 |
|-----------|-----------------|-------------------------|
| `dim_`    | dimension       | `dim_customers`         |
| `fact_`   | fact            | `fact_sales`            |
| `report_` | reporting table | `report_sales_monthly`  |

## Columns

- **Bronze and Silver** keep the source column names (`cst_id`, `prd_key`, `sls_order_dt`).
- **Gold** uses readable business names (`customer_id`, `product_number`, `order_date`).
- **Surrogate keys** end in `_key`: `<entity>_key`, for example `customer_key`, `product_key`.
- **Technical columns** start with `dwh_`: `dwh_<purpose>`, for example `dwh_create_date` (when the row was loaded).

## Stored procedures

- Load procedures are named `load_<layer>` and live in the schema they load.
- Examples: `bronze.load_bronze`, `silver.load_silver`.
- Run them with `CALL`, for example `CALL silver.load_silver();`.

## Script files

- DDL scripts: `ddl_<layer>.sql`
- Procedure scripts: `proc_load_<layer>.sql`
- Test scripts: `quality_checks_<layer>.sql`
