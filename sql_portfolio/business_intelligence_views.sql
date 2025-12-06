-- ============================================================================
-- E-COMMERCE ANALYTICS & CUSTOMER INTELLIGENCE PLATFORM
-- BUSINESS INTELLIGENCE VIEWS
-- For LLM Training Data Portfolio Project
-- Author: SQL Developer Portfolio
-- Date: 2025-01-04
-- Description: 10+ analytical views for business intelligence
-- ============================================================================

-- ============================================================================
-- EXECUTIVE DASHBOARD KPI VIEWS
-- ============================================================================

-- View 1: Daily Sales Summary
CREATE OR REPLACE VIEW v_daily_sales_summary AS
SELECT 
    dt.date_value AS sales_date,
    dt.day_name_of_week,
    dt.calendar_month_name,
    dt.calendar_year,
    COUNT(fst.sales_transaction_key) AS total_transactions,
    SUM(fst.total_revenue) AS daily_revenue,
    SUM(fst.total_profit) AS daily_profit,
    AVG(fst.total_revenue) AS average_order_value,
    COUNT(DISTINCT fst.customer_key) AS unique_customers,
    SUM(fst.quantity_sold) AS total_items_sold,
    -- Calculate day-over-day growth
    LAG(SUM(fst.total_revenue)) OVER (ORDER BY dt.date_value) AS prev_day_revenue,
    CASE 
        WHEN LAG(SUM(fst.total_revenue)) OVER (ORDER BY dt.date_value) > 0 THEN
            ROUND(((SUM(fst.total_revenue) - LAG(SUM(fst.total_revenue)) OVER (ORDER BY dt.date_value)) * 100.0 / 
                   LAG(SUM(fst.total_revenue)) OVER (ORDER BY dt.date_value)), 2)
        ELSE NULL
    END AS revenue_growth_percent
FROM fact_sales_transactions fst
JOIN dim_time dt ON fst.time_key = dt.time_key
WHERE fst.transaction_type = 'Purchase'
GROUP BY dt.date_value, dt.day_name_of_week, dt.calendar_month_name, dt.calendar_year
ORDER BY dt.date_value DESC;

-- View 2: Executive KPI Dashboard
CREATE OR REPLACE VIEW v_executive_kpi_dashboard AS
WITH current_period AS (
    SELECT 
        COUNT(fst.sales_transaction_key) AS total_transactions,
        SUM(fst.total_revenue) AS total_revenue,
        SUM(fst.total_profit) AS total_profit,
        AVG(fst.total_revenue) AS average_order_value,
        COUNT(DISTINCT fst.customer_key) AS unique_customers,
        COUNT(CASE WHEN fst.is_return = TRUE THEN 1 END) AS total_returns,
        COUNT(fst.sales_transaction_key) - COUNT(CASE WHEN fst.is_return = TRUE THEN 1 END) AS net_transactions
    FROM fact_sales_transactions fst
    JOIN dim_time dt ON fst.time_key = dt.time_key
    WHERE dt.date_value >= CURRENT_DATE - INTERVAL '30 days'
        AND fst.transaction_type = 'Purchase'
),
previous_period AS (
    SELECT 
        COUNT(fst.sales_transaction_key) AS total_transactions,
        SUM(fst.total_revenue) AS total_revenue,
        SUM(fst.total_profit) AS total_profit,
        AVG(fst.total_revenue) AS average_order_value,
        COUNT(DISTINCT fst.customer_key) AS unique_customers
    FROM fact_sales_transactions fst
    JOIN dim_time dt ON fst.time_key = dt.time_key
    WHERE dt.date_value >= CURRENT_DATE - INTERVAL '60 days'
        AND dt.date_value < CURRENT_DATE - INTERVAL '30 days'
        AND fst.transaction_type = 'Purchase'
)
SELECT 
    cp.total_transactions AS current_period_transactions,
    pp.total_transactions AS previous_period_transactions,
    ROUND(((cp.total_transactions - pp.total_transactions) * 100.0 / pp.total_transactions), 2) AS transaction_growth_percent,
    cp.total_revenue AS current_period_revenue,
    pp.total_revenue AS previous_period_revenue,
    ROUND(((cp.total_revenue - pp.total_revenue) * 100.0 / pp.total_revenue), 2) AS revenue_growth_percent,
    cp.total_profit AS current_period_profit,
    pp.total_profit AS previous_period_profit,
    ROUND(((cp.total_profit - pp.total_profit) * 100.0 / pp.total_profit), 2) AS profit_growth_percent,
    cp.average_order_value AS current_period_aov,
    pp.average_order_value AS previous_period_aov,
    ROUND(((cp.average_order_value - pp.average_order_value) * 100.0 / pp.average_order_value), 2) AS aov_growth_percent,
    cp.unique_customers AS current_period_customers,
    pp.unique_customers AS previous_period_customers,
    ROUND(((cp.unique_customers - pp.unique_customers) * 100.0 / pp.unique_customers), 2) AS customer_growth_percent,
    cp.total_returns,
    cp.net_transactions
