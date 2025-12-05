-- ============================================================================
-- E-COMMERCE ANALYTICS & CUSTOMER INTELLIGENCE PLATFORM
-- SAMPLE DATA GENERATION SCRIPTS
-- For LLM Training Data Portfolio Project
-- Author: SQL Developer Portfolio
-- Date: 2025-01-04
-- Description: Scripts to generate realistic test data for all tables
-- ============================================================================

-- ============================================================================
-- GENERATE TIME DIMENSION DATA (Supporting 3 years of data)
-- ============================================================================

-- Generate dates for 3 years (2023-2025)
WITH RECURSIVE date_series AS (
    SELECT '2023-01-01'::DATE AS date_val
    UNION ALL
    SELECT date_val + INTERVAL '1 day'
    FROM date_series
    WHERE date_val < '2025-12-31'
),
time_dimension_data AS (
    SELECT 
        ROW_NUMBER() OVER (ORDER BY date_val) AS time_key,
        date_val AS date_value,
        TO_CHAR(date_val, 'FMMonth FMDD, YYYY') AS full_date_description,
        EXTRACT(DOW FROM date_val) AS day_number_in_week, -- 0=Sunday, 1=Monday, etc.
        TO_CHAR(date_val, 'Day') AS day_name_of_week,
        EXTRACT(DAY FROM date_val) AS day_number_in_month,
        EXTRACT(DOY FROM date_val) AS day_number_in_year,
        EXTRACT(WEEK FROM date_val) AS calendar_week_number_in_year,
        EXTRACT(MONTH FROM date_val) AS calendar_month_number_in_year,
        TO_CHAR(date_val, 'Month') AS calendar_month_name,
        EXTRACT(YEAR FROM date_val) AS calendar_year,
        CASE 
            WHEN EXTRACT(MONTH FROM date_val) <= 6 THEN 'H1'
            ELSE 'H2'
        END AS calendar_half_year,
        CASE 
            WHEN EXTRACT(MONTH FROM date_val) <= 3 THEN 'Q1'
            WHEN EXTRACT(MONTH FROM date_val) <= 6 THEN 'Q2'
            WHEN EXTRACT(MONTH FROM date_val) <= 9 THEN 'Q3'
            ELSE 'Q4'
        END AS calendar_quarter,
        -- Assuming fiscal year starts in July
        CASE 
            WHEN EXTRACT(MONTH FROM date_val) >= 7 THEN EXTRACT(YEAR FROM date_val) + 1
            ELSE EXTRACT(YEAR FROM date_val)
        END AS fiscal_year,
        CASE 
            WHEN EXTRACT(MONTH FROM date_val) BETWEEN 7 AND 12 THEN 'FH1'
            ELSE 'FH2'
        END AS fiscal_half_year,
        CASE 
            WHEN EXTRACT(MONTH FROM date_val) BETWEEN 7 AND 9 THEN 'FQ1'
            WHEN EXTRACT(MONTH FROM date_val) BETWEEN 10 AND 12 THEN 'FQ2'
            WHEN EXTRACT(MONTH FROM date_val) BETWEEN 1 AND 3 THEN 'FQ3'
            ELSE 'FQ4'
        END AS fiscal_quarter,
        CASE 
            WHEN date_val IN ('2023-01-01', '2023-07-04', '2023-12-25', -- Add more holidays as needed
                             '2024-01-01', '2024-07-04', '2024-12-25',
                             '2025-01-01', '2025-07-04', '2025-12-25') 
            THEN TRUE 
            ELSE FALSE 
        END AS holiday_flag,
        CASE 
            WHEN EXTRACT(DOW FROM date_val) IN (0, 6) THEN TRUE 
            ELSE FALSE 
        END AS weekend_flag,
        (EXTRACT(DAY FROM date_val) - 1) / 7 + 1 AS day_of_week_in_month,
        (EXTRACT(DOY FROM date_val) - 1) / 7 + 1 AS day_of_week_in_year,
        EXTRACT(DOY FROM date_val) AS day_of_year,
        date_val + (6 - EXTRACT(DOW FROM date_val))::INTEGER * INTERVAL '1 day' AS week_ending_date,
        (date_val + INTERVAL '1 month' - INTERVAL '1 day')::DATE AS month_ending_date,
        CASE 
            WHEN EXTRACT(QUARTER FROM date_val) = 1 THEN (date_val + INTERVAL '3 months' - INTERVAL '1 day')::DATE
            WHEN EXTRACT(QUARTER FROM date_val) = 2 THEN (date_val + INTERVAL '3 months' - INTERVAL '1 day')::DATE
            WHEN EXTRACT(QUARTER FROM date_val) = 3 THEN (date_val + INTERVAL '3 months' - INTERVAL '1 day')::DATE
            ELSE (date_val + INTERVAL '3 months' - INTERVAL '1 day')::DATE
        END AS quarter_ending_date,
        (date_val + INTERVAL '1 year' - INTERVAL '1 day')::DATE AS year_ending_date
    FROM date_series
)
INSERT INTO dim_time (
    time_key, date_value, full_date_description, day_number_in_week, 
    day_name_of_week, day_number_in_month, day_number_in_year, 
    calendar_week_number_in_year, calendar_month_number_in_year, 
    calendar_month_name, calendar_year, calendar_half_year, calendar_quarter,
    fiscal_year, fiscal_half_year, fiscal_quarter, 
    holiday_flag, weekend_flag, day_of_week_in_month, 
    day_of_week_in_year, day_of_year, week_ending_date, 
    month_ending_date, quarter_ending_date, year_ending_date
)
SELECT 
    time_key, date_value, full_date_description, day_number_in_week, 
    TRIM(day_name_of_week), day_number_in_month, day_number_in_year, 
    calendar_week_number_in_year, calendar_month_number_in_year, 
    TRIM(calendar_month_name), calendar_year, calendar_half_year, calendar_quarter,
    fiscal_year, fiscal_half_year, fiscal_quarter, 
    holiday_flag, weekend_flag, day_of_week_in_month, 
    day_of_week_in_year, day_of_year, week_ending_date, 
    month_ending_date, quarter_ending_date, year_ending_date
