# Data Engineering Projects

Hands-on data engineering and analytics engineering projects: building pipelines, cleaning messy source data, and modeling it into structures that are ready for reporting and BI.

Each project lives in its own folder with its own README, documentation and scripts.

## Projects

| Project | What it does | Tech |
|---------|--------------|------|
| [**PostgreSQL Data Warehouse**](postgresql-data-warehouse) | Builds a data warehouse from raw CRM and ERP CSV files using the Medallion Architecture (Bronze, Silver, Gold). Loads the data with stored procedures, cleans and standardizes it, and delivers a star schema (2 dimensions, 1 fact) for analytics and Power BI. | PostgreSQL, PL/pgSQL, pgAdmin |

More projects will be added here.

## Skills Shown

- **ETL / ELT:** batch loading with `COPY`, full-load pipelines in stored procedures, load logging and error handling
- **Data quality:** deduplication, standardization, handling invalid dates and values, automated quality checks
- **Data modeling:** Medallion Architecture, star schema, surrogate keys
- **Documentation:** architecture and data flow diagrams, data catalog, naming conventions

## Repository Structure

```
Data-Engineering/
├── postgresql-data-warehouse/   # SQL data warehouse project
└── README.md
```

## About Me

I'm **Rama Almoujahed**, an M.Sc. student in Business Informatics at FH Südwestfalen in Germany, with work experience as a Data Analyst & BI Reporting working student. I work with SQL, Power BI, DAX, Python and SAP Datasphere.

See also my [Power BI projects](https://github.com/ramaalmoujahed/Power_BI).