FROM current_period cp
CROSS JOIN previous_period pp;

-- ============================================================================
-- SALES PERFORMANCE VIEWS
-- ============================================================================

-- View 3: Sales Performance by Region and Product
CREATE OR REPLACE VIEW v_sales_performance_region_product AS
SELECT 
    dg.country_name AS region,
    dg.region_name AS sub_region,
    dp.product_category,
    dp.product_brand,
    dt.calendar_year,
    dt.calendar_month_name,
    COUNT(fst.sales_transaction_key) AS total_transactions,
    SUM(fst.total_revenue) AS total_revenue,
    SUM(fst.total_profit) AS total_profit,
    SUM(fst.quantity_sold) AS total_quantity_sold,
    AVG(fst.total_revenue) AS average_order_value,
    -- Revenue rank within region
    RANK() OVER (PARTITION BY dg.country_name ORDER BY SUM(fst.total_revenue) DESC) AS revenue_rank_in_region,
    -- Profit margin
    CASE 
        WHEN SUM(fst.total_revenue) > 0 THEN
            ROUND((SUM(fst.total_profit) * 100.0 / SUM(fst.total_revenue)), 2)
        ELSE 0
    END AS profit_margin_percent,
    -- Year-over-year growth
    LAG(SUM(fst.total_revenue)) OVER (
        PARTITION BY dg.country_name, dp.product_category, dt.calendar_month_number_in_year
        ORDER BY dt.calendar_year
    ) AS prev_year_monthly_revenue,
    CASE 
        WHEN LAG(SUM(fst.total_revenue)) OVER (
            PARTITION BY dg.country_name, dp.product_category, dt.calendar_month_number_in_year
            ORDER BY dt.calendar_year
        ) > 0 THEN
            ROUND(((SUM(fst.total_revenue) - 
                   LAG(SUM(fst.total_revenue)) OVER (
                       PARTITION BY dg.country_name, dp.product_category, dt.calendar_month_number_in_year
                       ORDER BY dt.calendar_year
                   )) * 100.0 / 
                   LAG(SUM(fst.total_revenue)) OVER (
                       PARTITION BY dg.country_name, dp.product_category, dt.calendar_month_number_in_year
                       ORDER BY dt.calendar_year
                   )), 2)
        ELSE NULL
    END AS yoy_growth_percent
FROM fact_sales_transactions fst
JOIN dim_time dt ON fst.time_key = dt.time_key
JOIN dim_product dp ON fst.product_key = dp.product_key
JOIN dim_geography dg ON fst.geography_key = dg.geography_key
WHERE fst.transaction_type = 'Purchase'
GROUP BY dg.country_name, dg.region_name, dp.product_category, dp.product_brand, 
         dt.calendar_year, dt.calendar_month_name, dt.calendar_month_number_in_year
ORDER BY dg.country_name, dp.product_category, dt.calendar_year DESC, dt.calendar_month_number_in_year DESC;