FROM time_dimension_data;

-- ============================================================================
-- GENERATE GEOGRAPHY DIMENSION DATA
-- ============================================================================

INSERT INTO dim_geography (
    geography_key, country_code, country_name, region_code, region_name,
    state_province_code, state_province_name, city_name, postal_code,
    latitude, longitude, timezone, country_code_iso2, continent_code,
    continent_name, market_classification
) VALUES 
(1, 'USA001', 'United States of America', 'US-EAST', 'Northeast',
 'NY', 'New York', 'New York City', '10001',
 40.7128, -74.0060, 'America/New_York', 'US', 'NA',
 'North America', 'Premium'),
(2, 'USA002', 'United States of America', 'US-WEST', 'West Coast',
 'CA', 'California', 'Los Angeles', '90001',
 34.0522, -118.2437, 'America/Los_Angeles', 'US', 'NA',
 'North America', 'Premium'),
(3, 'CAN001', 'Canada', 'CA-ONT', 'Ontario',
 'ON', 'Ontario', 'Toronto', 'M4W',
 43.6532, -79.3832, 'America/Toronto', 'CA', 'NA',
 'North America', 'Standard'),
(4, 'GBR001', 'United Kingdom', 'GB-LON', 'London',
 'ENG', 'England', 'London', 'SW1',
 51.5074, -0.1278, 'Europe/London', 'GB', 'EU',
 'Europe', 'Premium'),
(5, 'AUS001', 'Australia', 'AUS-NSW', 'New South Wales',
 'NSW', 'New South Wales', 'Sydney', '2000',
 -33.8688, 151.2093, 'Australia/Sydney', 'AU', 'OC',
 'Oceania', 'Standard'),
(6, 'IND001', 'India', 'IND-MH', 'Maharashtra',
 'MH', 'Maharashtra', 'Mumbai', '400001',
 19.0760, 72.8777, 'Asia/Kolkata', 'IN', 'AS',
 'Asia', 'Economy'),
(7, 'BRA001', 'Brazil', 'BRA-SP', 'São Paulo',
 'SP', 'São Paulo', 'São Paulo', '01000-000',
 -23.5505, -46.6333, 'America/Sao_Paulo', 'BR', 'SA',
 'South America', 'Standard'),
(8, 'ZAF001', 'South Africa', 'ZAF-GT', 'Gauteng',
 'GT', 'Gauteng', 'Johannesburg', '2000',
 -26.2041, 28.0473, 'Africa/Johannesburg', 'ZA', 'AF',
 'Africa', 'Economy'),
(9, 'SGP001', 'Singapore', 'SGP-CEN', 'Central',
 'SGP', 'Singapore', 'Singapore', '018983',
 1.3521, 103.8198, 'Asia/Singapore', 'SG', 'AS',
 'Asia', 'Premium'),
(10, 'JPN001', 'Japan', 'JPN-TYO', 'Tokyo',
 '13', 'Tokyo', 'Tokyo', '100-0000',
 35.6762, 139.6503, 'Asia/Tokyo', 'JP', 'AS',
 'Asia', 'Premium');

-- ============================================================================
-- GENERATE CUSTOMER DATA
-- ============================================================================

