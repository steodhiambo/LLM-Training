-- ============================================================================
-- E-COMMERCE ANALYTICS & CUSTOMER INTELLIGENCE PLATFORM
-- SNOWFLAKE CLOUD PLATFORM IMPLEMENTATION
-- For LLM Training Data Portfolio Project
-- Author: SQL Developer Portfolio
-- Date: 2025-01-04
-- Description: Snowflake-specific implementation with cloud features
-- ============================================================================

-- ============================================================================
-- SNOWFLAKE WAREHOUSE SETUP AND MANAGEMENT
-- ============================================================================

-- Create virtual warehouses for different workloads
CREATE OR REPLACE WAREHOUSE dev_wh 
WITH WAREHOUSE_SIZE = 'XSMALL'
AUTO_SUSPEND = 300  -- 5 minutes
AUTO_RESUME = TRUE
MIN_CLUSTER_COUNT = 1
MAX_CLUSTER_COUNT = 1
SCALING_POLICY = 'STANDARD';

CREATE OR REPLACE WAREHOUSE compute_wh 
WITH WAREHOUSE_SIZE = 'SMALL'
AUTO_SUSPEND = 600  -- 10 minutes
AUTO_RESUME = TRUE
MIN_CLUSTER_COUNT = 1
MAX_CLUSTER_COUNT = 2
SCALING_POLICY = 'STANDARD';

CREATE OR REPLACE WAREHOUSE reporting_wh 
WITH WAREHOUSE_SIZE = 'MEDIUM'
AUTO_SUSPEND = 900  -- 15 minutes
AUTO_RESUME = TRUE
MIN_CLUSTER_COUNT = 1
MAX_CLUSTER_COUNT = 3
SCALING_POLICY = 'ECONOMY';

-- Warehouse monitoring query
SELECT 
    name,
    size,
    state,
    scaling_policy,
    auto_suspend,
    min_cluster_count,
    max_cluster_count
FROM table(information_schema.warehouses())
WHERE name IN ('DEV_WH', 'COMPUTE_WH', 'REPORTING_WH');

-- ============================================================================
-- SNOWFLAKE DATABASE AND SCHEMA SETUP
-- ============================================================================

-- Create database for the e-commerce analytics platform
CREATE OR REPLACE DATABASE ecommerce_analytics_db;

-- Create schemas for different layers
CREATE OR REPLACE SCHEMA ecommerce_analytics_db.raw_data;
CREATE OR REPLACE SCHEMA ecommerce_analytics_db.enriched_data;
CREATE OR REPLACE SCHEMA ecommerce_analytics_db.analytics;
CREATE OR REPLACE SCHEMA ecommerce_analytics_db.marts;

-- Set the working database and schema
USE DATABASE ecommerce_analytics_db;
USE SCHEMA analytics;

-- ============================================================================
-- SNOWFLAKE-TYPICAL TABLE CREATION WITH CLUSTERING
-- ============================================================================