-- View 4: Product Performance Analysis
CREATE OR REPLACE VIEW v_product_performance_analysis AS
SELECT 
    dp.product_key,
    dp.product_name,
    dp.product_category,
    dp.product_brand,
    dp.product_line,
    COUNT(fst.sales_transaction_key) AS total_transactions,
    SUM(fst.quantity_sold) AS total_quantity_sold,
    SUM(fst.total_revenue) AS total_revenue,
    SUM(fst.total_profit) AS total_profit,
    AVG(fst.total_revenue) AS average_order_value,
    AVG(fst.review_rating) AS average_review_rating,
    COUNT(CASE WHEN fst.review_rating IS NOT NULL THEN 1 END) AS review_count,
    -- Product performance rank
    RANK() OVER (ORDER BY SUM(fst.total_revenue) DESC) AS revenue_rank,
    RANK() OVER (ORDER BY SUM(fst.total_profit) DESC) AS profit_rank,
    RANK() OVER (ORDER BY AVG(fst.review_rating) DESC, COUNT(CASE WHEN fst.review_rating IS NOT NULL THEN 1 END) DESC) AS quality_rank,
    -- Profit margin
    CASE 
        WHEN SUM(fst.total_revenue) > 0 THEN
            ROUND((SUM(fst.total_profit) * 100.0 / SUM(fst.total_revenue)), 2)
        ELSE 0
    END AS profit_margin_percent,
    -- Inventory turnover proxy
    ROUND(SUM(fst.quantity_sold) / NULLIF(SUM(fst.quantity_sold) FILTER (WHERE fst.transaction_date < CURRENT_DATE - INTERVAL '90 days'), 1), 2) AS turnover_ratio
FROM dim_product dp
LEFT JOIN fact_sales_transactions fst ON dp.product_key = fst.product_key
WHERE fst.transaction_type = 'Purchase' OR fst IS NULL
GROUP BY dp.product_key, dp.product_name, dp.product_category, dp.product_brand, dp.product_line
HAVING SUM(COALESCE(fst.total_revenue, 0)) > 0
ORDER BY total_revenue DESC;

-- ============================================================================
-- CUSTOMER BEHAVIOR VIEWS
-- ============================================================================

-- View 5: Customer Segmentation and Behavior
CREATE OR REPLACE VIEW v_customer_segmentation_behavior AS
SELECT 
    dc.customer_key,
    dc.customer_name,
    dc.customer_segment,
    dc.loyalty_tier,
    dc.geography_key,
    dg.country_name,
    dg.region_name,
    -- Customer lifetime metrics
    dc.total_lifetime_value,
    dc.total_orders_count,
    dc.average_order_value,
    -- RFM analysis components
    EXTRACT(DAY FROM (CURRENT_DATE - dc.last_activity_date)) AS days_since_last_purchase,
    -- Purchase behavior
    COUNT(fst.sales_transaction_key) AS recent_transactions_count,
    SUM(fst.total_revenue) AS recent_revenue,
    AVG(fst.total_revenue) AS recent_avg_order_value,
    -- Product preferences
    STRING_AGG(DISTINCT dp.product_category, ', ' ORDER BY dp.product_category) AS preferred_categories,
    -- Engagement metrics
    AVG(fst.customer_satisfaction_score) AS avg_satisfaction_score,
    AVG(fst.review_rating) AS avg_review_rating,
    -- Behavioral indicators
    CASE 
        WHEN EXTRACT(DAY FROM (CURRENT_DATE - dc.last_activity_date)) <= 30 THEN 'Active'
        WHEN EXTRACT(DAY FROM (CURRENT_DATE - dc.last_activity_date)) <= 90 THEN 'At Risk'
        WHEN EXTRACT(DAY FROM (CURRENT_DATE - dc.last_activity_date)) <= 180 THEN 'Dormant'
        ELSE 'Churned'
    END AS engagement_status,
    -- Customer lifetime value tier
    CASE 
        WHEN dc.total_lifetime_value >= 2000 THEN 'High Value'
        WHEN dc.total_lifetime_value >= 1000 THEN 'Medium Value'
        WHEN dc.total_lifetime_value >= 500 THEN 'Low Value'
        ELSE 'New Customer'
    END AS clv_tier