INSERT INTO dim_customer (
    customer_key, customer_id, customer_name, customer_segment,
    gender, date_of_birth, age_group, marital_status, education_level,
    occupation, annual_income, loyalty_member, loyalty_tier,
    registration_date, registration_channel, last_activity_date,
    total_lifetime_value, total_orders_count, average_order_value,
    preferred_communication_channel, preferred_store_location,
    marketing_opt_in, geography_key
)
SELECT
    generate_series(1, 1000) AS customer_key,
    generate_series(1001, 2000) AS customer_id,
    'Customer ' || generate_series(1, 1000) AS customer_name,
    CASE 
        WHEN generate_series(1, 1000) <= 100 THEN 'Premium'
        WHEN generate_series(1, 1000) <= 300 THEN 'Gold'
        WHEN generate_series(1, 1000) <= 600 THEN 'Silver'
        ELSE 'Bronze'
    END AS customer_segment,
    CASE (generate_series(1, 1000) % 3)
        WHEN 0 THEN 'M'
        WHEN 1 THEN 'F'
        ELSE 'O'
    END AS gender,
    ('2023-01-01'::DATE - (generate_series(1, 1000) % 50 + 20) * 365) AS date_of_birth,
    CASE 
        WHEN (generate_series(1, 1000) % 100) < 15 THEN 'Under 18'
        WHEN (generate_series(1, 1000) % 100) < 25 THEN '18-25'
        WHEN (generate_series(1, 1000) % 100) < 35 THEN '26-35'
        WHEN (generate_series(1, 1000) % 100) < 50 THEN '36-50'
        WHEN (generate_series(1, 1000) % 100) < 65 THEN '51-65'
        ELSE 'Over 65'
    END AS age_group,
    CASE (generate_series(1, 1000) % 4)
        WHEN 0 THEN 'Single'
        WHEN 1 THEN 'Married'
        WHEN 2 THEN 'Divorced'
        ELSE 'Widowed'
    END AS marital_status,
    CASE (generate_series(1, 1000) % 4)
        WHEN 0 THEN 'High School'
        WHEN 1 THEN 'Bachelor'
        WHEN 2 THEN 'Master'
        ELSE 'PhD'
    END AS education_level,
    CASE (generate_series(1, 1000) % 10)
        WHEN 0 THEN 'Engineer'
        WHEN 1 THEN 'Teacher'
        WHEN 2 THEN 'Doctor'
        WHEN 3 THEN 'Lawyer'
        WHEN 4 THEN 'Designer'
        WHEN 5 THEN 'Manager'
        WHEN 6 THEN 'Consultant'
        WHEN 7 THEN 'Developer'
        WHEN 8 THEN 'Analyst'
        ELSE 'Executive'
    END AS occupation,
    (generate_series(1, 1000) % 100 + 20) * 2000 AS annual_income,
    CASE 
        WHEN (generate_series(1, 1000) % 10) < 8 THEN TRUE 
        ELSE FALSE 
    END AS loyalty_member,
    CASE 
        WHEN generate_series(1, 1000) <= 100 THEN 'Platinum'
        WHEN generate_series(1, 1000) <= 300 THEN 'Gold'
        WHEN generate_series(1, 1000) <= 600 THEN 'Silver'
        ELSE 'Basic'
    END AS loyalty_tier,
    ('2023-01-01'::DATE + (generate_series(1, 1000) % 1095)) AS registration_date,
    CASE (generate_series(1, 1000) % 3)
        WHEN 0 THEN 'Web'
        WHEN 1 THEN 'Email'
        ELSE 'Store'
    END AS registration_channel,
    ('2024-01-01'::DATE + (generate_series(1, 1000) % 365)) AS last_activity_date,
    (generate_series(1, 1000) % 5000 + 100) AS total_lifetime_value,
    (generate_series(1, 1000) % 50 + 1) AS total_orders_count,
    (generate_series(1, 1000) % 500 + 50) AS average_order_value,
    CASE (generate_series(1, 1000) % 3)
        WHEN 0 THEN 'Email'
        WHEN 1 THEN 'SMS'
        ELSE 'Phone'
    END AS preferred_communication_channel,
    CASE (generate_series(1, 1000) % 5)
        WHEN 0 THEN 'Downtown'
        WHEN 1 THEN 'Mall'
        WHEN 2 THEN 'Airport'
        WHEN 3 THEN 'Online'
        ELSE 'Suburban'
    END AS preferred_store_location,
    CASE 
        WHEN (generate_series(1, 1000) % 10) < 7 THEN TRUE 
        ELSE FALSE 
    END AS marketing_opt_in,
    ((generate_series(1, 1000) - 1) % 10) + 1 AS geography_key;

