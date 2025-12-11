-- ============================================================================
-- E-COMMERCE ANALYTICS & CUSTOMER INTELLIGENCE PLATFORM
-- STORED PROCEDURES & FUNCTIONS
-- For LLM Training Data Portfolio Project
-- Author: SQL Developer Portfolio
-- Date: 2025-01-04
-- Description: 8+ stored procedures and functions for business logic
-- ============================================================================

-- ============================================================================
-- FUNCTION 1: Get Customer Segment Based on Business Rules
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_customer_segment(
    p_total_revenue DECIMAL(12,2),
    p_total_orders INT,
    p_days_since_last_purchase INT,
    p_loyalty_member BOOLEAN
)
RETURNS VARCHAR(20)
LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_segment VARCHAR(20);
BEGIN
    -- Apply business logic to determine customer segment
    IF p_total_revenue >= 2000 AND p_total_orders >= 10 AND p_days_since_last_purchase <= 90 THEN
        v_customer_segment := 'Premium';
    ELSIF p_total_revenue >= 1000 AND p_total_orders >= 5 AND p_days_since_last_purchase <= 120 THEN
        v_customer_segment := 'Gold';
    ELSIF p_total_revenue >= 500 AND p_total_orders >= 3 AND p_days_since_last_purchase <= 180 THEN
        v_customer_segment := 'Silver';
    ELSIF p_total_revenue >= 200 AND p_days_since_last_purchase <= 365 THEN
        v_customer_segment := 'Bronze';
    ELSIF p_days_since_last_purchase > 365 THEN
        v_customer_segment := 'Inactive';
    ELSE
        v_customer_segment := 'New';
    END IF;

    RETURN v_customer_segment;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in fn_get_customer_segment: %', SQLERRM;
        RETURN 'Unknown';
END;
$$;

-- Test the function
SELECT fn_get_customer_segment(2500.00, 15, 30, TRUE) AS test_segment;