FROM dim_customer dc
JOIN dim_geography dg ON dc.geography_key = dg.geography_key
LEFT JOIN fact_sales_transactions fst ON dc.customer_key = fst.customer_key
LEFT JOIN dim_product dp ON fst.product_key = dp.product_key
WHERE fst.transaction_type = 'Purchase' OR fst IS NULL
GROUP BY dc.customer_key, dc.customer_name, dc.customer_segment, dc.loyalty_tier, 
         dc.geography_key, dg.country_name, dg.region_name, dc.total_lifetime_value, 
         dc.total_orders_count, dc.average_order_value, dc.last_activity_date
ORDER BY dc.total_lifetime_value DESC;

-- View 6: Customer Lifetime Value and Churn Risk
CREATE OR REPLACE VIEW v_customer_ltv_churn_risk AS
WITH customer_metrics AS (
    SELECT 
        dc.customer_key,
        dc.customer_name,
        dc.customer_segment,
        dc.loyalty_member,
        dc.registration_date,
        dc.last_activity_date,
        dc.total_lifetime_value,
        dc.total_orders_count,
        dc.average_order_value,
        -- Calculate customer lifespan in days
        EXTRACT(DAY FROM (dc.last_activity_date - dc.registration_date)) AS customer_lifespan_days,
        -- Calculate purchase frequency
        CASE 
            WHEN EXTRACT(DAY FROM (dc.last_activity_date - dc.registration_date)) > 0 THEN
                dc.total_orders_count / (EXTRACT(DAY FROM (dc.last_activity_date - dc.registration_date)) / 365.0)
            ELSE 0
        END AS annual_purchase_frequency,
        -- Days since last purchase
        EXTRACT(DAY FROM (CURRENT_DATE - dc.last_activity_date)) AS days_since_last_purchase,
        -- Average days between purchases
        AVG(EXTRACT(DAY FROM (fst.transaction_date - LAG(fst.transaction_date) 
            OVER (PARTITION BY dc.customer_key ORDER BY fst.transaction_date)))) AS avg_days_between_purchases
    FROM dim_customer dc
    LEFT JOIN fact_sales_transactions fst ON dc.customer_key = fst.customer_key
    WHERE fst.transaction_type = 'Purchase' OR fst IS NULL
    GROUP BY dc.customer_key, dc.customer_name, dc.customer_segment, dc.loyalty_member,
             dc.registration_date, dc.last_activity_date, dc.total_lifetime_value,
             dc.total_orders_count, dc.average_order_value
)
SELECT 
    customer_key,
    customer_name,
    customer_segment,
    loyalty_member,
    total_lifetime_value,
    total_orders_count,
    average_order_value,
    customer_lifespan_days,
    annual_purchase_frequency,
    days_since_last_purchase,
    COALESCE(avg_days_between_purchases, 365) AS avg_days_between_purchases,
    -- CLV calculation
    CASE 
        WHEN customer_lifespan_days > 0 AND annual_purchase_frequency > 0 THEN
            (average_order_value * annual_purchase_frequency) * 2  -- 2-year projected lifespan
        ELSE total_lifetime_value
    END AS projected_clv,
    -- Churn risk assessment
    CASE 
        WHEN days_since_last_purchase > (avg_days_between_purchases * 2) THEN 'High Risk'
        WHEN days_since_last_purchase > (avg_days_between_purchases * 1.5) THEN 'Medium Risk'
        WHEN days_since_last_purchase > avg_days_between_purchases THEN 'Low Risk'
        ELSE 'Low Risk - Active'
    END AS churn_risk_level,
    -- Customer value tier
    CASE 
        WHEN projected_clv >= 1500 THEN 'VIP'
        WHEN projected_clv >= 800 THEN 'High Value'
        WHEN projected_clv >= 400 THEN 'Medium Value'
        WHEN projected_clv >= 100 THEN 'Low Value'
        ELSE 'Potential'
    END AS customer_value_tier
FROM customer_metrics
ORDER BY projected_clv DESC;

-- ============================================================================
-- MARKETING ANALYTICS VIEWS
-- ============================================================================