-- ============================================================================
-- GENERATE PRODUCT DATA
-- ============================================================================

INSERT INTO dim_product (
    product_key, product_id, product_name, product_code,
    product_category, product_subcategory, product_brand,
    product_line, product_size, product_color, product_material,
    base_price, cost_price, product_status, product_description,
    supplier_id, supplier_name, weight_class, category_ranking
)
SELECT
    generate_series(1, 500) AS product_key,
    generate_series(5001, 5500) AS product_id,
    CASE (generate_series(1, 500) % 10)
        WHEN 0 THEN 'Smartphone'
        WHEN 1 THEN 'Laptop'
        WHEN 2 THEN 'Tablet'
        WHEN 3 THEN 'Headphones'
        WHEN 4 THEN 'Smart Watch'
        WHEN 5 THEN 'Wireless Earbuds'
        WHEN 6 THEN 'Gaming Console'
        WHEN 7 THEN 'Camera'
        WHEN 8 THEN 'TV'
        ELSE 'Speaker'
    END AS product_name,
    'PRD' || LPAD(generate_series(1, 500)::TEXT, 4, '0') AS product_code,
    CASE (generate_series(1, 500) % 5)
        WHEN 0 THEN 'Electronics'
        WHEN 1 THEN 'Computers'
        WHEN 2 THEN 'Audio'
        WHEN 3 THEN 'Wearables'
        ELSE 'Entertainment'
    END AS product_category,
    CASE (generate_series(1, 500) % 4)
        WHEN 0 THEN 'Mobile Devices'
        WHEN 1 THEN 'Desktops'
        WHEN 2 THEN 'Accessories'
        ELSE 'Gaming'
    END AS product_subcategory,
    CASE (generate_series(1, 500) % 8)
        WHEN 0 THEN 'TechBrand'
        WHEN 1 THEN 'GlobalTech'
        WHEN 2 THEN 'InnovateInc'
        WHEN 3 THEN 'Digitron'
        WHEN 4 THEN 'GigaCorp'
        WHEN 5 THEN 'NexusTech'
        WHEN 6 THEN 'Quantum'
        ELSE 'ElectroMax'
    END AS product_brand,
    CASE (generate_series(1, 500) % 4)
        WHEN 0 THEN 'Premium'
        WHEN 1 THEN 'Standard'
        WHEN 2 THEN 'Budget'
        ELSE 'Deluxe'
    END AS product_line,
    CASE (generate_series(1, 500) % 3)
        WHEN 0 THEN 'Small'
        WHEN 1 THEN 'Medium'
        ELSE 'Large'
    END AS product_size,
    CASE (generate_series(1, 500) % 8)
        WHEN 0 THEN 'Black'
        WHEN 1 THEN 'White'
        WHEN 2 THEN 'Silver'
        WHEN 3 THEN 'Blue'
        WHEN 4 THEN 'Red'
        WHEN 5 THEN 'Gold'
        WHEN 6 THEN 'Green'
        ELSE 'Purple'
    END AS product_color,
    CASE (generate_series(1, 500) % 5)
        WHEN 0 THEN 'Aluminum'
        WHEN 1 THEN 'Plastic'
        WHEN 2 THEN 'Metal'
        WHEN 3 THEN 'Silicon'
        ELSE 'Composite'
    END AS product_material,
    (generate_series(1, 500) % 2000 + 50) AS base_price,
    (generate_series(1, 500) % 1500 + 30) AS cost_price,
    'Active' AS product_status,
    'High quality product in ' || 
    CASE (generate_series(1, 500) % 5)
        WHEN 0 THEN 'Electronics'
        WHEN 1 THEN 'Computers'
        WHEN 2 THEN 'Audio'
        WHEN 3 THEN 'Wearables'
        ELSE 'Entertainment'
    END AS product_description,
    (generate_series(1, 500) % 50) + 1 AS supplier_id,
    'Supplier ' || ((generate_series(1, 500) % 50) + 1) AS supplier_name,
    CASE 
        WHEN (generate_series(1, 500) % 100) < 30 THEN 'Light'
        WHEN (generate_series(1, 500) % 100) < 70 THEN 'Medium'
        ELSE 'Heavy'
    END AS weight_class,
    generate_series(1, 500) % 100 AS category_ranking;

-- ============================================================================
-- GENERATE MARKETING CHANNEL DATA
-- ============================================================================

