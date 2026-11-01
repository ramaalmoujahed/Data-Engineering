/*
=============================================================
Create Database and Schemas (PostgreSQL)
=============================================================
Script Purpose:
    Creates the 'datawarehouse' database and the three schemas of the
    Medallion Architecture: bronze, silver and gold.

    PostgreSQL cannot switch databases inside one script, so run it in
    two parts:
      PART 1 -> in a Query Tool connected to the 'postgres' database
      PART 2 -> in a Query Tool connected to the 'datawarehouse' database

WARNING:
    PART 1 drops the whole 'datawarehouse' database if it exists.
    All data in it will be permanently deleted.
=============================================================
*/

-- ===================== PART 1 (database: postgres) =====================
DROP DATABASE IF EXISTS datawarehouse WITH (FORCE);
CREATE DATABASE datawarehouse;

-- ===================== PART 2 (database: datawarehouse) ================
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;
