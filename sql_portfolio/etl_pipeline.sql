-- ============================================================================
-- E-COMMERCE ANALYTICS & CUSTOMER INTELLIGENCE PLATFORM
-- ETL PIPELINE IMPLEMENTATION
-- For LLM Training Data Portfolio Project
-- Author: SQL Developer Portfolio
-- Date: 2025-01-04
-- Description: Complete ETL workflow for the data warehouse
-- ============================================================================

-- ============================================================================
-- STAGE 1: EXTRACT - STAGING TABLE CREATION AND DATA INGESTION
-- ============================================================================

-- The staging tables have already been created in Phase 1
-- Now we'll create procedures to handle the staging layer

-- ============================================================================
-- PROCEDURE: Load Data into Staging Tables
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_load_staging_data(
    IN p_source_type VARCHAR(50),  -- 'SALES', 'WEB_EVENTS', 'CUSTOMERS'
    IN p_file_path VARCHAR(500),   -- Path to source file
    OUT p_status_message VARCHAR(255),
    OUT p_records_loaded INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql TEXT;
    v_record_count INT := 0;
BEGIN
    p_status_message := 'Starting data load for ' || p_source_type;
    p_records_loaded := 0;
    
    IF p_source_type = 'SALES' THEN
        -- Simulate loading sales data into staging table
        -- In real implementation, this would use COPY or similar to load from file
        -- For demonstration, we'll insert some sample records
        
        -- First, clear out any "New" records for this demonstration
        DELETE FROM stg_sales_transactions WHERE load_status = 'New';
        
        -- Insert sample records to simulate file load
        INSERT INTO stg_sales_transactions (
            source_transaction_id, source_customer_id, source_product_code,
            transaction_date_str, transaction_time_str, transaction_type,
            order_id, order_item_id, quantity_sold_str, unit_price_str,
            discount_amount_str, tax_amount_str, shipping_cost_str,
            customer_satisfaction_score_str, review_rating_str,
            delivery_status, payment_method
        )
        SELECT 
            'TXN' || generate_series(1000, 1010) AS source_transaction_id,
            (generate_series(1000, 1010) % 100 + 1001)::VARCHAR AS source_customer_id,
            'PRD' || LPAD((generate_series(1000, 1010) % 500 + 1)::TEXT, 4, '0') AS source_product_code,
            CURRENT_DATE::VARCHAR AS transaction_date_str,
            '12:00:00' AS transaction_time_str,
            'Purchase' AS transaction_type,
            'ORD' || LPAD(generate_series(1000, 1010)::TEXT, 6, '0') AS order_id,
            'ORD' || LPAD(generate_series(1000, 1010)::TEXT, 6, '0') || '-1' AS order_item_id,
            (generate_series(1, 11))::VARCHAR AS quantity_sold_str,
            (generate_series(10, 110, 10))::VARCHAR AS unit_price_str,
            '0.00' AS discount_amount_str,
            '0.00' AS tax_amount_str,
            '0.00' AS shipping_cost_str,
            '4.5' AS customer_satisfaction_score_str,
            '5' AS review_rating_str,
            'Pending' AS delivery_status,
            'Credit Card' AS payment_method;
        
        SELECT COUNT(*) INTO v_record_count FROM stg_sales_transactions WHERE load_status = 'New';
        p_records_loaded := v_record_count;
        p_status_message := 'Loaded ' || v_record_count || ' sales records into staging';
        
    ELSIF p_source_type = 'WEB_EVENTS' THEN
        -- Similar for web events
        DELETE FROM stg_web_events WHERE load_status = 'New';
        
        INSERT INTO stg_web_events (
            source_event_id, source_user_id, event_date_str, event_time_str,
            event_type, page_url, referrer_url, utm_source, utm_medium,
            device_type, session_id
        )
        SELECT 
            'EV' || generate_series(1000, 1005) AS source_event_id,
            'USR' || (generate_series(1000, 1005) % 100 + 1001)::VARCHAR AS source_user_id,
            CURRENT_DATE::VARCHAR AS event_date_str,
            '14:30:00' AS event_time_str,
            'page_view' AS event_type,
            '/product/' || (generate_series(1, 6)) AS page_url,
            'https://google.com' AS referrer_url,
            'google' AS utm_source,
            'cpc' AS utm_medium,
            'Desktop' AS device_type,
            'SES' || LPAD(generate_series(1000, 1005)::TEXT, 8, '0') AS session_id;
        
        SELECT COUNT(*) INTO v_record_count FROM stg_web_events WHERE load_status = 'New';
        p_records_loaded := v_record_count;
        p_status_message := 'Loaded ' || v_record_count || ' web event records into staging';
        
    ELSIF p_source_type = 'CUSTOMERS' THEN
        -- Similar for customers
        DELETE FROM stg_customers WHERE load_status = 'New';
        
        INSERT INTO stg_customers (
            source_customer_id, customer_name, customer_segment, gender,
            date_of_birth_str, marital_status, registration_date_str,
            country, region, city, annual_income_str
        )
        SELECT 
            (1000 + generate_series(1, 5))::VARCHAR AS source_customer_id,
            'Customer ' || generate_series(1, 5) AS customer_name,
            'Gold' AS customer_segment,
            CASE generate_series(1, 5) % 2 WHEN 0 THEN 'M' ELSE 'F' END AS gender,
            '1980-01-01' AS date_of_birth_str,
            'Single' AS marital_status,
            CURRENT_DATE::VARCHAR AS registration_date_str,
            'USA' AS country,
            'Northeast' AS region,
            'New York' AS city,
            (50000 + generate_series(1, 5) * 10000)::VARCHAR AS annual_income_str;
        
        SELECT COUNT(*) INTO v_record_count FROM stg_customers WHERE load_status = 'New';
        p_records_loaded := v_record_count;
        p_status_message := 'Loaded ' || v_record_count || ' customer records into staging';
    END IF;
    
    RAISE NOTICE '%', p_status_message;
EXCEPTION
    WHEN OTHERS THEN
        p_status_message := 'Error in sp_load_staging_data: ' || SQLERRM;
        p_records_loaded := 0;
        RAISE;
END;
$$;

-- Test the procedure
CALL sp_load_staging_data('SALES', '/path/to/sales.csv');

-- ============================================================================
-- STAGE 2: TRANSFORM - DATA CLEANSING AND BUSINESS LOGIC APPLICATION
-- ============================================================================

-- ============================================================================
-- PROCEDURE: Clean and Validate Staging Data
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_transform_staging_data(
    IN p_source_type VARCHAR(50),
    OUT p_status_message VARCHAR(500),
    OUT p_records_processed INT,
    OUT p_records_errors INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql TEXT;
    v_processed_count INT := 0;
    v_error_count INT := 0;
    v_validation_errors INT := 0;
BEGIN
    p_status_message := 'Starting transformation for ' || p_source_type;
    p_records_processed := 0;
    p_records_errors := 0;
    
    IF p_source_type = 'SALES' THEN
        -- Apply data validation rules for sales data
        -- Mark records with validation errors
        UPDATE stg_sales_transactions 
        SET 
            load_status = 'Error',
            error_message = error_message || '; Invalid customer ID format',
            processed_flag = TRUE
        WHERE source_customer_id !~ '^[0-9]+$' 
          AND load_status = 'New';
        
        -- Validate product code format
        UPDATE stg_sales_transactions 
        SET 
            load_status = 'Error',
            error_message = COALESCE(error_message, '') || '; Invalid product code format',
            processed_flag = TRUE
        WHERE source_product_code !~ '^PRD[0-9]{4}$'
          AND load_status = 'New';
        
        -- Validate numeric fields
        -- Note: In a real system, you'd use a more sophisticated approach for handling conversions
        UPDATE stg_sales_transactions 
        SET 
            load_status = 'Error',
            error_message = COALESCE(error_message, '') || '; Invalid quantity format',
            processed_flag = TRUE
        WHERE quantity_sold_str !~ '^[0-9]+$' 
          AND quantity_sold_str IS NOT NULL
          AND load_status = 'New';
        
        -- Validate date format
        UPDATE stg_sales_transactions 
        SET 
            load_status = 'Error',
            error_message = COALESCE(error_message, '') || '; Invalid date format',
            processed_flag = TRUE
        WHERE transaction_date_str !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
          AND load_status = 'New';
        
        -- Update records that passed validation to Validated status
        UPDATE stg_sales_transactions 
        SET 
            load_status = 'Validated',
            load_date = CURRENT_TIMESTAMP
        WHERE load_status = 'New';
        
        -- Count results
        SELECT COUNT(*) INTO v_processed_count FROM stg_sales_transactions WHERE load_status = 'Validated';
        SELECT COUNT(*) INTO v_error_count FROM stg_sales_transactions WHERE load_status = 'Error';
        
        p_records_processed := v_processed_count;
        p_records_errors := v_error_count;
        p_status_message := 'Sales data transformation completed. Processed: ' || v_processed_count || ', Errors: ' || v_error_count;
        
    ELSIF p_source_type = 'CUSTOMERS' THEN
        -- Apply data validation rules for customer data
        UPDATE stg_customers 
        SET 
            load_status = 'Error',
            error_message = 'Invalid customer ID format',
            processed_flag = TRUE
        WHERE source_customer_id !~ '^[0-9]+$'
          AND load_status = 'New';
        
        -- Validate date format
        UPDATE stg_customers 
        SET 
            load_status = 'Error',
            error_message = COALESCE(error_message, '') || '; Invalid date of birth format',
            processed_flag = TRUE
        WHERE date_of_birth_str !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
          AND load_status = 'New';
        
        -- Update records that passed validation
        UPDATE stg_customers 
        SET 
            load_status = 'Validated',
            load_date = CURRENT_TIMESTAMP
        WHERE load_status = 'New';
        
        SELECT COUNT(*) INTO v_processed_count FROM stg_customers WHERE load_status = 'Validated';
        SELECT COUNT(*) INTO v_error_count FROM stg_customers WHERE load_status = 'Error';
        
        p_records_processed := v_processed_count;
        p_records_errors := v_error_count;
        p_status_message := 'Customer data transformation completed. Processed: ' || v_processed_count || ', Errors: ' || v_error_count;
    END IF;
    
    RAISE NOTICE '%', p_status_message;
EXCEPTION
    WHEN OTHERS THEN
        p_status_message := 'Error in sp_transform_staging_data: ' || SQLERRM;
        p_records_processed := 0;
        p_records_errors := 0;
        RAISE;
END;
$$;

-- Test the transformation procedure
CALL sp_transform_staging_data('SALES');

-- ============================================================================
-- PROCEDURE: Apply Business Logic and Calculations
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_apply_business_logic(
    IN p_source_type VARCHAR(50),
    OUT p_status_message VARCHAR(500)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql TEXT;
BEGIN
    p_status_message := 'Applying business logic for ' || p_source_type;
    
    IF p_source_type = 'SALES' THEN
        -- Apply business logic specific to sales data
        -- Update customer segment based on business rules
        -- This is a simplified version - in real system, would join and update
        
        -- Calculate derived fields in staging that will be used in the fact table
        UPDATE stg_sales_transactions
        SET 
            raw_json_data = JSON_BUILD_OBJECT(
                'processed_at', NOW(),
                'original_source', 'legacy_system',
                'business_rules_applied', TRUE
            )
        WHERE load_status = 'Validated';
        
        p_status_message := p_status_message || '. Business logic applied to validated records';
        
    ELSIF p_source_type = 'CUSTOMERS' THEN
        -- For customer data, determine loyalty status based on business rules
        -- In a real system, we'd join with sales data to determine loyalty
        
        UPDATE stg_customers
        SET 
            raw_json_data = JSON_BUILD_OBJECT(
                'processed_at', NOW(),
                'customer_segment_suggestion', 
                    CASE 
                        WHEN (annual_income_str::DECIMAL > 100000) THEN 'Premium'
                        WHEN (annual_income_str::DECIMAL > 50000) THEN 'Gold'
                        ELSE 'Silver'
                    END
            )
        WHERE load_status = 'Validated';
        
        p_status_message := p_status_message || '. Customer business logic applied';
    END IF;
    
    RAISE NOTICE '%', p_status_message;
EXCEPTION
    WHEN OTHERS THEN
        p_status_message := 'Error in sp_apply_business_logic: ' || SQLERRM;
        RAISE;
END;
$$;

-- Test the business logic procedure
CALL sp_apply_business_logic('SALES');

-- ============================================================================
-- STAGE 3: LOAD - DIMENSION AND FACT TABLE POPULATION
-- ============================================================================

-- ============================================================================
-- PROCEDURE: Upsert Customer Dimension with SCD Type 2
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_upsert_customer_dimension(
    OUT p_status_message VARCHAR(500),
    OUT p_records_inserted INT,
    OUT p_records_updated INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_inserted_count INT := 0;
    v_updated_count INT := 0;
    v_cursor CURSOR FOR
        SELECT * FROM stg_customers 
        WHERE load_status = 'Validated' 
          AND processed_flag = FALSE;
    v_record RECORD;
    v_existing_customer_id INT;
    v_customer_match_count INT;
BEGIN
    p_status_message := 'Starting customer dimension upsert with SCD Type 2';
    p_records_inserted := 0;
    p_records_updated := 0;
    
    -- Process each validated customer record
    OPEN v_cursor;
    LOOP
        FETCH v_cursor INTO v_record;
        EXIT WHEN NOT FOUND;
        
        -- Check if customer already exists in dimension (by business key)
        SELECT customer_id, COUNT(*) 
        INTO v_existing_customer_id, v_customer_match_count
        FROM dim_customer 
        WHERE customer_id = v_record.source_customer_id::INT
          AND is_active = TRUE
        GROUP BY customer_id;
        
        IF v_customer_match_count > 0 AND v_existing_customer_id IS NOT NULL THEN
            -- Customer exists, check for changes using SCD Type 2
            
            -- Get the current record to compare against
            PERFORM 1 FROM dim_customer
            WHERE customer_id = v_record.source_customer_id::INT
              AND is_active = TRUE
              AND (customer_name != v_record.customer_name 
                   OR customer_segment != v_record.customer_segment
                   OR gender != LEFT(v_record.gender, 1)
                   OR date_of_birth != v_record.date_of_birth_str::DATE
                   OR marital_status != v_record.marital_status);
            
            IF FOUND THEN
                -- Update existing to set is_active = FALSE and end_date (not implemented in our schema but conceptually)
                -- For this schema, we'll just update the record since we don't have effective dates
                UPDATE dim_customer 
                SET 
                    customer_name = v_record.customer_name,
                    customer_segment = v_record.customer_segment,
                    gender = LEFT(v_record.gender, 1),
                    date_of_birth = v_record.date_of_birth_str::DATE,
                    marital_status = v_record.marital_status,
                    updated_at = CURRENT_TIMESTAMP
                WHERE customer_id = v_record.source_customer_id::INT
                  AND is_active = TRUE;
                
                v_updated_count := v_updated_count + 1;
            END IF;
        ELSE
            -- Customer doesn't exist, insert new record
            INSERT INTO dim_customer (
                customer_id, customer_name, customer_segment, gender,
                date_of_birth, marital_status, registration_date,
                geography_key, created_at, updated_at
            )
            VALUES (
                v_record.source_customer_id::INT,
                v_record.customer_name,
                COALESCE(v_record.customer_segment, 'Unknown'),
                LEFT(COALESCE(v_record.gender, 'O'), 1),
                v_record.date_of_birth_str::DATE,
                v_record.marital_status,
                v_record.registration_date_str::DATE,
                1, -- Default geography
                CURRENT_TIMESTAMP,
                CURRENT_TIMESTAMP
            );
            
            v_inserted_count := v_inserted_count + 1;
        END IF;
        
        -- Mark staging record as processed
        UPDATE stg_customers 
        SET processed_flag = TRUE, load_status = 'Loaded'
        WHERE staging_id = v_record.staging_id;
        
    END LOOP;
    CLOSE v_cursor;
    
    p_records_inserted := v_inserted_count;
    p_records_updated := v_updated_count;
    p_status_message := 'Customer dimension upsert completed. Inserted: ' || v_inserted_count || 
                       ', Updated: ' || v_updated_count;
    
    RAISE NOTICE '%', p_status_message;
EXCEPTION
    WHEN OTHERS THEN
        p_status_message := 'Error in sp_upsert_customer_dimension: ' || SQLERRM;
        RAISE;
END;
$$;

-- Test the customer dimension upsert
CALL sp_upsert_customer_dimension();

-- ============================================================================
-- PROCEDURE: Load Fact Sales Transactions with Data Reconciliation
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_load_fact_sales_transactions(
    OUT p_status_message VARCHAR(500),
    OUT p_records_loaded INT,
    OUT p_reconciliation_status VARCHAR(100)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_loaded_count INT := 0;
    v_staging_count INT := 0;
    v_fact_count_before INT := 0;
    v_fact_count_after INT := 0;
    v_reconciliation_needed BOOLEAN := FALSE;
    v_reconciliation_result VARCHAR(100);
BEGIN
    p_status_message := 'Starting fact sales transactions load with reconciliation';
    p_records_loaded := 0;
    p_reconciliation_status := 'Not Started';
    
    -- Get initial counts for reconciliation
    SELECT COUNT(*) INTO v_fact_count_before FROM fact_sales_transactions;
    SELECT COUNT(*) INTO v_staging_count FROM stg_sales_transactions WHERE load_status = 'Validated' AND processed_flag = FALSE;
    
    -- Insert records from staging to fact table
    INSERT INTO fact_sales_transactions (
        transaction_id,
        customer_key,
        product_key,
        time_key,
        geography_key,
        transaction_date,
        transaction_time,
        transaction_type,
        order_id,
        order_item_id,
        session_id,
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
        payment_status,
        is_return,
        created_at,
        updated_at
    )
    SELECT 
        sst.source_transaction_id,
        COALESCE(
            (SELECT customer_key FROM dim_customer WHERE customer_id = sst.source_customer_id::INT LIMIT 1),
            -1  -- Unknown customer key
        ),
        COALESCE(
            (SELECT product_key FROM dim_product WHERE product_code = sst.source_product_code LIMIT 1),
            -1  -- Unknown product key
        ),
        COALESCE(
            (SELECT time_key FROM dim_time WHERE date_value = sst.transaction_date_str::DATE LIMIT 1),
            -1  -- Unknown time key
        ),
        COALESCE(
            (SELECT dc.geography_key FROM dim_customer dc WHERE dc.customer_id = sst.source_customer_id::INT LIMIT 1),
            1   -- Default geography key
        ),
        sst.transaction_date_str::DATE,
        sst.transaction_time_str::TIME,
        COALESCE(sst.transaction_type, 'Purchase'),
        sst.order_id,
        sst.order_item_id,
        sst.source_transaction_id || '_session',  -- Create session ID from transaction
        sst.quantity_sold_str::INT,
        sst.unit_price_str::DECIMAL(10,2),
        sst.unit_price_str::DECIMAL(10,2) * 0.7,  -- Calculate cost as 70% of price
        (sst.quantity_sold_str::INT * sst.unit_price_str::DECIMAL(10,2)),  -- total_revenue
        (sst.quantity_sold_str::INT * sst.unit_price_str::DECIMAL(10,2) * 0.7),  -- total_cost
        (sst.quantity_sold_str::INT * sst.unit_price_str::DECIMAL(10,2)) - 
        (sst.quantity_sold_str::INT * sst.unit_price_str::DECIMAL(10,2) * 0.7),  -- total_profit
        COALESCE(sst.discount_amount_str::DECIMAL(10,2), 0),
        COALESCE(sst.tax_amount_str::DECIMAL(10,2), 0),
        COALESCE(sst.shipping_cost_str::DECIMAL(10,2), 0),
        COALESCE(sst.customer_satisfaction_score_str::DECIMAL(3,2), 4.0),
        COALESCE(sst.review_rating_str::INT, 5),
        COALESCE(sst.delivery_status, 'Pending'),
        COALESCE(sst.payment_method, 'Unknown'),
        'Pending',
        CASE WHEN sst.transaction_type = 'Return' THEN TRUE ELSE FALSE END,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    FROM stg_sales_transactions sst
    WHERE sst.load_status = 'Validated' 
      AND sst.processed_flag = FALSE;
    
    -- Get final count
    SELECT COUNT(*) INTO v_fact_count_after FROM fact_sales_transactions;
    
    -- Calculate records loaded
    v_loaded_count := v_fact_count_after - v_fact_count_before;
    p_records_loaded := v_loaded_count;
    
    -- Perform basic reconciliation
    IF v_loaded_count = v_staging_count THEN
        p_reconciliation_status := 'Match - All records loaded';
    ELSIF v_loaded_count < v_staging_count THEN
        p_reconciliation_status := 'Gap - Some records not loaded: ' || (v_staging_count - v_loaded_count) || ' missing';
    ELSE
        p_reconciliation_status := 'Surplus - More records loaded than in staging: ' || (v_loaded_count - v_staging_count) || ' extra';
    END IF;
    
    -- Mark staging records as processed
    UPDATE stg_sales_transactions 
    SET processed_flag = TRUE, load_status = 'Loaded', load_date = CURRENT_TIMESTAMP
    WHERE load_status = 'Validated' AND processed_flag = FALSE;
    
    p_status_message := 'Fact sales transactions load completed. Expected: ' || v_staging_count || 
                       ', Loaded: ' || v_loaded_count || '. Reconciliation: ' || p_reconciliation_status;
    
    RAISE NOTICE '%', p_status_message;
EXCEPTION
    WHEN OTHERS THEN
        p_status_message := 'Error in sp_load_fact_sales_transactions: ' || SQLERRM;
        p_reconciliation_status := 'Error in Reconciliation';
        RAISE;
END;
$$;

-- Test the fact table loading
CALL sp_load_fact_sales_transactions();

-- ============================================================================
-- MAIN ETL WORKFLOW PROCEDURE
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_full_etl_workflow(
    IN p_process_date DATE DEFAULT CURRENT_DATE,
    OUT p_status_summary TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_result TEXT;
    v_error_count INT := 0;
    v_total_processes INT := 0;
    v_start_time TIMESTAMP := NOW();
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    p_status_summary := 'Starting full ETL workflow for date: ' || p_process_date || E'\n';
    
    -- Stage 1: Extract and Load into Staging Tables
    BEGIN
        v_total_processes := v_total_processes + 1;
        CALL sp_load_staging_data('SALES', '/path/to/sales.csv', v_result, NULL);
        p_status_summary := p_status_summary || 'Stage 1a - Sales staging: ' || v_result || E'\n';
    EXCEPTION
        WHEN OTHERS THEN
            v_error_count := v_error_count + 1;
            p_status_summary := p_status_summary || 'ERROR in Stage 1a: ' || SQLERRM || E'\n';
    END;
    
    BEGIN
        CALL sp_load_staging_data('CUSTOMERS', '/path/to/customers.csv', v_result, NULL);
        p_status_summary := p_status_summary || 'Stage 1b - Customers staging: ' || v_result || E'\n';
    EXCEPTION
        WHEN OTHERS THEN
            v_error_count := v_error_count + 1;
            p_status_summary := p_status_summary || 'ERROR in Stage 1b: ' || SQLERRM || E'\n';
    END;
    
    -- Stage 2: Transform and Validate
    BEGIN
        CALL sp_transform_staging_data('SALES', v_result, NULL, NULL);
        p_status_summary := p_status_summary || 'Stage 2a - Sales transformation: ' || v_result || E'\n';
    EXCEPTION
        WHEN OTHERS THEN
            v_error_count := v_error_count + 1;
            p_status_summary := p_status_summary || 'ERROR in Stage 2a: ' || SQLERRM || E'\n';
    END;
    
    BEGIN
        CALL sp_transform_staging_data('CUSTOMERS', v_result, NULL, NULL);
        p_status_summary := p_status_summary || 'Stage 2b - Customer transformation: ' || v_result || E'\n';
    EXCEPTION
        WHEN OTHERS THEN
            v_error_count := v_error_count + 1;
            p_status_summary := p_status_summary || 'ERROR in Stage 2b: ' || SQLERRM || E'\n';
    END;
    
    BEGIN
        CALL sp_apply_business_logic('SALES');
        p_status_summary := p_status_summary || 'Stage 2c - Sales business logic applied' || E'\n';
    EXCEPTION
        WHEN OTHERS THEN
            v_error_count := v_error_count + 1;
            p_status_summary := p_status_summary || 'ERROR in Stage 2c: ' || SQLERRM || E'\n';
    END;
    
    -- Stage 3: Load to Dimension and Fact Tables
    BEGIN
        CALL sp_upsert_customer_dimension(v_result, NULL, NULL);
        p_status_summary := p_status_summary || 'Stage 3a - Customer dimension load: ' || v_result || E'\n';
    EXCEPTION
        WHEN OTHERS THEN
            v_error_count := v_error_count + 1;
            p_status_summary := p_status_summary || 'ERROR in Stage 3a: ' || SQLERRM || E'\n';
    END;
    
    BEGIN
        CALL sp_load_fact_sales_transactions(v_result, NULL, v_result);
        p_status_summary := p_status_summary || 'Stage 3b - Fact sales load: ' || v_result || E'\n';
    EXCEPTION
        WHEN OTHERS THEN
            v_error_count := v_error_count + 1;
            p_status_summary := p_status_summary || 'ERROR in Stage 3b: ' || SQLERRM || E'\n';
    END;
    
    -- Calculate duration
    v_end_time := NOW();
    v_duration := v_end_time - v_start_time;
    
    -- Final summary
    p_status_summary := p_status_summary || 
                       E'\nETL Workflow Summary:' ||
                       E'\n- Total Processes: ' || v_total_processes ||
                       E'\n- Errors: ' || v_error_count ||
                       E'\n- Duration: ' || v_duration ||
                       E'\n- Status: ' || CASE WHEN v_error_count = 0 THEN 'SUCCESS' ELSE 'WITH_ERRORS' END;
    
    RAISE NOTICE '%', p_status_summary;
EXCEPTION
    WHEN OTHERS THEN
        p_status_summary := 'Critical error in ETL workflow: ' || SQLERRM;
        RAISE;
END;
$$;

-- Test the full ETL workflow
CALL sp_full_etl_workflow('2024-01-01');

-- ============================================================================
-- ETL MONITORING AND ERROR LOGGING VIEWS
-- ============================================================================

-- View for ETL job monitoring
CREATE OR REPLACE VIEW v_etl_monitoring AS
SELECT 
    'Sales Staging' AS etl_component,
    COUNT(*) AS total_records,
    COUNT(CASE WHEN load_status = 'New' THEN 1 END) AS new_records,
    COUNT(CASE WHEN load_status = 'Validated' THEN 1 END) AS validated_records,
    COUNT(CASE WHEN load_status = 'Error' THEN 1 END) AS error_records,
    COUNT(CASE WHEN load_status = 'Loaded' THEN 1 END) AS loaded_records,
    MAX(load_date) AS last_processed
FROM stg_sales_transactions

UNION ALL

SELECT 
    'Customer Staging' AS etl_component,
    COUNT(*) AS total_records,
    COUNT(CASE WHEN load_status = 'New' THEN 1 END) AS new_records,
    COUNT(CASE WHEN load_status = 'Validated' THEN 1 END) AS validated_records,
    COUNT(CASE WHEN load_status = 'Error' THEN 1 END) AS error_records,
    COUNT(CASE WHEN load_status = 'Loaded' THEN 1 END) AS loaded_records,
    MAX(load_date) AS last_processed
FROM stg_customers

UNION ALL

SELECT 
    'Web Events Staging' AS etl_component,
    COUNT(*) AS total_records,
    COUNT(CASE WHEN load_status = 'New' THEN 1 END) AS new_records,
    COUNT(CASE WHEN load_status = 'Validated' THEN 1 END) AS validated_records,
    COUNT(CASE WHEN load_status = 'Error' THEN 1 END) AS error_records,
    COUNT(CASE WHEN load_status = 'Loaded' THEN 1 END) AS loaded_records,
    MAX(load_date) AS last_processed
FROM stg_web_events;

-- View for error details
CREATE OR REPLACE VIEW v_etl_errors AS
SELECT 
    'Sales' AS source_type,
    staging_id,
    source_transaction_id AS source_key,
    error_message,
    load_date,
    load_status
FROM stg_sales_transactions
WHERE load_status = 'Error'

UNION ALL

SELECT 
    'Customer' AS source_type,
    staging_id,
    source_customer_id AS source_key,
    error_message,
    load_date,
    load_status
FROM stg_customers
WHERE load_status = 'Error'

UNION ALL

SELECT 
    'Web Events' AS source_type,
    staging_id,
    source_event_id AS source_key,
    error_message,
    load_date,
    load_status
FROM stg_web_events
WHERE load_status = 'Error';

-- Show ETL monitoring results
SELECT * FROM v_etl_monitoring;
SELECT * FROM v_etl_errors LIMIT 10;