INSERT INTO dim_marketing_channel (
    marketing_channel_key, channel_id, channel_name, channel_type,
    channel_category, attribution_model, campaign_type, cost_per_click,
    channel_status, marketing_region, marketing_budget, target_audience
)
VALUES 
(1, 101, 'Google Ads - Search', 'Paid', 'Acquisition', 'Last Click', 'Awareness', 2.50, 'Active', 'Global', 50000.00, 'All Demographics'),
(2, 102, 'Google Ads - Display', 'Paid', 'Retention', 'First Click', 'Consideration', 1.20, 'Active', 'North America', 30000.00, 'Young Professionals'),
(3, 103, 'Facebook Ads', 'Paid', 'Acquisition', 'Linear', 'Conversion', 3.10, 'Active', 'Global', 40000.00, 'All Demographics'),
(4, 104, 'Instagram Ads', 'Paid', 'Acquisition', 'Time Decay', 'Awareness', 2.80, 'Active', 'Global', 35000.00, 'Young Adults'),
(5, 105, 'Email Marketing', 'Direct', 'Retention', 'Last Click', 'Retention', 0.10, 'Active', 'Global', 10000.00, 'Existing Customers'),
(6, 106, 'Organic Search', 'Organic', 'Acquisition', 'Last Click', 'Awareness', 0.00, 'Active', 'Global', 0.00, 'All Demographics'),
(7, 107, 'Affiliate Marketing', 'Affiliates', 'Acquisition', 'Last Click', 'Conversion', 4.50, 'Active', 'Global', 25000.00, 'Price Sensitive'),
(8, 108, 'Influencer Marketing', 'Social', 'Acquisition', 'Last Click', 'Awareness', 5.00, 'Active', 'Global', 20000.00, 'Young Adults'),
(9, 109, 'TV Advertising', 'Traditional', 'Awareness', 'Last Click', 'Awareness', 10.00, 'Active', 'North America', 100000.00, 'All Demographics'),
(10, 110, 'Direct Traffic', 'Direct', 'Acquisition', 'Last Click', 'Retention', 0.00, 'Active', 'Global', 0.00, 'All Demographics');

-- ============================================================================
-- GENERATE SALES TRANSACTION DATA
-- ============================================================================

-- Create a temporary table to store sales transactions
CREATE TEMP TABLE temp_sales_data AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY random()) AS sales_transaction_key,
    'TXN' || LPAD((ROW_NUMBER() OVER (ORDER BY random()))::TEXT, 8, '0') AS transaction_id,
    ((random() * 999)::INT + 1) AS customer_key,
    ((random() * 499)::INT + 1) AS product_key,
    ((random() * 1095)::INT + 1) AS time_key, -- 3 years of data
    ((random() * 9)::INT + 1) AS geography_key,
    ((random() * 9)::INT + 1) AS marketing_channel_key,
    ('2023-01-01'::DATE + (random() * 1095)::INT) AS transaction_date,
    ('08:00:00'::TIME + (random() * 57600)::INT * INTERVAL '1 second') AS transaction_time, -- 8AM to 10PM
    CASE (random() * 3)::INT
        WHEN 0 THEN 'Purchase'
        WHEN 1 THEN 'Return'
        ELSE 'Refund'
    END AS transaction_type,
    'ORD' || LPAD(((ROW_NUMBER() OVER (ORDER BY random())) % 5000 + 1)::TEXT, 6, '0') AS order_id,
    'ORD' || LPAD(((ROW_NUMBER() OVER (ORDER BY random())) % 5000 + 1)::TEXT, 6, '0') || '-1' AS order_item_id,
    'SES' || LPAD(((ROW_NUMBER() OVER (ORDER BY random())) % 2000 + 1)::TEXT, 8, '0') AS session_id,
    (random() * 5 + 1)::INT AS quantity_sold,
    (random() * 1000 + 10)::DECIMAL(10,2) AS unit_price,
    (random() * 800 + 5)::DECIMAL(10,2) AS unit_cost,
    NULL AS total_revenue,
    NULL AS total_cost,
    NULL AS total_profit,
    (random() * 50)::DECIMAL(10,2) AS discount_amount,
    (random() * 20)::DECIMAL(10,2) AS tax_amount,
    (random() * 15)::DECIMAL(10,2) AS shipping_cost
FROM generate_series(1, 10000); -- Generate 10,000 sales transactions

-- Update computed financial values
UPDATE temp_sales_data SET 
    total_revenue = quantity_sold * unit_price,
    total_cost = quantity_sold * unit_cost,
    total_profit = (quantity_sold * unit_price) - (quantity_sold * unit_cost);