-- Recreate fact table with Snowflake-specific features
CREATE OR REPLACE TABLE ecommerce_analytics_db.analytics.fact_sales_transactions (
    sales_transaction_key NUMBER PRIMARY KEY,
    transaction_id VARCHAR,
    customer_key NUMBER NOT NULL,
    product_key NUMBER NOT NULL,
    time_key NUMBER NOT NULL,
    geography_key NUMBER NOT NULL,
    marketing_channel_key NUMBER,
    
    -- Transaction Details
    transaction_date DATE NOT NULL,
    transaction_time TIME,
    transaction_type VARCHAR,
    order_id VARCHAR,
    order_item_id VARCHAR,
    session_id VARCHAR,
    
    -- Financial Metrics
    quantity_sold NUMBER NOT NULL,
    unit_price NUMBER(10,2) NOT NULL,
    unit_cost NUMBER(10,2),
    total_revenue NUMBER(12,2) NOT NULL,
    total_cost NUMBER(12,2),
    total_profit NUMBER(12,2),
    discount_amount NUMBER(10,2) DEFAULT 0,
    tax_amount NUMBER(10,2) DEFAULT 0,
    shipping_cost NUMBER(10,2) DEFAULT 0,
    gross_margin NUMBER(12,2),
    
    -- Customer Interaction Details
    customer_satisfaction_score NUMBER(3,2),
    review_rating NUMBER,
    review_text VARCHAR,
    
    -- Performance Metrics
    order_processing_time_minutes NUMBER,
    shipping_time_days NUMBER,
    delivery_status VARCHAR,
    payment_method VARCHAR,
    payment_status VARCHAR,
    
    -- Business Intelligence Flags
    is_return BOOLEAN DEFAULT FALSE,
    is_express_delivery BOOLEAN DEFAULT FALSE,
    is_gift BOOLEAN DEFAULT FALSE,
    is_first_time_purchase BOOLEAN DEFAULT FALSE,
    is_repeat_customer BOOLEAN DEFAULT FALSE,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
CLUSTER BY (time_key, customer_key, product_key);

-- Dimension tables with appropriate clustering
CREATE OR REPLACE TABLE ecommerce_analytics_db.analytics.dim_time (
    time_key NUMBER PRIMARY KEY,
    date_value DATE NOT NULL,
    calendar_year NUMBER NOT NULL,
    calendar_month_number_in_year NUMBER NOT NULL,
    calendar_month_name VARCHAR(10) NOT NULL,
    day_of_week NUMBER NOT NULL,
    day_of_month NUMBER NOT NULL,
    is_weekend BOOLEAN,
    is_holiday BOOLEAN,
    -- ... other columns as in original
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
CLUSTER BY (calendar_year, calendar_month_number_in_year);

CREATE OR REPLACE TABLE ecommerce_analytics_db.analytics.dim_customer (
    customer_key NUMBER PRIMARY KEY,
    customer_id NUMBER NOT NULL,
    customer_name VARCHAR,
    customer_segment VARCHAR,
    -- ... other columns as in original
    geography_key NUMBER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
CLUSTER BY (customer_segment, geography_key);

-- ============================================================================
-- SNOWFLAKE FILE FORMATS AND STAGES
-- ============================================================================

-- Create file format for CSV files
CREATE OR REPLACE FILE FORMAT ecommerce_csv_format
TYPE = 'CSV'
FIELD_DELIMITER = ','
SKIP_HEADER = 1
FIELD_OPTIONALLY_ENCLOSED_BY = '"'
NULL_IF = ('NULL', 'null', '', 'N/A')
EMPTY_FIELD_AS_NULL = TRUE
ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;

-- Create file format for JSON files
CREATE OR REPLACE FILE FORMAT ecommerce_json_format
TYPE = 'JSON'
STRIP_OUTER_ARRAY = TRUE
ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;

-- Create external stage for data loading
CREATE OR REPLACE STAGE ecommerce_external_stage
URL = 's3://your-ecommerce-data-bucket/'
CREDENTIALS = (AWS_KEY_ID='your_access_key' AWS_SECRET_KEY='your_secret_key')
FILE_FORMAT = ecommerce_csv_format
COMMENT = 'Stage for loading e-commerce data files';

-- Create internal stage for temporary data
CREATE OR REPLACE STAGE ecommerce_internal_stage;

-- Show stages
SHOW STAGES;

-- ============================================================================
-- SNOWFLAKE SEMI-STRUCTURED DATA HANDLING
-- ============================================================================

-- Table to handle semi-structured data from web events
CREATE OR REPLACE TABLE ecommerce_analytics_db.raw_data.web_events_raw (
    raw_data VARIANT,
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    source_file_name VARCHAR,
    load_status VARCHAR DEFAULT 'LOADED'
);

-- Example query to extract structured data from semi-structured
SELECT 
    raw_data:sessionId::STRING AS session_id,
    raw_data:eventType::STRING AS event_type,
    raw_data:timestamp::TIMESTAMP AS event_timestamp,
    raw_data:userId::STRING AS user_id,
    raw_data:page:category::STRING AS page_category,
    raw_data:page:url::STRING AS page_url,
    raw_data:product:sku::STRING AS product_sku,
    raw_data:product:name::STRING AS product_name
FROM ecommerce_analytics_db.raw_data.web_events_raw
WHERE load_status = 'LOADED';

-- ============================================================================
-- SNOWFLAKE TIME TRAVEL AND DATA LINEAGE
-- ============================================================================

-- Example of time travel query to see data as it was 1 hour ago
SELECT COUNT(*) AS transaction_count
FROM ecommerce_analytics_db.analytics.fact_sales_transactions
AT(OFFSET => -3600)  -- 1 hour ago
WHERE transaction_date = CURRENT_DATE();

-- Query to see data as it was at a specific timestamp
SELECT COUNT(*) AS transaction_count
FROM ecommerce_analytics_db.analytics.fact_sales_transactions
BEFORE(STATEMENT => '2024-01-01 12:00:00');

-- Show available time travel periods
SELECT 
    TABLE_NAME,
    CREATED,
    LAST_DDL_TIME,
    ROW_COUNT,
    RETENTION_TIME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'ANALYTICS';

-- ============================================================================
-- SNOWFLAKE STREAMS FOR CHANGE DATA CAPTURE
-- ============================================================================

-- Create stream to capture changes in the fact table
CREATE OR REPLACE STREAM ecommerce_analytics_db.analytics.sales_transaction_changes
ON TABLE ecommerce_analytics_db.analytics.fact_sales_transactions;

-- Query the stream to see changes
SELECT 
    metadata$action AS change_action,
    metadata$isupdate AS is_update,
    sa.*
FROM ecommerce_analytics_db.analytics.sales_transaction_changes AS sa;

-- ============================================================================
-- SNOWFLAKE TASKS FOR AUTOMATED OPERATIONS
-- ============================================================================

-- Create task for daily data refresh
CREATE OR REPLACE TASK refresh_customer_segments
WAREHOUSE = 'COMPUTE_WH'
SCHEDULE = 'USING CRON 0 2 * * * UTC'  -- Daily at 2 AM UTC
AS
CALL ecommerce_analytics_db.analytics.sp_refresh_customer_segments();

-- Create task for weekly report generation
CREATE OR REPLACE TASK weekly_sales_report
WAREHOUSE = 'REPORTING_WH'
SCHEDULE = 'USING CRON 0 6 * * 1 UTC'  -- Weekly on Monday at 6 AM UTC
WHEN SYSTEM$STREAM_HAS_DATA('SALES_TRANSACTION_CHANGES')
AS
INSERT INTO ecommerce_analytics_db.analytics.weekly_sales_summary
SELECT 
    CURRENT_DATE() AS report_date,
    COUNT(*) AS total_transactions,
    SUM(total_revenue) AS total_revenue,
    AVG(total_revenue) AS avg_transaction_value
FROM ecommerce_analytics_db.analytics.fact_sales_transactions
WHERE transaction_date >= CURRENT_DATE() - 7;

-- Resume tasks
ALTER TASK refresh_customer_segments RESUME;
ALTER TASK weekly_sales_report RESUME;

-- Show tasks
SHOW TASKS;

-- ============================================================================
-- SNOWFLAKE RESOURCE MONITORS FOR COST OPTIMIZATION
-- ============================================================================

-- Create resource monitor to track and control warehouse usage
CREATE OR REPLACE RESOURCE MONITOR ecommerce_resource_monitor
WITH CREDIT_QUOTA = 100  -- Monthly credit limit
FREQ = MONTHLY
START_TIMESTAMP = NEXT_MONTH
TRIGGERS 
  ON 80 PERCENT DO SUSPEND
  ON 90 PERCENT DO SUSPEND_IMMEDIATE
  ON 95 PERCENT DO NOTIFY;

-- Apply resource monitor to warehouse
ALTER WAREHOUSE compute_wh SET RESOURCE_MONITOR = ecommerce_resource_monitor;

-- Show resource monitors
SHOW RESOURCE MONITORS;

-- ============================================================================
-- SNOWFLAKE MATERIALIZED VIEWS FOR PERFORMANCE
-- ============================================================================

-- Create materialized view for frequently queried customer analytics
CREATE MATERIALIZED VIEW ecommerce_analytics_db.analytics.mv_customer_lifetime_value
AS
SELECT 
    dc.customer_segment,
    COUNT(*) AS customer_count,
    SUM(fst.total_revenue) AS total_revenue,
    AVG(fst.total_revenue) AS avg_revenue_per_customer,
    MAX(fst.transaction_date) AS last_transaction_date
FROM ecommerce_analytics_db.analytics.dim_customer dc
JOIN ecommerce_analytics_db.analytics.fact_sales_transactions fst 
    ON dc.customer_key = fst.customer_key
GROUP BY dc.customer_segment;

-- Refresh materialized view
ALTER MATERIALIZED VIEW ecommerce_analytics_db.analytics.mv_customer_lifetime_value REFRESH;

-- Query materialized view
SELECT * FROM ecommerce_analytics_db.analytics.mv_customer_lifetime_value;

-- ============================================================================
-- SNOWFLAKE SEQUENCES FOR SURROGATE KEYS
-- ============================================================================

-- Create sequences for surrogate key generation
CREATE OR REPLACE SEQUENCE ecommerce_analytics_db.analytics.seq_customer_key
START = 1
INCREMENT = 1
COMMENT = 'Sequence for customer surrogate keys';

CREATE OR REPLACE SEQUENCE ecommerce_analytics_db.analytics.seq_product_key
START = 1
INCREMENT = 1
COMMENT = 'Sequence for product surrogate keys';

CREATE OR REPLACE SEQUENCE ecommerce_analytics_db.analytics.seq_sales_transaction_key
START = 1
INCREMENT = 1
COMMENT = 'Sequence for sales transaction surrogate keys';

-- Show sequences
SHOW SEQUENCES;

-- ============================================================================
-- SNOWFLAKE DATA SHARING AND SECURE VIEWS
-- ============================================================================

-- Create secure view for sensitive customer data
CREATE OR REPLACE SECURE VIEW ecommerce_analytics_db.marts.vw_customer_summary
AS
SELECT 
    customer_key,
    customer_segment,
    LEFT(customer_name, 1) || REPEAT('*', LENGTH(customer_name) - 2) || RIGHT(customer_name, 1) AS masked_customer_name,
    total_lifetime_value,
    total_orders_count,
    registration_date,
    geography_key
FROM ecommerce_analytics_db.analytics.dim_customer
WHERE is_active = TRUE;

-- Create secure view for sales reporting
CREATE OR REPLACE SECURE VIEW ecommerce_analytics_db.marts.vw_sales_performance
AS
SELECT 
    dt.calendar_year,
    dt.calendar_month_name,
    dp.product_category,
    COUNT(fst.sales_transaction_key) AS transaction_count,
    SUM(fst.total_revenue) AS total_revenue,
    AVG(fst.total_revenue) AS avg_order_value,
    COUNT(DISTINCT fst.customer_key) AS unique_customers
FROM ecommerce_analytics_db.analytics.fact_sales_transactions fst
JOIN ecommerce_analytics_db.analytics.dim_time dt ON fst.time_key = dt.time_key
JOIN ecommerce_analytics_db.analytics.dim_product dp ON fst.product_key = dp.product_key
WHERE fst.transaction_date >= DATEADD(MONTH, -12, CURRENT_DATE())  -- Last 12 months
GROUP BY dt.calendar_year, dt.calendar_month_name, dp.product_category;

-- ============================================================================
-- SNOWFLAKE COPY COMMANDS FOR DATA LOADING
-- ============================================================================

-- Example COPY command to load data from stage
COPY INTO ecommerce_analytics_db.analytics.fact_sales_transactions
FROM @ecommerce_external_stage/sales_data/
FILE_FORMAT = ecommerce_csv_format
ON_ERROR = 'CONTINUE'
PURGE = FALSE
FORCE = FALSE;

-- Show load history
SELECT 
    table_name,
    rows_loaded,
    load_timestamp,
    status
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'FACT_SALES_TRANSACTIONS',
    START_TIME => DATEADD(HOURS, -1, CURRENT_TIMESTAMP())
));

-- ============================================================================
-- SNOWFLAKE QUERY OPTIMIZATION WITH SNOWFLAKE-SPECIFIC FEATURES
-- ============================================================================

-- Example of query with result caching
SELECT 
    product_category,
    SUM(total_revenue) AS total_revenue
FROM ecommerce_analytics_db.analytics.fact_sales_transactions fst
JOIN ecommerce_analytics_db.analytics.dim_product dp ON fst.product_key = dp.product_key
WHERE transaction_date >= CURRENT_DATE() - 30
GROUP BY product_category
ORDER BY total_revenue DESC;

-- Example of query with automatic result reuse
-- The same query will benefit from result caching if run again within 24 hours
SELECT 
    product_category,
    SUM(total_revenue) AS total_revenue
FROM ecommerce_analytics_db.analytics.fact_sales_transactions fst
JOIN ecommerce_analytics_db.analytics.dim_product dp ON fst.product_key = dp.product_key
WHERE transaction_date >= CURRENT_DATE() - 30
GROUP BY product_category
ORDER BY total_revenue DESC;

-- Show query history to see performance metrics
SELECT 
    query_id,
    query_text,
    warehouse_name,
    execution_time,
    result_scanned_bytes,
    bytes_spilled_to_local_storage,
    bytes_spilled_to_remote_storage
FROM table(information_schema.query_history(
    date_range_start => DATEADD(HOURS, -24, CURRENT_TIMESTAMP()),
    result_limit => 10
))
WHERE query_text LIKE '%FACT_SALES_TRANSACTIONS%'
ORDER BY start_time DESC;

-- ============================================================================
-- SNOWFLAKE ZERO-COPY CLONING FOR DEVELOPMENT
-- ============================================================================

-- Example of creating a zero-copy clone for development/testing
-- This command would be run to create an isolated development copy
-- CREATE OR REPLACE DATABASE ecommerce_dev_db CLONE ecommerce_analytics_db;

-- Example of cloning a schema
-- CREATE OR REPLACE SCHEMA ecommerce_analytics_db.dev_test CLONE ecommerce_analytics_db.analytics;

-- ============================================================================
-- SNOWFLAKE ROW ACCESS POLICIES FOR DATA SECURITY
-- ============================================================================

-- Create row access policy to limit data access by region
CREATE OR REPLACE ROW ACCESS POLICY region_access_policy AS (region_filter STRING) 
RETURNS BOOLEAN -> 
CASE 
    WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'SECURITYADMIN') THEN TRUE
    WHEN region_filter = 'ALL' THEN TRUE
    ELSE region_filter = CURRENT_ROLE()