-- View 7: Marketing Attribution and Channel Performance
CREATE OR REPLACE VIEW v_marketing_attribution_channel_performance AS
SELECT 
    dmc.channel_name,
    dmc.channel_type,
    dmc.campaign_type,
    dmc.cost_per_click,
    COUNT(fst.sales_transaction_key) AS attributed_conversions,
    SUM(fst.total_revenue) AS attributed_revenue,
    SUM(fst.total_profit) AS attributed_profit,
    -- Cost metrics
    COUNT(fst.sales_transaction_key) * AVG(dmc.cost_per_click) AS total_marketing_cost,
    CASE 
        WHEN COUNT(fst.sales_transaction_key) > 0 THEN
            ROUND(SUM(fst.total_revenue) / (COUNT(fst.sales_transaction_key) * AVG(dmc.cost_per_click)), 2)
        ELSE NULL
    END AS revenue_per_dollar_spent,
    -- ROI calculation
    CASE 
        WHEN COUNT(fst.sales_transaction_key) * AVG(dmc.cost_per_click) > 0 THEN
            ROUND(((SUM(fst.total_revenue) - (COUNT(fst.sales_transaction_key) * AVG(dmc.cost_per_click))) * 100.0 / 
                   (COUNT(fst.sales_transaction_key) * AVG(dmc.cost_per_click))), 2)
        ELSE NULL
    END AS roi_percent,
    -- Customer acquisition metrics
    COUNT(DISTINCT fst.customer_key) AS customers_acquired,
    CASE 
        WHEN COUNT(DISTINCT fst.customer_key) > 0 THEN
            ROUND((COUNT(fst.sales_transaction_key) * AVG(dmc.cost_per_click)) / COUNT(DISTINCT fst.customer_key), 2)
        ELSE NULL
    END AS cac_per_customer,
    -- Conversion rates
    ROUND((COUNT(fst.sales_transaction_key) * 100.0 / 
          (SELECT COUNT(*) FROM fact_web_events fwe WHERE fwe.marketing_channel_key = dmc.marketing_channel_key)), 2) AS conversion_rate_percent
FROM dim_marketing_channel dmc
LEFT JOIN fact_sales_transactions fst ON dmc.marketing_channel_key = fst.marketing_channel_key
WHERE fst.transaction_type = 'Purchase' OR fst IS NULL
GROUP BY dmc.channel_name, dmc.channel_type, dmc.campaign_type, dmc.cost_per_click, dmc.marketing_channel_key
HAVING COUNT(fst.sales_transaction_key) > 0 OR COUNT(CASE WHEN fst IS NULL THEN 1 END) > 0
ORDER BY attributed_revenue DESC;

-- View 8: Campaign Performance Dashboard
CREATE OR REPLACE VIEW v_campaign_performance_dashboard AS
SELECT 
    dmc.channel_name AS campaign_name,
    dmc.campaign_type,
    dmc.target_audience,
    dmc.marketing_budget,
    -- Engagement metrics
    (SELECT COUNT(*) FROM fact_web_events fwe WHERE fwe.marketing_channel_key = dmc.marketing_channel_key) AS total_impressions,
    (SELECT COUNT(*) FROM fact_web_events fwe WHERE fwe.marketing_channel_key = dmc.marketing_channel_key AND fwe.event_type = 'page_view') AS total_clicks,
    -- Conversion metrics
    COUNT(fst.sales_transaction_key) AS total_conversions,
    SUM(fst.total_revenue) AS total_revenue_from_campaign,
    -- Performance ratios
    CASE 
        WHEN (SELECT COUNT(*) FROM fact_web_events fwe WHERE fwe.marketing_channel_key = dmc.marketing_channel_key) > 0 THEN
            ROUND(((SELECT COUNT(*) FROM fact_web_events fwe WHERE fwe.marketing_channel_key = dmc.marketing_channel_key AND fwe.event_type = 'page_view') * 100.0 / 
                   (SELECT COUNT(*) FROM fact_web_events fwe WHERE fwe.marketing_channel_key = dmc.marketing_channel_key)), 4)
        ELSE 0
    END AS click_through_rate_percent,
    CASE 
        WHEN (SELECT COUNT(*) FROM fact_web_events fwe WHERE fwe.marketing_channel_key = dmc.marketing_channel_key AND fwe.event_type = 'page_view') > 0 THEN
            ROUND((COUNT(fst.sales_transaction_key) * 100.0 / 
                   (SELECT COUNT(*) FROM fact_web_events fwe WHERE fwe.marketing_channel_key = dmc.marketing_channel_key AND fwe.event_type = 'page_view')), 4)
        ELSE 0
    END AS conversion_rate_percent,
    -- ROI metrics
    CASE 
        WHEN dmc.marketing_budget > 0 THEN
            ROUND((SUM(fst.total_revenue) - dmc.marketing_budget) * 100.0 / dmc.marketing_budget, 2)
        ELSE NULL
    END AS roi_percent