-- Insert into the actual fact table
INSERT INTO fact_sales_transactions (
    sales_transaction_key, transaction_id, customer_key, product_key,
    time_key, geography_key, marketing_channel_key, transaction_date,
    transaction_time, transaction_type, order_id, order_item_id,
    session_id, quantity_sold, unit_price, unit_cost, total_revenue,
    total_cost, total_profit, discount_amount, tax_amount,
    shipping_cost, gross_margin, customer_satisfaction_score,
    review_rating, order_processing_time_minutes, shipping_time_days,
    delivery_status, payment_method, payment_status, is_return,
    is_express_delivery, is_gift, is_first_time_purchase, created_at
)
SELECT
    sales_transaction_key, transaction_id, customer_key, product_key,
    time_key, geography_key, marketing_channel_key, transaction_date,
    transaction_time, transaction_type, order_id, order_item_id,
    session_id, quantity_sold, unit_price, unit_cost, total_revenue,
    total_cost, total_profit, discount_amount, tax_amount,
    shipping_cost,
    CASE 
        WHEN total_revenue > 0 THEN (total_profit / total_revenue) * 100
        ELSE 0
    END AS gross_margin,
    (random() * 4 + 1)::DECIMAL(3,2) AS customer_satisfaction_score,
    (random() * 4 + 1)::INT AS review_rating,
    (random() * 120 + 5)::INT AS order_processing_time_minutes,
    (random() * 14 + 2)::INT AS shipping_time_days,
    CASE (random() * 4)::INT
        WHEN 0 THEN 'Delivered'
        WHEN 1 THEN 'Shipped'
        WHEN 2 THEN 'Pending'
        ELSE 'Cancelled'
    END AS delivery_status,
    CASE (random() * 4)::INT
        WHEN 0 THEN 'Credit Card'
        WHEN 1 THEN 'Debit Card'
        WHEN 2 THEN 'PayPal'
        ELSE 'Bank Transfer'
    END AS payment_method,
    CASE (random() * 3)::INT
        WHEN 0 THEN 'Paid'
        WHEN 1 THEN 'Pending'
        ELSE 'Failed'
    END AS payment_status,
    CASE 
        WHEN transaction_type = 'Return' OR transaction_type = 'Refund' THEN TRUE
        ELSE FALSE
    END AS is_return,
    CASE 
        WHEN (random() * 10)::INT < 2 THEN TRUE
        ELSE FALSE
    END AS is_express_delivery,
    CASE 
        WHEN (random() * 10)::INT < 1 THEN TRUE
        ELSE FALSE
    END AS is_gift,
    CASE 
        WHEN (random() * 10)::INT < 3 THEN TRUE
        ELSE FALSE
    END AS is_first_time_purchase,
    NOW() AS created_at
FROM temp_sales_data;

-- Clean up temporary table
DROP TABLE temp_sales_data;

-- ============================================================================
-- GENERATE WEB EVENTS DATA
-- ============================================================================

-- Create a temporary table for web events
CREATE TEMP TABLE temp_web_events AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY random()) AS web_event_key,
    (random() * 999 + 1)::INT AS customer_key,
    (random() * 1095 + 1)::INT AS time_key,
    (random() * 499 + 1)::INT AS product_key,
    (random() * 9 + 1)::INT AS marketing_channel_key,
    ('2023-01-01'::DATE + (random() * 1095)::INT) AS event_date,
    ('00:00:00'::TIME + (random() * 86400)::INT * INTERVAL '1 second') AS event_time,
    CASE (random() * 8)::INT
        WHEN 0 THEN 'page_view'
        WHEN 1 THEN 'add_to_cart'
        WHEN 2 THEN 'checkout_start'
        WHEN 3 THEN 'purchase'
        WHEN 4 THEN 'product_search'
        WHEN 5 THEN 'wishlist_add'
        WHEN 6 THEN 'review_submit'
        ELSE 'form_submit'
    END AS event_type,
    CASE (random() * 5)::INT
        WHEN 0 THEN '/home'
        WHEN 1 THEN '/products'
        WHEN 2 THEN '/cart'
        WHEN 3 THEN '/checkout'
        ELSE '/account'
    END AS page_url,
    CASE (random() * 5)::INT
        WHEN 0 THEN 'Home Page'
        WHEN 1 THEN 'Product Listing'
        WHEN 2 THEN 'Shopping Cart'
        WHEN 3 THEN 'Checkout'
        ELSE 'Account'
    END AS page_title,
    CASE (random() * 3)::INT
        WHEN 0 THEN 'https://google.com'
        WHEN 1 THEN 'https://facebook.com'
        ELSE 'https://direct.com'
    END AS referrer_url,
    CASE (random() * 3)::INT
        WHEN 0 THEN 'google'
        WHEN 1 THEN 'facebook'
        ELSE 'direct'
    END AS utm_source,
    CASE (random() * 3)::INT
        WHEN 0 THEN 'cpc'
        WHEN 1 THEN 'social'
        ELSE 'direct'
    END AS utm_medium,
    'campaign_' || (random() * 100)::INT AS utm_campaign,
    'SES' || LPAD(((ROW_NUMBER() OVER (ORDER BY random())) % 2000 + 1)::TEXT, 8, '0') AS session_id,
    CASE (random() * 3)::INT
        WHEN 0 THEN 'Desktop'
        WHEN 1 THEN 'Mobile'
        ELSE 'Tablet'
    END AS device_type,
    CASE (random() * 4)::INT
        WHEN 0 THEN 'Chrome'
        WHEN 1 THEN 'Safari'
        WHEN 2 THEN 'Firefox'
        ELSE 'Edge'
    END AS browser_name,
    CASE (random() * 4)::INT
        WHEN 0 THEN 'Windows'
        WHEN 1 THEN 'iOS'
        WHEN 2 THEN 'Android'
        ELSE 'macOS'
    END AS operating_system,
    (random() * 300)::INT AS page_view_duration_seconds,
    (random() * 100)::INT AS session_duration_seconds
