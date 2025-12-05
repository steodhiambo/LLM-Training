-- ============================================================================
-- E-COMMERCE ANALYTICS & CUSTOMER INTELLIGENCE PLATFORM
-- DATABASE SCHEMA DDL SCRIPTS
-- For LLM Training Data Portfolio Project
-- Author: SQL Developer Portfolio
-- Date: 2025-01-04
-- Description: Complete star schema design with fact and dimension tables
-- ============================================================================

-- ============================================================================
-- DIMENSION TABLES
-- ============================================================================

-- DIM_TIME: Time dimension with multiple hierarchies
CREATE TABLE dim_time (
    time_key INT PRIMARY KEY,
    date_value DATE NOT NULL,
    full_date_description VARCHAR(50) NOT NULL,
    day_number_in_week INT NOT NULL,
    day_name_of_week VARCHAR(10) NOT NULL,
    day_number_in_month INT NOT NULL,
    day_number_in_year INT NOT NULL,
    calendar_week_number_in_year INT NOT NULL,
    calendar_month_number_in_year INT NOT NULL,
    calendar_month_name VARCHAR(10) NOT NULL,
    calendar_year INT NOT NULL,
    calendar_half_year VARCHAR(10) NOT NULL,
    calendar_quarter VARCHAR(10) NOT NULL,
    fiscal_week_number_in_year INT,
    fiscal_month_number_in_year INT,
    fiscal_month_name VARCHAR(10),
    fiscal_year INT,
    fiscal_half_year VARCHAR(10),
    fiscal_quarter VARCHAR(10),
    holiday_flag BOOLEAN DEFAULT FALSE,
    weekend_flag BOOLEAN DEFAULT FALSE,
    day_of_week_in_month INT,
    day_of_week_in_year INT,
    day_of_year INT,
    week_ending_date DATE,
    month_ending_date DATE,
    quarter_ending_date DATE,
    year_ending_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DIM_GEOGRAPHY: Geographic dimension for location data
CREATE TABLE dim_geography (
    geography_key INT PRIMARY KEY,
    country_code CHAR(3) NOT NULL,
    country_name VARCHAR(100) NOT NULL,
    region_code VARCHAR(10) NOT NULL,
    region_name VARCHAR(100) NOT NULL,
    state_province_code VARCHAR(10),
    state_province_name VARCHAR(100),
    city_name VARCHAR(100),
    postal_code VARCHAR(20),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    timezone VARCHAR(50),
    country_code_iso2 CHAR(2),
    continent_code VARCHAR(5),
    continent_name VARCHAR(50),
    market_classification VARCHAR(20), -- Premium, Standard, Economy
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DIM_CUSTOMER: Customer dimension with demographic and behavioral data
CREATE TABLE dim_customer (
    customer_key INT PRIMARY KEY,
    customer_id INT NOT NULL UNIQUE,
    customer_name VARCHAR(100) NOT NULL,
    customer_segment VARCHAR(50), -- Premium, Gold, Silver, Bronze
    gender CHAR(1) CHECK (gender IN ('M', 'F', 'O')),
    date_of_birth DATE,
    age_group VARCHAR(20), -- Under 18, 18-25, 26-35, 36-50, 51-65, Over 65
    marital_status VARCHAR(20), -- Single, Married, Divorced, Widowed
    education_level VARCHAR(50), -- High School, Bachelor, Master, PhD
    occupation VARCHAR(100),
    annual_income DECIMAL(12, 2),
    loyalty_member BOOLEAN DEFAULT FALSE,
    loyalty_tier VARCHAR(20), -- Basic, Silver, Gold, Platinum
    registration_date DATE NOT NULL,
    registration_channel VARCHAR(50),
    last_activity_date DATE,
    total_lifetime_value DECIMAL(12, 2) DEFAULT 0,
    total_orders_count INT DEFAULT 0,
    average_order_value DECIMAL(10, 2) DEFAULT 0,
    preferred_communication_channel VARCHAR(50),
    preferred_store_location VARCHAR(100),
    marketing_opt_in BOOLEAN DEFAULT FALSE,
    geography_key INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (geography_key) REFERENCES dim_geography(geography_key)
);

-- DIM_PRODUCT: Product dimension with detailed product information
CREATE TABLE dim_product (
    product_key INT PRIMARY KEY,
    product_id INT NOT NULL UNIQUE,
    product_name VARCHAR(200) NOT NULL,
    product_code VARCHAR(50) NOT NULL UNIQUE,
    product_category VARCHAR(100) NOT NULL,
    product_subcategory VARCHAR(100),
    product_brand VARCHAR(100),
    product_line VARCHAR(100),
    product_size VARCHAR(50),
    product_color VARCHAR(50),
    product_material VARCHAR(100),
    product_weight DECIMAL(10, 3),
    product_dimensions VARCHAR(50), -- Length x Width x Height
    base_price DECIMAL(10, 2) NOT NULL,
    cost_price DECIMAL(10, 2),
    product_status VARCHAR(20) DEFAULT 'Active', -- Active, Discontinued, Out of Stock
    product_description TEXT,
    product_image_url VARCHAR(500),
    supplier_id INT,
    supplier_name VARCHAR(100),
    manufacturing_date DATE,
    expiry_date DATE,
    weight_class VARCHAR(20), -- Light, Medium, Heavy
    category_ranking INT, -- For performance analysis
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- DIM_MARKETING_CHANNEL: Marketing channel dimension for attribution
CREATE TABLE dim_marketing_channel (
    marketing_channel_key INT PRIMARY KEY,
    channel_id INT NOT NULL UNIQUE,
    channel_name VARCHAR(100) NOT NULL UNIQUE,
    channel_type VARCHAR(50) NOT NULL, -- Direct, Organic, Paid, Social, Email, Affiliates
    channel_category VARCHAR(50), -- Acquisition, Retention, Conversion
    attribution_model VARCHAR(50), -- Last Click, First Click, Linear, Time Decay
    campaign_type VARCHAR(50), -- Awareness, Consideration, Conversion
    cost_per_click DECIMAL(10, 4),
    channel_status VARCHAR(20) DEFAULT 'Active',
    marketing_region VARCHAR(100),
    marketing_budget DECIMAL(12, 2),
    target_audience VARCHAR(200),
    conversion_goal VARCHAR(100),
    performance_metrics TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- ============================================================================
-- FACT TABLES
-- ============================================================================

-- FACT_SALES_TRANSACTIONS: Main sales transaction fact table
CREATE TABLE fact_sales_transactions (
    sales_transaction_key INT PRIMARY KEY,
    transaction_id VARCHAR(50) NOT NULL UNIQUE,
    customer_key INT NOT NULL,
    product_key INT NOT NULL,
    time_key INT NOT NULL,
    geography_key INT NOT NULL,
    marketing_channel_key INT,
    
    -- Transaction Details
    transaction_date DATE NOT NULL,
    transaction_time TIME NOT NULL,
    transaction_type VARCHAR(50) NOT NULL, -- Purchase, Return, Refund, Exchange
    order_id VARCHAR(50) NOT NULL,
    order_item_id VARCHAR(50) NOT NULL,
    session_id VARCHAR(100),
    
    -- Financial Metrics
    quantity_sold INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    unit_cost DECIMAL(10, 2),
    total_revenue DECIMAL(12, 2) NOT NULL, -- quantity_sold * unit_price
    total_cost DECIMAL(12, 2), -- quantity_sold * unit_cost
    total_profit DECIMAL(12, 2), -- total_revenue - total_cost
    discount_amount DECIMAL(10, 2) DEFAULT 0,
    tax_amount DECIMAL(10, 2) DEFAULT 0,
    shipping_cost DECIMAL(10, 2) DEFAULT 0,
    gross_margin DECIMAL(12, 2), -- total_profit / total_revenue * 100
    
    -- Customer Interaction Details
    customer_satisfaction_score DECIMAL(3, 2), -- 0.00 to 5.00
    review_rating INT CHECK (review_rating BETWEEN 1 AND 5),
    review_text TEXT,
    
    -- Performance Metrics
    order_processing_time_minutes INT,
    shipping_time_days INT,
    delivery_status VARCHAR(20), -- Delivered, Shipped, Pending, Cancelled
    payment_method VARCHAR(50),
    payment_status VARCHAR(20), -- Paid, Pending, Failed, Refunded
    
    -- Business Intelligence Flags
    is_return BOOLEAN DEFAULT FALSE,
    is_express_delivery BOOLEAN DEFAULT FALSE,
    is_gift BOOLEAN DEFAULT FALSE,
    is_first_time_purchase BOOLEAN DEFAULT FALSE,
    is_repeat_customer BOOLEAN DEFAULT FALSE,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign Key Constraints
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    FOREIGN KEY (time_key) REFERENCES dim_time(time_key),
    FOREIGN KEY (geography_key) REFERENCES dim_geography(geography_key),
    FOREIGN KEY (marketing_channel_key) REFERENCES dim_marketing_channel(marketing_channel_key),
    
    -- Check Constraints
    CONSTRAINT chk_positive_quantity CHECK (quantity_sold > 0),
    CONSTRAINT chk_positive_prices CHECK (unit_price >= 0 AND unit_cost >= 0),
    CONSTRAINT chk_positive_financials CHECK (total_revenue >= 0 AND total_cost >= 0),
    CONSTRAINT chk_valid_review_rating CHECK (review_rating BETWEEN 1 AND 5),
    CONSTRAINT chk_valid_satisfaction_score CHECK (customer_satisfaction_score BETWEEN 0.00 AND 5.00)
);

-- FACT_WEB_EVENTS: Web user behavior and engagement fact table
CREATE TABLE fact_web_events (
    web_event_key INT PRIMARY KEY,
    customer_key INT,
    time_key INT NOT NULL,
    product_key INT,
    marketing_channel_key INT,
    session_id VARCHAR(100) NOT NULL,
    user_id VARCHAR(100),
    
    -- Event Details
    event_date DATE NOT NULL,
    event_time TIME NOT NULL,
    event_type VARCHAR(100) NOT NULL, -- page_view, add_to_cart, checkout_start, purchase, etc.
    page_url VARCHAR(500),
    page_title VARCHAR(200),
    referrer_url VARCHAR(500),
    utm_source VARCHAR(100),
    utm_medium VARCHAR(100),
    utm_campaign VARCHAR(100),
    utm_term VARCHAR(100),
    utm_content VARCHAR(100),
    
    -- Device and Browser Info
    device_type VARCHAR(50), -- Desktop, Mobile, Tablet
    browser_name VARCHAR(50),
    operating_system VARCHAR(50),
    screen_resolution VARCHAR(20),
    ip_address VARCHAR(45),
    user_agent TEXT,
    
    -- Engagement Metrics
    page_view_duration_seconds INT,
    scroll_depth_percent INT CHECK (scroll_depth_percent BETWEEN 0 AND 100),
    exit_page_flag BOOLEAN DEFAULT FALSE,
    bounce_flag BOOLEAN DEFAULT FALSE,
    internal_search_terms VARCHAR(200),
    video_engagement_seconds INT,
    
    -- Conversion Tracking
    conversion_event BOOLEAN DEFAULT FALSE,
    conversion_value DECIMAL(12, 2),
    goal_completion VARCHAR(100),
    transaction_id VARCHAR(50), -- Links to fact_sales_transactions
    
    -- Session Metrics
    session_duration_seconds INT,
    pages_per_session INT,
    events_per_session INT,
    session_start_time TIME,
    session_end_time TIME,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign Key Constraints
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    FOREIGN KEY (time_key) REFERENCES dim_time(time_key),
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    FOREIGN KEY (marketing_channel_key) REFERENCES dim_marketing_channel(marketing_channel_key)
);

-- FACT_CUSTOMER_INTERACTIONS: Customer touchpoint fact table
CREATE TABLE fact_customer_interactions (
    interaction_key INT PRIMARY KEY,
    customer_key INT NOT NULL,
    time_key INT NOT NULL,
    product_key INT,
    marketing_channel_key INT,
    
    -- Interaction Details
    interaction_date DATE NOT NULL,
    interaction_time TIME NOT NULL,
    interaction_channel VARCHAR(50) NOT NULL, -- Email, Phone, Chat, Social Media, In-Store
    interaction_type VARCHAR(100) NOT NULL, -- Support, Sales, Inquiry, Complaint, Feedback
    interaction_purpose VARCHAR(200),
    interaction_status VARCHAR(50) DEFAULT 'Open', -- Open, In Progress, Resolved, Closed
    priority_level VARCHAR(20) DEFAULT 'Medium', -- Low, Medium, High, Critical
    
    -- Customer Service Metrics
    first_response_time_minutes INT,
    resolution_time_minutes INT,
    satisfaction_score DECIMAL(3, 2), -- 0.00 to 5.00
    resolution_status VARCHAR(50), -- Resolved, Escalated, Pending, Unresolved
    
    -- Content of Interaction
    interaction_subject VARCHAR(200),
    interaction_details TEXT,
    resolution_notes TEXT,
    agent_id VARCHAR(50),
    agent_name VARCHAR(100),
    department VARCHAR(100),
    
    -- Business Impact
    revenue_impact DECIMAL(12, 2), -- Positive for upsells, negative for churn prevention cost
    sentiment_score DECIMAL(3, 2), -- -1.00 to 1.00 (negative to positive)
    sentiment_category VARCHAR(20), -- Positive, Negative, Neutral
    follow_up_required BOOLEAN DEFAULT FALSE,
    follow_up_date DATE,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign Key Constraints
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    FOREIGN KEY (time_key) REFERENCES dim_time(time_key),
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    FOREIGN KEY (marketing_channel_key) REFERENCES dim_marketing_channel(marketing_channel_key)
);

-- ============================================================================
-- STAGING TABLES FOR ETL PROCESSING
-- ============================================================================

-- STG_SALES_TRANSACTIONS: Staging table for raw sales data
CREATE TABLE stg_sales_transactions (
    staging_id INT PRIMARY KEY,
    source_transaction_id VARCHAR(50) NOT NULL,
    source_customer_id VARCHAR(50),
    source_product_code VARCHAR(50),
    transaction_date_str VARCHAR(20), -- Before conversion to DATE
    transaction_time_str VARCHAR(20), -- Before conversion to TIME
    transaction_type VARCHAR(50),
    order_id VARCHAR(50),
    order_item_id VARCHAR(50),
    quantity_sold_str VARCHAR(20), -- Before conversion to INT
    unit_price_str VARCHAR(20), -- Before conversion to DECIMAL
    discount_amount_str VARCHAR(20), -- Before conversion to DECIMAL
    tax_amount_str VARCHAR(20), -- Before conversion to DECIMAL
    shipping_cost_str VARCHAR(20), -- Before conversion to DECIMAL
    customer_satisfaction_score_str VARCHAR(10), -- Before conversion to DECIMAL
    review_rating_str VARCHAR(10), -- Before conversion to INT
    delivery_status VARCHAR(20),
    payment_method VARCHAR(50),
    source_channel VARCHAR(50),
    source_region VARCHAR(100),
    raw_json_data JSON, -- To store the original JSON if source is JSON
    load_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    load_status VARCHAR(20) DEFAULT 'New', -- New, Validated, Error, Loaded
    error_message TEXT,
    processed_flag BOOLEAN DEFAULT FALSE
);

-- STG_WEB_EVENTS: Staging table for web events
CREATE TABLE stg_web_events (
    staging_id INT PRIMARY KEY,
    source_event_id VARCHAR(100),
    source_user_id VARCHAR(100),
    event_date_str VARCHAR(20), -- Before conversion to DATE
    event_time_str VARCHAR(20), -- Before conversion to TIME
    event_type VARCHAR(100),
    page_url VARCHAR(500),
    referrer_url VARCHAR(500),
    utm_source VARCHAR(100),
    utm_medium VARCHAR(100),
    utm_campaign VARCHAR(100),
    utm_term VARCHAR(100),
    utm_content VARCHAR(100),
    device_type VARCHAR(50),
    browser_name VARCHAR(50),
    operating_system VARCHAR(50),
    page_view_duration_str VARCHAR(20), -- Before conversion to INT
    session_id VARCHAR(100),
    session_duration_str VARCHAR(20), -- Before conversion to INT
    raw_json_data JSON,
    load_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    load_status VARCHAR(20) DEFAULT 'New',
    error_message TEXT,
    processed_flag BOOLEAN DEFAULT FALSE
);

-- STG_CUSTOMERS: Staging table for customer data
CREATE TABLE stg_customers (
    staging_id INT PRIMARY KEY,
    source_customer_id VARCHAR(50) NOT NULL,
    customer_name VARCHAR(100),
    customer_segment VARCHAR(50),
    gender VARCHAR(10),
    date_of_birth_str VARCHAR(20), -- Before conversion to DATE
    marital_status VARCHAR(20),
    education_level VARCHAR(50),
    occupation VARCHAR(100),
    annual_income_str VARCHAR(20), -- Before conversion to DECIMAL
    loyalty_member_str VARCHAR(10), -- Before conversion to BOOLEAN
    registration_date_str VARCHAR(20), -- Before conversion to DATE
    registration_channel VARCHAR(50),
    country VARCHAR(100),
    region VARCHAR(100),
    city VARCHAR(100),
    postal_code VARCHAR(20),
    preferred_communication_channel VARCHAR(50),
    marketing_opt_in_str VARCHAR(10), -- Before conversion to BOOLEAN
    raw_json_data JSON,
    load_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    load_status VARCHAR(20) DEFAULT 'New',
    error_message TEXT,
    processed_flag BOOLEAN DEFAULT FALSE
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE OPTIMIZATION
-- ============================================================================

-- Indexes on dimension tables
CREATE INDEX idx_dim_customer_id ON dim_customer(customer_id);
CREATE INDEX idx_dim_customer_segment ON dim_customer(customer_segment);
CREATE INDEX idx_dim_customer_registration_date ON dim_customer(registration_date);
CREATE INDEX idx_dim_product_id ON dim_product(product_id);
CREATE INDEX idx_dim_product_category ON dim_product(product_category);
CREATE INDEX idx_dim_time_date_value ON dim_time(date_value);
CREATE INDEX idx_dim_time_calendar_year ON dim_time(calendar_year);
CREATE INDEX idx_dim_geography_country ON dim_geography(country_code);

-- Indexes on fact tables (typically on foreign key columns)
CREATE INDEX idx_fact_sales_customer_key ON fact_sales_transactions(customer_key);
CREATE INDEX idx_fact_sales_product_key ON fact_sales_transactions(product_key);
CREATE INDEX idx_fact_sales_time_key ON fact_sales_transactions(time_key);
CREATE INDEX idx_fact_sales_geography_key ON fact_sales_transactions(geography_key);
CREATE INDEX idx_fact_sales_transaction_date ON fact_sales_transactions(transaction_date);
CREATE INDEX idx_fact_sales_order_id ON fact_sales_transactions(order_id);

CREATE INDEX idx_fact_web_events_customer_key ON fact_web_events(customer_key);
CREATE INDEX idx_fact_web_events_time_key ON fact_web_events(time_key);
CREATE INDEX idx_fact_web_events_product_key ON fact_web_events(product_key);
CREATE INDEX idx_fact_web_events_event_date ON fact_web_events(event_date);
CREATE INDEX idx_fact_web_events_session_id ON fact_web_events(session_id);
CREATE INDEX idx_fact_web_events_event_type ON fact_web_events(event_type);

CREATE INDEX idx_fact_customer_interactions_customer_key ON fact_customer_interactions(customer_key);
CREATE INDEX idx_fact_customer_interactions_time_key ON fact_customer_interactions(time_key);
CREATE INDEX idx_fact_customer_interactions_interaction_date ON fact_customer_interactions(interaction_date);
CREATE INDEX idx_fact_customer_interactions_interaction_type ON fact_customer_interactions(interaction_type);

-- Composite indexes for common query patterns
CREATE INDEX idx_fact_sales_customer_time ON fact_sales_transactions(customer_key, time_key);
CREATE INDEX idx_fact_sales_product_time ON fact_sales_transactions(product_key, time_key);
CREATE INDEX idx_fact_sales_date_channel ON fact_sales_transactions(transaction_date, marketing_channel_key);