FROM dim_marketing_channel dmc
LEFT JOIN fact_sales_transactions fst ON dmc.marketing_channel_key = fst.marketing_channel_key
WHERE fst.transaction_type = 'Purchase' OR fst IS NULL
GROUP BY dmc.channel_name, dmc.campaign_type, dmc.target_audience, dmc.marketing_budget
HAVING dmc.marketing_budget > 0 OR COUNT(fst.sales_transaction_key) > 0
ORDER BY total_revenue_from_campaign DESC;

-- ============================================================================
-- OPERATIONAL METRICS VIEWS
-- ============================================================================

-- View 9: Order Fulfillment and Delivery Metrics
CREATE OR REPLACE VIEW v_order_fulfillment_delivery_metrics AS
SELECT 
    dt.calendar_year,
    dt.calendar_month_name,
    fst.delivery_status,
    COUNT(fst.sales_transaction_key) AS order_count,
    SUM(fst.total_revenue) AS total_revenue_impacted,
    AVG(fst.order_processing_time_minutes) AS avg_processing_time_minutes,
    AVG(fst.shipping_time_days) AS avg_shipping_time_days,
    -- Performance quartiles
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY fst.order_processing_time_minutes) AS processing_time_25th_percentile,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY fst.order_processing_time_minutes) AS processing_time_median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY fst.order_processing_time_minutes) AS processing_time_75th_percentile,
    -- Quality metrics
    COUNT(CASE WHEN fst.order_processing_time_minutes > 120 THEN 1 END) AS slow_processing_orders,
    COUNT(CASE WHEN fst.shipping_time_days > 7 THEN 1 END) AS slow_shipping_orders,
    ROUND((COUNT(CASE WHEN fst.order_processing_time_minutes <= 60 THEN 1 END) * 100.0 / COUNT(fst.sales_transaction_key)), 2) AS on_time_processing_percent,
    ROUND((COUNT(CASE WHEN fst.shipping_time_days <= 5 THEN 1 END) * 100.0 / COUNT(fst.sales_transaction_key)), 2) AS on_time_shipping_percent,
    -- Geographic impact
    dg.country_name,
    dg.region_name,
    -- Customer satisfaction correlation
    AVG(fst.customer_satisfaction_score) AS avg_customer_satisfaction,
    AVG(fst.review_rating) AS avg_review_rating
FROM fact_sales_transactions fst
JOIN dim_time dt ON fst.time_key = dt.time_key
JOIN dim_geography dg ON fst.geography_key = dg.geography_key
WHERE fst.transaction_type = 'Purchase'
GROUP BY dt.calendar_year, dt.calendar_month_name, fst.delivery_status, dg.country_name, dg.region_name
ORDER BY dt.calendar_year DESC, dt.calendar_month_number_in_year DESC, fst.delivery_status;