FROM generate_series(1, 50000); -- Generate 50,000 web events

-- Insert into the actual fact table
INSERT INTO fact_web_events (
    web_event_key, customer_key, time_key, product_key,
    marketing_channel_key, session_id, user_id, event_date,
    event_time, event_type, page_url, page_title, referrer_url,
    utm_source, utm_medium, utm_campaign, device_type, browser_name,
    operating_system, page_view_duration_seconds, session_duration_seconds,
    created_at
)
SELECT
    web_event_key, customer_key, time_key, product_key,
    marketing_channel_key, session_id, 
    'USR' || LPAD(customer_key::TEXT, 6, '0') AS user_id, event_date,
    event_time, event_type, page_url, page_title, referrer_url,
    utm_source, utm_medium, utm_campaign, device_type, browser_name,
    operating_system, page_view_duration_seconds, session_duration_seconds,
    NOW() AS created_at
FROM temp_web_events;

-- Clean up temporary table
DROP TABLE temp_web_events;

-- ============================================================================
-- GENERATE CUSTOMER INTERACTIONS DATA
-- ============================================================================

-- Create a temporary table for customer interactions
CREATE TEMP TABLE temp_customer_interactions AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY random()) AS interaction_key,
    (random() * 999 + 1)::INT AS customer_key,
    (random() * 1095 + 1)::INT AS time_key,
    (random() * 499 + 1)::INT AS product_key,
    (random() * 9 + 1)::INT AS marketing_channel_key,
    ('2023-01-01'::DATE + (random() * 1095)::INT) AS interaction_date,
    ('09:00:00'::TIME + (random() * 28800)::INT * INTERVAL '1 second') AS interaction_time, -- 9AM to 5PM
    CASE (random() * 5)::INT
        WHEN 0 THEN 'Phone'
        WHEN 1 THEN 'Email'
        WHEN 2 THEN 'Chat'
        WHEN 3 THEN 'Social Media'
        ELSE 'In-Store'
    END AS interaction_channel,
    CASE (random() * 5)::INT
        WHEN 0 THEN 'Support'
        WHEN 1 THEN 'Sales'
        WHEN 2 THEN 'Inquiry'
        WHEN 3 THEN 'Complaint'
        ELSE 'Feedback'
    END AS interaction_type,
    CASE (random() * 3)::INT
        WHEN 0 THEN 'Product Inquiry'
        WHEN 1 THEN 'Order Status'
        ELSE 'Technical Support'
    END AS interaction_purpose,
    CASE (random() * 4)::INT
        WHEN 0 THEN 'Open'
        WHEN 1 THEN 'In Progress'
        WHEN 2 THEN 'Resolved'
        ELSE 'Closed'
    END AS interaction_status,
    CASE (random() * 4)::INT
        WHEN 0 THEN 'Low'
        WHEN 1 THEN 'Medium'
        ELSE 'High'
    END AS priority_level,
    (random() * 30)::INT AS first_response_time_minutes,
    (random() * 360)::INT AS resolution_time_minutes,
    (random() * 4 + 1)::DECIMAL(3,2) AS satisfaction_score,
    CASE (random() * 4)::INT
        WHEN 0 THEN 'Resolved'
        WHEN 1 THEN 'Escalated'
        WHEN 2 THEN 'Pending'
        ELSE 'Unresolved'
    END AS resolution_status,
    'Interaction regarding ' || 
    CASE (random() * 3)::INT
        WHEN 0 THEN 'Order Status'
        WHEN 1 THEN 'Product Feature'
        ELSE 'Billing Question'
    END AS interaction_subject,
    CASE (random() * 3)::INT
        WHEN 0 THEN 'Customer called to inquire about order status. Provided tracking information. Issue resolved.'
        WHEN 1 THEN 'Customer reported issue with product. Troubleshooting steps provided. Issue resolved.'
        ELSE 'Customer provided feedback on shopping experience. Thanked for input.'
    END AS interaction_details