-- ============================================================================
-- FUNCTION 2: Calculate Customer Discount Based on Tier and Loyalty
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_calculate_discount(
    p_customer_segment VARCHAR(20),
    p_loyalty_member BOOLEAN,
    p_product_category VARCHAR(100),
    p_base_price DECIMAL(10,2)
)
RETURNS DECIMAL(10,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_discount_amount DECIMAL(10,2) := 0;
    v_discount_rate DECIMAL(5,4) := 0;
BEGIN
    -- Determine base discount rate by customer segment
    CASE p_customer_segment
        WHEN 'Premium' THEN v_discount_rate := 0.15; -- 15% discount
        WHEN 'Gold' THEN v_discount_rate := 0.10;    -- 10% discount
        WHEN 'Silver' THEN v_discount_rate := 0.05;  -- 5% discount
        WHEN 'Bronze' THEN v_discount_rate := 0.02;  -- 2% discount
        ELSE v_discount_rate := 0.00; -- No discount
    END CASE;

    -- Additional discount for loyalty members
    IF p_loyalty_member THEN
        v_discount_rate := v_discount_rate + 0.02; -- Extra 2% for loyalty
    END IF;

    -- Category-specific promotions
    IF p_product_category = 'Electronics' THEN
        v_discount_rate := v_discount_rate + 0.03; -- Extra 3% for electronics
    ELSIF p_product_category = 'Entertainment' THEN
        v_discount_rate := v_discount_rate + 0.05; -- Extra 5% for entertainment
    END IF;

    -- Ensure discount doesn't exceed 25%
    IF v_discount_rate > 0.25 THEN
        v_discount_rate := 0.25;
    END IF;

    -- Calculate discount amount
    v_discount_amount := p_base_price * v_discount_rate;

    RETURN v_discount_amount;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in fn_calculate_discount: %', SQLERRM;
        RETURN 0;
END;
$$;

-- Test the function
SELECT fn_calculate_discount('Gold', TRUE, 'Electronics', 500.00) AS discount_amount;

-- ============================================================================
-- FUNCTION 3: Convert Date to Fiscal Period
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_fiscal_period(
    p_date DATE
)
RETURNS TABLE(
    fiscal_year INT,
    fiscal_quarter VARCHAR(10),
    fiscal_month VARCHAR(10),
    fiscal_half_year VARCHAR(10)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_month INT;
    v_year INT;
BEGIN
    v_month := EXTRACT(MONTH FROM p_date);
    v_year := EXTRACT(YEAR FROM p_date);

    -- Fiscal year runs from July to June
    -- For dates July-Dec, fiscal year is current year + 1
    -- For dates Jan-June, fiscal year is current year
    IF v_month >= 7 THEN
        fiscal_year := v_year + 1;
    ELSE
        fiscal_year := v_year;
    END IF;

    -- Determine fiscal quarter (Q1: July-September, Q2: October-December, etc.)
    IF v_month IN (7, 8, 9) THEN
        fiscal_quarter := 'FQ1';
        fiscal_half_year := 'FH1';
    ELSIF v_month IN (10, 11, 12) THEN
        fiscal_quarter := 'FQ2';
        fiscal_half_year := 'FH1';
    ELSIF v_month IN (1, 2, 3) THEN
        fiscal_quarter := 'FQ3';
        fiscal_half_year := 'FH2';
    ELSE -- months 4, 5, 6
        fiscal_quarter := 'FQ4';
        fiscal_half_year := 'FH2';
    END IF;

    -- Fiscal month name
    CASE v_month
        WHEN 7 THEN fiscal_month := 'July';
        WHEN 8 THEN fiscal_month := 'August';
        WHEN 9 THEN fiscal_month := 'September';
        WHEN 10 THEN fiscal_month := 'October';
        WHEN 11 THEN fiscal_month := 'November';
        WHEN 12 THEN fiscal_month := 'December';
        WHEN 1 THEN fiscal_month := 'January';
        WHEN 2 THEN fiscal_month := 'February';
        WHEN 3 THEN fiscal_month := 'March';
        WHEN 4 THEN fiscal_month := 'April';
        WHEN 5 THEN fiscal_month := 'May';
        WHEN 6 THEN fiscal_month := 'June';
    END CASE;

    RETURN NEXT;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in fn_get_fiscal_period: %', SQLERRM;
        fiscal_year := NULL;
        fiscal_quarter := NULL;
        fiscal_month := NULL;
        fiscal_half_year := NULL;
        RETURN NEXT;
END;
$$;

-- Test the function
SELECT * FROM fn_get_fiscal_period('2024-08-15'::DATE);

-- ============================================================================
-- PROCEDURE 1: Calculate Customer Lifetime Value
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_calculate_customer_lifetime_value(
    IN p_customer_key INT DEFAULT NULL,  -- If NULL, calculate for all customers
    OUT p_status_message VARCHAR(255)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_count INT := 0;
    v_error_count INT := 0;
    v_customer_record RECORD;
    v_clv DECIMAL(12,2);
    v_total_revenue DECIMAL(12,2);
    v_total_orders INT;
    v_avg_order_value DECIMAL(10,2);
    v_customer_lifespan_days INT;
    v_purchase_frequency DECIMAL(10,2);
BEGIN
    p_status_message := 'Starting CLV calculation';
    
    -- If no customer key provided, calculate for all customers
    IF p_customer_key IS NULL THEN
        p_status_message := p_status_message || ' for all customers';
        
        -- Use cursor to process each customer individually
        FOR v_customer_record IN 
            SELECT customer_key FROM dim_customer
        LOOP
            BEGIN
                -- Calculate metrics for this customer
                SELECT 
                    COALESCE(SUM(total_revenue), 0),
                    COUNT(sales_transaction_key),
                    COALESCE(AVG(total_revenue), 0),
                    COALESCE(EXTRACT(DAY FROM (MAX(transaction_date) - MIN(transaction_date))), 0)
                INTO 
                    v_total_revenue, v_total_orders, v_avg_order_value, v_customer_lifespan_days
                FROM fact_sales_transactions
                WHERE customer_key = v_customer_record.customer_key 
                    AND transaction_type = 'Purchase';
                
                -- Calculate purchase frequency
                IF v_customer_lifespan_days > 0 THEN
                    v_purchase_frequency := v_total_orders / (v_customer_lifespan_days / 365.0);
                ELSE
                    v_purchase_frequency := 0;
                END IF;
                
                -- Calculate CLV: (Average Order Value * Purchase Frequency) * Average Customer Lifespan
                -- Using conservative 2-year lifespan assumption
                v_clv := (v_avg_order_value * v_purchase_frequency) * 2;
                
                -- Update the customer dimension with calculated CLV
                UPDATE dim_customer 
                SET total_lifetime_value = v_total_revenue,
                    total_orders_count = v_total_orders,
                    average_order_value = v_avg_order_value
                WHERE customer_key = v_customer_record.customer_key;
                
                v_customer_count := v_customer_count + 1;
                
            EXCEPTION
                WHEN OTHERS THEN
                    v_error_count := v_error_count + 1;
                    RAISE NOTICE 'Error calculating CLV for customer %: %', v_customer_record.customer_key, SQLERRM;
            END;
        END LOOP;
    ELSE
        -- Calculate for specific customer
        BEGIN
            SELECT 
                COALESCE(SUM(total_revenue), 0),
                COUNT(sales_transaction_key),
                COALESCE(AVG(total_revenue), 0),
                COALESCE(EXTRACT(DAY FROM (MAX(transaction_date) - MIN(transaction_date))), 0)
            INTO 
                v_total_revenue, v_total_orders, v_avg_order_value, v_customer_lifespan_days
            FROM fact_sales_transactions
            WHERE customer_key = p_customer_key 
                AND transaction_type = 'Purchase';
            
            IF v_customer_lifespan_days > 0 THEN
                v_purchase_frequency := v_total_orders / (v_customer_lifespan_days / 365.0);
            ELSE
                v_purchase_frequency := 0;
            END IF;
            
            v_clv := (v_avg_order_value * v_purchase_frequency) * 2;
            
            UPDATE dim_customer 
            SET total_lifetime_value = v_total_revenue,
                total_orders_count = v_total_orders,
                average_order_value = v_avg_order_value
            WHERE customer_key = p_customer_key;
            
            v_customer_count := 1;
            
        EXCEPTION
            WHEN OTHERS THEN
                v_error_count := v_error_count + 1;
                RAISE EXCEPTION 'Error calculating CLV for customer %: %', p_customer_key, SQLERRM;
        END;
    END IF;
    
    p_status_message := p_status_message || '. Processed ' || v_customer_count || ' customers with ' || v_error_count || ' errors.';
EXCEPTION
    WHEN OTHERS THEN
        p_status_message := 'Error in sp_calculate_customer_lifetime_value: ' || SQLERRM;
        RAISE;
END;
$$;

-- Test the procedure
CALL sp_calculate_customer_lifetime_value();
SELECT customer_name, total_lifetime_value, total_orders_count, average_order_value
FROM dim_customer 
WHERE customer_key <= 10;

-- ============================================================================
-- PROCEDURE 2: Generate Parameterized Sales Report
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_generate_sales_report(
    IN p_start_date DATE DEFAULT '2023-01-01',
    IN p_end_date DATE DEFAULT CURRENT_DATE,
    IN p_product_category VARCHAR(100) DEFAULT NULL,
    IN p_customer_segment VARCHAR(50) DEFAULT NULL,
    IN p_output_format VARCHAR(20) DEFAULT 'SUMMARY'  -- SUMMARY, DETAILED, or CSV
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql TEXT;
    v_report_date TIMESTAMP := NOW();
BEGIN
    -- Create a temporary table to store the report results
    DROP TABLE IF EXISTS temp_sales_report;
    CREATE TEMP TABLE temp_sales_report (
        report_id SERIAL PRIMARY KEY,
        report_name VARCHAR(100),
        metric_name VARCHAR(100),
        metric_value TEXT,
        calculated_date TIMESTAMP DEFAULT NOW()
    );

    -- Insert report header information
    INSERT INTO temp_sales_report (report_name, metric_name, metric_value)
    VALUES 
        ('Sales Report', 'Report Period Start', p_start_date::TEXT),
        ('Sales Report', 'Report Period End', p_end_date::TEXT),
        ('Sales Report', 'Product Category Filter', COALESCE(p_product_category, 'All Categories')),
        ('Sales Report', 'Customer Segment Filter', COALESCE(p_customer_segment, 'All Segments')),
        ('Sales Report', 'Output Format', p_output_format),
        ('Sales Report', 'Report Generated', v_report_date::TEXT);

    -- Insert summary metrics
    v_sql := '
    INSERT INTO temp_sales_report (report_name, metric_name, metric_value)
    SELECT 
        ''Sales Report'' as report_name,
        metric_name,
        metric_value
    FROM (
        SELECT ''Total Revenue'' as metric_name, SUM(total_revenue)::TEXT as metric_value
        FROM fact_sales_transactions fst
        JOIN dim_time dt ON fst.time_key = dt.time_key
        JOIN dim_product dp ON fst.product_key = dp.product_key
        JOIN dim_customer dc ON fst.customer_key = dc.customer_key
        WHERE dt.date_value BETWEEN $1 AND $2'
        || COALESCE(' AND dp.product_category = ''' || p_product_category || '''', '')
        || COALESCE(' AND dc.customer_segment = ''' || p_customer_segment || '''', '') || '
        
        UNION ALL
        
        SELECT ''Total Transactions'' as metric_name, COUNT(*)::TEXT as metric_value
        FROM fact_sales_transactions fst
        JOIN dim_time dt ON fst.time_key = dt.time_key
        JOIN dim_product dp ON fst.product_key = dp.product_key
        JOIN dim_customer dc ON fst.customer_key = dc.customer_key
        WHERE dt.date_value BETWEEN $1 AND $2'
        || COALESCE(' AND dp.product_category = ''' || p_product_category || '''', '')
        || COALESCE(' AND dc.customer_segment = ''' || p_customer_segment || '''', '') || '
        
        UNION ALL
        
        SELECT ''Average Order Value'' as metric_name, 
               ROUND(AVG(total_revenue), 2)::TEXT as metric_value
        FROM fact_sales_transactions fst
        JOIN dim_time dt ON fst.time_key = dt.time_key
        JOIN dim_product dp ON fst.product_key = dp.product_key
        JOIN dim_customer dc ON fst.customer_key = dc.customer_key
        WHERE dt.date_value BETWEEN $1 AND $2'
        || COALESCE(' AND dp.product_category = ''' || p_product_category || '''', '')
        || COALESCE(' AND dc.customer_segment = ''' || p_customer_segment || '''', '') || '
        
        UNION ALL
        
        SELECT ''Total Products Sold'' as metric_name, 
               SUM(quantity_sold)::TEXT as metric_value
        FROM fact_sales_transactions fst
        JOIN dim_time dt ON fst.time_key = dt.time_key
        JOIN dim_product dp ON fst.product_key = dp.product_key
        JOIN dim_customer dc ON fst.customer_key = dc.customer_key
        WHERE dt.date_value BETWEEN $1 AND $2'
        || COALESCE(' AND dp.product_category = ''' || p_product_category || '''', '')
        || COALESCE(' AND dc.customer_segment = ''' || p_customer_segment || '''', '') || '
    ) subquery';
    
    EXECUTE v_sql USING p_start_date, p_end_date;

    -- Output results based on format
    IF p_output_format = 'SUMMARY' THEN
        RAISE NOTICE 'Sales Report Generated. Summary Metrics:';
        RAISE NOTICE 'Period: % to %', p_start_date, p_end_date;
        
        -- Show summary results
        FOR v_sql IN 
            SELECT metric_name || ': ' || metric_value 
            FROM temp_sales_report 
            WHERE metric_name IN ('Total Revenue', 'Total Transactions', 'Average Order Value', 'Total Products Sold')
        LOOP
            RAISE NOTICE '%', v_sql;
        END LOOP;
    ELSIF p_output_format = 'CSV' THEN
        RAISE NOTICE 'CSV output would be generated here';
        -- In a real implementation, this would generate actual CSV content
    ELSE
        RAISE NOTICE 'Detailed report with individual records would be generated';
    END IF;

    -- Clean up
    DROP TABLE temp_sales_report;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in sp_generate_sales_report: %', SQLERRM;
        DROP TABLE IF EXISTS temp_sales_report;
        RAISE;
END;
$$;

-- Test the procedure
CALL sp_generate_sales_report('2024-01-01', '2024-12-31', 'Electronics', 'Gold', 'SUMMARY');

-- ============================================================================
-- PROCEDURE 3: Refresh Customer Segments
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_refresh_customer_segments()
LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_count INT := 0;
    v_update_count INT := 0;
    v_cursor CURSOR FOR
        SELECT 
            dc.customer_key,
            dc.customer_name,
            SUM(COALESCE(fst.total_revenue, 0)) AS total_revenue,
            COUNT(fst.sales_transaction_key) AS total_transactions,
            COALESCE(MAX(fst.transaction_date), dc.registration_date) AS last_purchase_date
        FROM dim_customer dc
        LEFT JOIN fact_sales_transactions fst ON dc.customer_key = fst.customer_key
        WHERE fst.transaction_type = 'Purchase' OR fst IS NULL
        GROUP BY dc.customer_key, dc.customer_name, dc.registration_date;
    v_record RECORD;
    v_new_segment VARCHAR(50);
    v_days_since_last_purchase INT;
BEGIN
    -- Process each customer to update their segment
    OPEN v_cursor;
    LOOP
        FETCH v_cursor INTO v_record;
        EXIT WHEN NOT FOUND;
        
        -- Calculate days since last purchase
        v_days_since_last_purchase := EXTRACT(DAY FROM (CURRENT_DATE - v_record.last_purchase_date));
        
        -- Determine new segment using the function
        v_new_segment := fn_get_customer_segment(
            v_record.total_revenue,
            v_record.total_transactions,
            v_days_since_last_purchase,
            v_record.customer_key IN (SELECT customer_key FROM dim_customer WHERE loyalty_member = TRUE)
        );
        
        -- Update customer segment if changed
        UPDATE dim_customer 
        SET 
            customer_segment = v_new_segment,
            updated_at = CURRENT_TIMESTAMP
        WHERE customer_key = v_record.customer_key
            AND (customer_segment IS DISTINCT FROM v_new_segment);
        
        IF FOUND THEN
            v_update_count := v_update_count + 1;
        END IF;
        
        v_customer_count := v_customer_count + 1;
        
    END LOOP;
    CLOSE v_cursor;
    
    RAISE NOTICE 'Customer segments refreshed: % customers processed, % updated', 
                 v_customer_count, v_update_count;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in sp_refresh_customer_segments: %', SQLERRM;
        RAISE;
END;
$$;

-- Test the procedure
CALL sp_refresh_customer_segments();

-- ============================================================================
-- PROCEDURE 4: Load Daily Sales Data (ETL)
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_load_daily_sales_data(
    IN p_process_date DATE DEFAULT CURRENT_DATE,
    OUT p_status_message VARCHAR(255),
    OUT p_records_processed INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_staging_count INT := 0;
    v_error_count INT := 0;
    v_processed_count INT := 0;
    v_sql TEXT;
    v_error_message TEXT;
BEGIN
    p_status_message := 'Starting daily sales data load for ' || p_process_date;
    p_records_processed := 0;
    
    -- First, validate staging data for the given date
    SELECT COUNT(*) INTO v_staging_count
    FROM stg_sales_transactions 
    WHERE load_status = 'New' 
      AND processed_flag = FALSE
      AND transaction_date_str::DATE = p_process_date;
    
    RAISE NOTICE 'Found % records in staging for date %', v_staging_count, p_process_date;
    
    -- Process each record in staging with error handling
    -- In this example, we'll simulate the ETL process
    BEGIN
        -- Update load status to processing
        UPDATE stg_sales_transactions
        SET load_status = 'Processing',
            load_date = CURRENT_TIMESTAMP
        WHERE transaction_date_str::DATE = p_process_date 
          AND load_status = 'New'
          AND processed_flag = FALSE;
        
        -- Process valid records and insert into fact table
        -- First, handle data conversions and validations
        CREATE TEMP TABLE temp_converted_sales AS
        SELECT 
            staging_id,
            source_transaction_id,
            source_customer_id::INT AS customer_id,
            source_product_code,
            transaction_date_str::DATE AS transaction_date,
            transaction_time_str::TIME AS transaction_time,
            transaction_type,
            order_id,
            order_item_id,
            quantity_sold_str::INT AS quantity_sold,
            unit_price_str::DECIMAL(10,2) AS unit_price,
            COALESCE(discount_amount_str::DECIMAL(10,2), 0) AS discount_amount,
            COALESCE(tax_amount_str::DECIMAL(10,2), 0) AS tax_amount,
            COALESCE(shipping_cost_str::DECIMAL(10,2), 0) AS shipping_cost,
            customer_satisfaction_score_str::DECIMAL(3,2) AS satisfaction_score,
            review_rating_str::INT AS review_rating,
            delivery_status,
            payment_method
        FROM stg_sales_transactions
        WHERE transaction_date_str::DATE = p_process_date
          AND load_status = 'Processing'
          AND staging_id IN (
              SELECT staging_id FROM stg_sales_transactions 
              WHERE transaction_date_str::DATE = p_process_date 
                AND load_status = 'Processing'
                -- Add validation checks here
                AND source_customer_id ~ '^[0-9]+$'  -- Check if numeric
                AND source_product_code IS NOT NULL
                AND quantity_sold_str ~ '^[0-9]+$'    -- Check if numeric
                AND unit_price_str ~ '^[0-9]+\.?[0-9]*$'  -- Check if numeric
          );
        
        -- Insert valid records into the fact table
        -- For this example, we'll map to existing surrogate keys
        -- In a real ETL, we would do proper lookups
        INSERT INTO fact_sales_transactions (
            transaction_id,
            customer_key, 
            product_key,
            time_key,
            geography_key,
            marketing_channel_key,
            transaction_date,
            transaction_time,
            transaction_type,
            order_id,
            order_item_id,
            quantity_sold,
            unit_price,
            unit_cost,
            total_revenue,
            total_cost,
            total_profit,
            discount_amount,
            tax_amount,
            shipping_cost,
            customer_satisfaction_score,
            review_rating,
            delivery_status,
            payment_method,
            created_at
        )
        SELECT 
            tcs.source_transaction_id,
            COALESCE((SELECT customer_key FROM dim_customer WHERE customer_id = tcs.customer_id LIMIT 1), 1) AS customer_key,
            COALESCE((SELECT product_key FROM dim_product WHERE product_code = tcs.source_product_code LIMIT 1), 1) AS product_key,
            COALESCE((SELECT time_key FROM dim_time WHERE date_value = tcs.transaction_date LIMIT 1), 1) AS time_key,
            COALESCE((SELECT geography_key FROM dim_customer WHERE customer_id = tcs.customer_id LIMIT 1), 1) AS geography_key,
            1 AS marketing_channel_key, -- Default
            tcs.transaction_date,
            tcs.transaction_time,
            tcs.transaction_type,
            tcs.order_id,
            tcs.order_item_id,
            tcs.quantity_sold,
            tcs.unit_price,
            tcs.unit_price * 0.7, -- Assuming 70% cost
            tcs.quantity_sold * tcs.unit_price, -- total_revenue
            tcs.quantity_sold * tcs.unit_price * 0.7, -- total_cost
            tcs.quantity_sold * tcs.unit_price - tcs.quantity_sold * tcs.unit_price * 0.7, -- total_profit
            tcs.discount_amount,
            tcs.tax_amount,
            tcs.shipping_cost,
            tcs.satisfaction_score,
            tcs.review_rating,
            tcs.delivery_status,
            tcs.payment_method,
            CURRENT_TIMESTAMP
        FROM temp_converted_sales tcs;
        
        -- Update staging records to mark as processed successfully
        -- In a real scenario, we would use the actual inserted IDs
        p_records_processed := (SELECT COUNT(*) FROM temp_converted_sales);
        
        -- Mark staging records as processed
        UPDATE stg_sales_transactions 
        SET 
            load_status = 'Loaded',
            processed_flag = TRUE,
            load_date = CURRENT_TIMESTAMP
        WHERE staging_id IN (SELECT staging_id FROM temp_converted_sales);
        
        -- Mark any remaining records as errors
        UPDATE stg_sales_transactions 
        SET 
            load_status = 'Error',
            error_message = 'Data validation failed',
            processed_flag = TRUE,
            load_date = CURRENT_TIMESTAMP
        WHERE transaction_date_str::DATE = p_process_date
          AND load_status = 'Processing';
        
        -- Clean up temp table
        DROP TABLE temp_converted_sales;
        
        p_status_message := 'Successfully processed ' || p_records_processed || ' records for date ' || p_process_date;
        
    EXCEPTION
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
            p_status_message := 'Error processing daily sales data for ' || p_process_date || ': ' || v_error_message;
            RAISE NOTICE '%', p_status_message;
            
            -- Mark any records currently in processing as errors
            UPDATE stg_sales_transactions 
            SET 
                load_status = 'Error',
                error_message = v_error_message,
                processed_flag = TRUE,
                load_date = CURRENT_TIMESTAMP
            WHERE transaction_date_str::DATE = p_process_date
              AND load_status = 'Processing';
    END;
EXCEPTION
    WHEN OTHERS THEN
        p_status_message := 'Critical error in sp_load_daily_sales_data: ' || SQLERRM;
        RAISE;
END;
$$;

-- Test the procedure
CALL sp_load_daily_sales_data('2024-01-01');

-- ============================================================================
-- PROCEDURE 5: Data Quality Check
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_data_quality_check(
    OUT p_quality_score INT,
    OUT p_issue_summary TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_checks INT := 0;
    v_failed_checks INT := 0;
    v_quality_issues TEXT := '';
    v_issue_count INT;
    v_issue_description TEXT;
BEGIN
    p_quality_score := 100;
    p_issue_summary := '';
    
    -- Check 1: Null values in critical fields
    v_total_checks := v_total_checks + 1;
    SELECT COUNT(*) INTO v_issue_count
    FROM fact_sales_transactions
    WHERE transaction_date IS NULL OR customer_key IS NULL OR product_key IS NULL;
    
    IF v_issue_count > 0 THEN
        v_failed_checks := v_failed_checks + 1;
        v_quality_issues := v_quality_issues || 'NULL values in critical transaction fields: ' || v_issue_count || ' records; ';
    END IF;
    
    -- Check 2: Invalid financial data
    v_total_checks := v_total_checks + 1;
    SELECT COUNT(*) INTO v_issue_count
    FROM fact_sales_transactions
    WHERE total_revenue < 0 OR quantity_sold <= 0 OR unit_price < 0;
    
    IF v_issue_count > 0 THEN
        v_failed_checks := v_failed_checks + 1;
        v_quality_issues := v_quality_issues || 'Invalid financial data: ' || v_issue_count || ' records; ';
    END IF;
    
    -- Check 3: Foreign key integrity
    v_total_checks := v_total_checks + 1;
    SELECT COUNT(*) INTO v_issue_count
    FROM fact_sales_transactions fst
    LEFT JOIN dim_customer dc ON fst.customer_key = dc.customer_key
    WHERE dc.customer_key IS NULL;
    
    IF v_issue_count > 0 THEN
        v_failed_checks := v_failed_checks + 1;
        v_quality_issues := v_quality_issues || 'Invalid customer foreign keys: ' || v_issue_count || ' records; ';
    END IF;
    
    -- Check 4: Date range validation
    v_total_checks := v_total_checks + 1;
    SELECT COUNT(*) INTO v_issue_count
    FROM fact_sales_transactions
    WHERE transaction_date < '2020-01-01' OR transaction_date > CURRENT_DATE + INTERVAL '1 day';
    
    IF v_issue_count > 0 THEN
        v_failed_checks := v_failed_checks + 1;
        v_quality_issues := v_quality_issues || 'Invalid transaction dates: ' || v_issue_count || ' records; ';
    END IF;
    
    -- Check 5: Duplicate transaction IDs
    v_total_checks := v_total_checks + 1;
    SELECT COUNT(*) - COUNT(DISTINCT transaction_id) INTO v_issue_count
    FROM fact_sales_transactions
    WHERE transaction_id IS NOT NULL;
    
    IF v_issue_count > 0 THEN
        v_failed_checks := v_failed_checks + 1;
        v_quality_issues := v_quality_issues || 'Duplicate transaction IDs: ' || v_issue_count || ' records; ';
    END IF;
    
    -- Calculate quality score
    IF v_total_checks > 0 THEN
        p_quality_score := 100 - ((v_failed_checks * 100) / v_total_checks);
    ELSE
        p_quality_score := 100;
    END IF;
    
    p_issue_summary := v_quality_issues;
    
    -- Log results
    RAISE NOTICE 'Data Quality Check Results: Score: %%, Passed: %, Failed: %', 
                 p_quality_score, (v_total_checks - v_failed_checks), v_failed_checks;
    IF p_issue_summary != '' THEN
        RAISE NOTICE 'Issues Found: %', p_issue_summary;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in sp_data_quality_check: %', SQLERRM;
        p_quality_score := 0;
        p_issue_summary := 'Error occurred during quality check: ' || SQLERRM;
END;
$$;

-- Test the procedure
CALL sp_data_quality_check();