-- View 10: Return and Refund Analysis
CREATE OR REPLACE VIEW v_return_refund_analysis AS
SELECT 
    dp.product_category,
    dp.product_brand,
    dg.country_name,
    dt.calendar_year,
    dt.calendar_month_name,
    -- Return metrics
    COUNT(CASE WHEN fst.is_return = TRUE THEN 1 END) AS total_returns,
    COUNT(fst.sales_transaction_key) AS total_transactions,
    ROUND((COUNT(CASE WHEN fst.is_return = TRUE THEN 1 END) * 100.0 / COUNT(fst.sales_transaction_key)), 2) AS return_rate_percent,
    -- Financial impact
    SUM(CASE WHEN fst.is_return = TRUE THEN fst.total_revenue ELSE 0 END) AS total_returned_value,
    AVG(CASE WHEN fst.is_return = TRUE THEN fst.total_revenue END) AS avg_returned_value,
    -- Return reasons proxy (using available fields)
    COUNT(CASE WHEN fst.customer_satisfaction_score < 3 THEN 1 END) AS dissatisfaction_returns,
    COUNT(CASE WHEN fst.review_rating <= 2 THEN 1 END) AS low_rating_returns,
    -- Time-based analysis
    AVG(CASE WHEN fst.is_return = TRUE THEN EXTRACT(DAY FROM (fst.transaction_date - 
        (SELECT MIN(transaction_date) FROM fact_sales_transactions fst2 
         WHERE fst2.order_id = fst.order_id AND fst2.customer_key = fst.customer_key))) END) AS avg_return_days,
    -- Seasonal patterns
    CASE 
        WHEN dt.calendar_month_name IN ('November', 'December', 'January') THEN 'Holiday Season'
        WHEN dt.calendar_month_name IN ('May', 'June', 'July') THEN 'Summer Period'
        ELSE 'Other'
    END AS season_type
FROM fact_sales_transactions fst
JOIN dim_product dp ON fst.product_key = dp.product_key
JOIN dim_geography dg ON fst.geography_key = dg.geography_key
JOIN dim_time dt ON fst.time_key = dt.time_key
WHERE fst.transaction_type IN ('Purchase', 'Return', 'Refund')
GROUP BY dp.product_category, dp.product_brand, dg.country_name, 
         dt.calendar_year, dt.calendar_month_name
HAVING COUNT(fst.sales_transaction_key) > 10  -- Only show categories with meaningful volume
ORDER BY return_rate_percent DESC, total_returned_value DESC;

-- ============================================================================
-- CUSTOMER EXPERIENCE VIEWS
-- ============================================================================

-- View 11: Customer Experience and Satisfaction Metrics
CREATE OR REPLACE VIEW v_customer_experience_metrics AS
SELECT 
    dc.customer_segment,
    dg.country_name,
    dp.product_category,
    -- Satisfaction metrics
    AVG(fst.customer_satisfaction_score) AS avg_satisfaction_score,
    AVG(fst.review_rating) AS avg_review_rating,
    COUNT(fst.review_rating) AS total_reviews,
    COUNT(CASE WHEN fst.review_rating >= 4 THEN 1 END) AS positive_reviews,
    COUNT(CASE WHEN fst.review_rating <= 2 THEN 1 END) AS negative_reviews,
    ROUND((COUNT(CASE WHEN fst.review_rating >= 4 THEN 1 END) * 100.0 / COUNT(fst.review_rating)), 2) AS positive_review_percent,
    -- Service quality metrics
    AVG(fst.order_processing_time_minutes) AS avg_processing_time,
    AVG(fst.shipping_time_days) AS avg_shipping_time,
    -- Quality indicators
    ROUND((COUNT(CASE WHEN fst.customer_satisfaction_score >= 4.0 THEN 1 END) * 100.0 / 
           COUNT(fst.customer_satisfaction_score)), 2) AS high_satisfaction_percent,
    -- Value correlation
    AVG(fst.total_revenue) AS avg_order_value_by_satisfaction,
    COUNT(fst.sales_transaction_key) AS transaction_count_by_segment
FROM fact_sales_transactions fst
JOIN dim_customer dc ON fst.customer_key = dc.customer_key
JOIN dim_geography dg ON dc.geography_key = dg.geography_key
JOIN dim_product dp ON fst.product_key = dp.product_key
WHERE fst.customer_satisfaction_score IS NOT NULL 
    OR fst.review_rating IS NOT NULL