FROM generate_series(1, 5000); -- Generate 5,000 customer interactions

-- Insert into the actual fact table
INSERT INTO fact_customer_interactions (
    interaction_key, customer_key, time_key, product_key,
    marketing_channel_key, interaction_date, interaction_time,
    interaction_channel, interaction_type, interaction_purpose,
    interaction_status, priority_level, first_response_time_minutes,
    resolution_time_minutes, satisfaction_score, resolution_status,
    interaction_subject, interaction_details, agent_id, agent_name,
    department, revenue_impact, sentiment_score, created_at
)
SELECT
    interaction_key, customer_key, time_key, product_key,
    marketing_channel_key, interaction_date, interaction_time,
    interaction_channel, interaction_type, interaction_purpose,
    interaction_status, priority_level, first_response_time_minutes,
    resolution_time_minutes, satisfaction_score, resolution_status,
    interaction_subject, interaction_details,
    'AGT' || LPAD(((interaction_key % 50) + 1)::TEXT, 4, '0') AS agent_id,
    'Agent ' || ((interaction_key % 50) + 1) AS agent_name,
    CASE (random() * 3)::INT
        WHEN 0 THEN 'Support'
        WHEN 1 THEN 'Sales'
        ELSE 'Technical'
    END AS department,
    (random() * 100 - 50)::DECIMAL(12,2) AS revenue_impact, -- Can be positive or negative
    (random() * 2 - 1)::DECIMAL(3,2) AS sentiment_score, -- From -1 to +1
    NOW() AS created_at
FROM temp_customer_interactions;

-- Clean up temporary table
DROP TABLE temp_customer_interactions;

-- ============================================================================
-- UPDATE CUSTOMER DIMENSION WITH AGGREGATED METRICS
-- ============================================================================

-- Update customer dimension with calculated metrics based on sales data
UPDATE dim_customer 
SET 
    total_orders_count = (
        SELECT COUNT(*)
        FROM fact_sales_transactions fst
        WHERE fst.customer_key = dim_customer.customer_key
    ),
    total_lifetime_value = (
        SELECT COALESCE(SUM(total_revenue), 0)
        FROM fact_sales_transactions fst
        WHERE fst.customer_key = dim_customer.customer_key
    ),
    average_order_value = (
        SELECT COALESCE(AVG(total_revenue), 0)
        FROM fact_sales_transactions fst
        WHERE fst.customer_key = dim_customer.customer_key
    ),
    last_activity_date = (
        SELECT COALESCE(MAX(transaction_date), registration_date)
        FROM fact_sales_transactions fst
        WHERE fst.customer_key = dim_customer.customer_key
    );

-- ============================================================================
-- VALIDATION QUERIES - VERIFY DATA GENERATION
-- ============================================================================

-- Check record counts
SELECT 'dim_time' AS table_name, COUNT(*) AS record_count FROM dim_time
UNION ALL
SELECT 'dim_geography' AS table_name, COUNT(*) AS record_count FROM dim_geography
UNION ALL
SELECT 'dim_customer' AS table_name, COUNT(*) AS record_count FROM dim_customer
UNION ALL
SELECT 'dim_product' AS table_name, COUNT(*) AS record_count FROM dim_product
UNION ALL
SELECT 'dim_marketing_channel' AS table_name, COUNT(*) AS record_count FROM dim_marketing_channel
UNION ALL
SELECT 'fact_sales_transactions' AS table_name, COUNT(*) AS record_count FROM fact_sales_transactions
UNION ALL
SELECT 'fact_web_events' AS table_name, COUNT(*) AS record_count FROM fact_web_events
UNION ALL
SELECT 'fact_customer_interactions' AS table_name, COUNT(*) AS record_count FROM fact_customer_interactions
ORDER BY table_name;

-- Sample validation queries
SELECT 'Sales transaction sample:' AS info;
SELECT transaction_id, customer_key, product_key, transaction_date, total_revenue 
FROM fact_sales_transactions LIMIT 5;

SELECT 'Web event sample:' AS info;
SELECT event_type, page_url, device_type, event_date
FROM fact_web_events LIMIT 5;

SELECT 'Customer interaction sample:' AS info;
SELECT interaction_type, interaction_channel, satisfaction_score
FROM fact_customer_interactions LIMIT 5;