END;

-- Apply row access policy to a table (conceptual)
-- ALTER TABLE dim_customer ADD ROW ACCESS POLICY region_access_policy ON (geography_key);

-- ============================================================================
-- SNOWFLAKE SAMPLE IMPLEMENTATION SCRIPT
-- ============================================================================

-- Complete implementation script that demonstrates Snowflake best practices
CREATE OR REPLACE PROCEDURE ecommerce_analytics_db.analytics.sp_snowflake_etl_pipeline()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    result_msg STRING;
BEGIN
    -- Step 1: Load raw data
    COPY INTO ecommerce_analytics_db.raw_data.web_events_raw
    FROM @ecommerce_external_stage/web_events/
    FILE_FORMAT = ecommerce_json_format
    MATCH_BY_COLUMN_NAME = 'CASE_INSENSITIVE';
    
    -- Step 2: Transform and load into analytics schema
    INSERT INTO ecommerce_analytics_db.analytics.fact_web_events
    SELECT 
        SEQ_FACT_WEB_EVENTS_KEY.NEXTVAL AS web_event_key,
        raw_data:userId::NUMBER AS customer_key,
        -- Map date to time_key using dimension
        (SELECT time_key FROM ecommerce_analytics_db.analytics.dim_time WHERE date_value = raw_data:timestamp::DATE) AS time_key,
        raw_data:eventType::STRING AS event_type,
        raw_data:sessionId::STRING AS session_id,
        raw_data:timestamp::TIMESTAMP AS event_timestamp,
        raw_data:page:url::STRING AS page_url,
        raw_data:device:type::STRING AS device_type,
        raw_data:browser:name::STRING AS browser_name
    FROM ecommerce_analytics_db.raw_data.web_events_raw
    WHERE load_status = 'LOADED'
    AND raw_data:timestamp::DATE = CURRENT_DATE();
    
    -- Step 3: Update materialized views
    ALTER MATERIALIZED VIEW ecommerce_analytics_db.analytics.mv_customer_lifetime_value REFRESH;
    
    -- Step 4: Log successful completion
    INSERT INTO ecommerce_analytics_db.analytics.etl_log 
    VALUES (CURRENT_TIMESTAMP(), 'SNOWFLAKE_ETL_PIPELINE', 'SUCCESS', 'Daily data refresh completed');
    
    result_msg := 'Snowflake ETL pipeline completed successfully at ' || CURRENT_TIMESTAMP();
    RETURN result_msg;