GROUP BY dc.customer_segment, dg.country_name, dp.product_category
HAVING COUNT(fst.sales_transaction_key) >= 5  -- Minimum sample size
ORDER BY avg_satisfaction_score DESC;

-- View 12: Web Engagement and Conversion Funnel
CREATE OR REPLACE VIEW v_web_engagement_conversion_funnel AS
WITH funnel_data AS (
    SELECT 
        dt.calendar_date AS visit_date,
        COUNT(CASE WHEN fw.event_type = 'page_view' THEN 1 END) AS visits,
        COUNT(CASE WHEN fw.event_type = 'add_to_cart' THEN 1 END) AS add_to_cart,
        COUNT(CASE WHEN fw.event_type = 'checkout_start' THEN 1 END) AS checkout_started,
        COUNT(CASE WHEN fw.event_type = 'purchase' THEN 1 END) AS purchases,
        COUNT(DISTINCT fw.customer_key) AS unique_visitors,
        COUNT(DISTINCT CASE WHEN fw.event_type = 'purchase' THEN fw.customer_key END) AS unique_customers
    FROM fact_web_events fw
    JOIN dim_time dt ON fw.time_key = dt.time_key
    WHERE fw.event_type IN ('page_view', 'add_to_cart', 'checkout_start', 'purchase')
    GROUP BY dt.calendar_date
)
SELECT 
    visit_date,
    unique_visitors,
    visits,
    add_to_cart,
    checkout_started,
    purchases,
    -- Conversion rates
    ROUND((add_to_cart * 100.0 / NULLIF(visits, 0)), 2) AS visit_to_cart_percent,
    ROUND((checkout_started * 100.0 / NULLIF(add_to_cart, 0)), 2) AS cart_to_checkout_percent,
    ROUND((purchases * 100.0 / NULLIF(checkout_started, 0)), 2) AS checkout_to_purchase_percent,
    ROUND((purchases * 100.0 / NULLIF(visits, 0)), 4) AS overall_conversion_rate,
    -- Engagement metrics
    ROUND((add_to_cart / NULLIF(unique_visitors, 0)), 2) AS avg_adds_per_visitor,
    ROUND((purchases / NULLIF(unique_visitors, 0)), 2) AS avg_purchases_per_visitor
FROM funnel_data
ORDER BY visit_date DESC;

-- ============================================================================
-- USAGE EXAMPLES AND VIEW VALIDATION
-- ============================================================================

-- Example queries showing how to use the business intelligence views

-- Query 1: Executive dashboard summary
SELECT 
    current_period_revenue,
    revenue_growth_percent,
    current_period_profit,
    profit_growth_percent,
    current_period_customers,
    customer_growth_percent
FROM v_executive_kpi_dashboard;

-- Query 2: Top-performing products
SELECT 
    product_name,
    product_category,
    total_revenue,
    profit_margin_percent,
    average_review_rating
FROM v_product_performance_analysis
LIMIT 10;

-- Query 3: Customer segments with churn risk
SELECT 
    customer_segment,
    churn_risk_level,
    projected_clv,
    customer_value_tier,
    days_since_last_purchase
FROM v_customer_ltv_churn_risk
WHERE churn_risk_level IN ('High Risk', 'Medium Risk')
ORDER BY days_since_last_purchase DESC;

-- Query 4: Marketing channel performance ROI
SELECT 
    channel_name,
    channel_type,
    attributed_revenue,
    roi_percent,
    cac_per_customer
FROM v_marketing_attribution_channel_performance
WHERE roi_percent IS NOT NULL
ORDER BY roi_percent DESC;

-- Query 5: Daily sales trends
SELECT 
    sales_date,
    daily_revenue,
    revenue_growth_percent,
    unique_customers,
    average_order_value
FROM v_daily_sales_summary
WHERE sales_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY sales_date DESC;

-- Show all created views
SELECT table_name, table_type, table_comment
FROM information_schema.tables
WHERE table_schema = 'public' 
    AND table_type = 'VIEW'
    AND table_name LIKE 'v_%'
ORDER BY table_name;