END;
$$;

-- Call the procedure
CALL ecommerce_analytics_db.analytics.sp_snowflake_etl_pipeline();

-- Show the procedure
DESCRIBE PROCEDURE ecommerce_analytics_db.analytics.sp_snowflake_etl_pipeline();

-- ============================================================================
-- SNOWFLAKE MONITORING AND MAINTENANCE QUERIES
-- ============================================================================

-- Query to monitor warehouse usage
SELECT 
    warehouse_name,
    start_time,
    end_time,
    credits_used,
    state
FROM table(information_schema.warehouse_metering_history(
    date_range_start => DATEADD(DAYS, -7, CURRENT_TIMESTAMP()),
    date_range_end => CURRENT_TIMESTAMP()
))
WHERE warehouse_name IN ('DEV_WH', 'COMPUTE_WH', 'REPORTING_WH')
ORDER BY start_time DESC;

-- Query to monitor table sizes
SELECT 
    table_schema,
    table_name,
    row_count,
    used_bytes,
    pg_size_pretty(used_bytes) AS size_formatted
FROM information_schema.tables
WHERE table_schema = 'ANALYTICS'
ORDER BY used_bytes DESC;

-- Query to monitor active queries
SELECT 
    query_id,
    user_name,
    warehouse_name,
    query_text,
    start_time,
    total_elapsed_time,
    bytes_scanned
FROM table(information_schema.query_history(
    date_range_start => DATEADD(HOURS, -1, CURRENT_TIMESTAMP()),
    result_limit => 20
))
ORDER BY start_time DESC;