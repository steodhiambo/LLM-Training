-- ============================================================================
-- E-COMMERCE ANALYTICS & CUSTOMER INTELLIGENCE PLATFORM
-- COMPLEX SQL QUERIES FOR LLM TRAINING DATA PORTFOLIO
-- Author: SQL Developer Portfolio
-- Date: 2025-01-04
-- Description: 15+ complex SQL queries demonstrating advanced techniques
-- ============================================================================

-- ============================================================================
-- QUERY CATEGORY A: CUSTOMER ANALYTICS
-- ============================================================================

-- Query A1: RFM (Recency, Frequency, Monetary) Customer Segmentation
-- Business Purpose: Identify customer segments based on purchase behavior
WITH customer_rfm AS (
    SELECT 
        c.customer_key,
        c.customer_name,
        c.customer_segment,
        -- Recency: Days since last purchase
        EXTRACT(DAY FROM (CURRENT_DATE - MAX(st.transaction_date))) AS recency_days,
        -- Frequency: Total number of transactions
        COUNT(st.sales_transaction_key) AS frequency,
        -- Monetary: Total revenue from customer
        SUM(st.total_revenue) AS monetary
    FROM dim_customer c
    JOIN fact_sales_transactions st ON c.customer_key = st.customer_key
    GROUP BY c.customer_key, c.customer_name, c.customer_segment
),
rfm_scores AS (
    SELECT 
        *,
        -- Assign scores 1-5 (5 being best) for each metric
        NTILE(5) OVER (ORDER BY recency_days DESC) AS recency_score, -- Higher recency = lower score
        NTILE(5) OVER (ORDER BY frequency) AS frequency_score,
        NTILE(5) OVER (ORDER BY monetary) AS monetary_score
    FROM customer_rfm
),
segmented_customers AS (
    SELECT 
        *,
        CASE 
            WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'
            WHEN recency_score >= 3 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'Loyal Customers'
            WHEN recency_score >= 3 AND frequency_score <= 2 THEN 'Potential Loyalists'
            WHEN recency_score = 5 AND frequency_score <= 2 THEN 'New Customers'
            WHEN recency_score <= 2 AND frequency_score >= 3 THEN 'At Risk'
            WHEN recency_score = 1 AND frequency_score <= 2 THEN 'Hibernating'
            WHEN recency_score = 1 AND frequency_score >= 4 THEN 'Cannot Lose Them'
            ELSE 'Others'
        END AS customer_segmentation
    FROM rfm_scores
)
SELECT 
    customer_segmentation,
    COUNT(*) AS customer_count,
    AVG(recency_days) AS avg_recency_days,
    AVG(frequency) AS avg_frequency,
    AVG(monetary) AS avg_monetary,
    SUM(monetary) AS total_segment_revenue
FROM segmented_customers
GROUP BY customer_segmentation
ORDER BY total_segment_revenue DESC;

-- Query A2: Customer Lifetime Value (CLV) Calculation
-- Business Purpose: Calculate projected customer lifetime value for retention planning
WITH customer_metrics AS (
    SELECT 
        c.customer_key,
        c.customer_name,
        c.loyalty_member,
        COUNT(DISTINCT st.order_id) AS total_orders,
        SUM(st.total_revenue) AS total_revenue,
        AVG(st.total_revenue) AS avg_order_value,
        MIN(st.transaction_date) AS first_purchase_date,
        MAX(st.transaction_date) AS last_purchase_date,
        EXTRACT(DAY FROM (MAX(st.transaction_date) - MIN(st.transaction_date))) AS customer_lifespan_days
    FROM dim_customer c
    JOIN fact_sales_transactions st ON c.customer_key = st.customer_key
    WHERE st.transaction_type = 'Purchase'
    GROUP BY c.customer_key, c.customer_name, c.loyalty_member
),
clv_calculation AS (
    SELECT 
        *,
        -- Purchase frequency: total_orders / customer_lifespan_years
        CASE 
            WHEN customer_lifespan_days > 0 THEN 
                (total_orders / (customer_lifespan_days / 365.0))
            ELSE 0
        END AS purchase_frequency,
        -- Customer value: avg_order_value * avg_purchase_frequency
        avg_order_value AS customer_value
    FROM customer_metrics
)
SELECT 
    customer_key,
    customer_name,
    total_revenue,
    total_orders,
    avg_order_value,
    purchase_frequency,
    -- CLV formula: (Customer Value * Purchase Frequency) * Average Customer Lifespan
    CASE 
        WHEN customer_lifespan_days > 0 THEN
            (customer_value * purchase_frequency) * (customer_lifespan_days / 365.0) * 2  -- Assuming 2-year average lifespan
        ELSE 0
    END AS estimated_clv,
    CASE 
        WHEN customer_lifespan_days > 0 AND 
             (customer_value * purchase_frequency) * (customer_lifespan_days / 365.0) * 2 > 1000 
        THEN 'High Value' 
        WHEN customer_lifespan_days > 0 AND 
             (customer_value * purchase_frequency) * (customer_lifespan_days / 365.0) * 2 > 500 
        THEN 'Medium Value' 
        ELSE 'Low Value' 
    END AS clv_tier
FROM clv_calculation
ORDER BY estimated_clv DESC
LIMIT 20;

-- Query A3: Cohort Analysis (Customer Retention by Signup Month)
-- Business Purpose: Track customer retention rates by acquisition period
WITH cohort_analysis AS (
    SELECT 
        c.customer_key,
        DATE_TRUNC('month', c.registration_date)::DATE AS cohort_month,
        DATE_TRUNC('month', st.transaction_date)::DATE AS transaction_month,
        EXTRACT(YEAR FROM st.transaction_date) * 12 + EXTRACT(MONTH FROM st.transaction_date) - 
        EXTRACT(YEAR FROM c.registration_date) * 12 - EXTRACT(MONTH FROM c.registration_date) AS period_number
    FROM dim_customer c
    JOIN fact_sales_transactions st ON c.customer_key = st.customer_key
    WHERE st.transaction_type = 'Purchase'
),
cohort_size AS (
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_key) AS num_customers
    FROM cohort_analysis
    GROUP BY cohort_month
),
retention_analysis AS (
    SELECT 
        c.cohort_month,
        c.period_number,
        COUNT(DISTINCT c.customer_key) AS customers_retained
    FROM cohort_analysis c
    GROUP BY c.cohort_month, c.period_number
)
SELECT 
    cs.cohort_month,
    cs.num_customers AS initial_cohort_size,
    ROUND((ra0.customers_retained * 100.0 / cs.num_customers), 2) AS m0_retention_pct,
    ROUND((COALESCE(ra1.customers_retained, 0) * 100.0 / cs.num_customers), 2) AS m1_retention_pct,
    ROUND((COALESCE(ra2.customers_retained, 0) * 100.0 / cs.num_customers), 2) AS m2_retention_pct,
    ROUND((COALESCE(ra3.customers_retained, 0) * 100.0 / cs.num_customers), 2) AS m3_retention_pct,
    ROUND((COALESCE(ra4.customers_retained, 0) * 100.0 / cs.num_customers), 2) AS m4_retention_pct,
    ROUND((COALESCE(ra5.customers_retained, 0) * 100.0 / cs.num_customers), 2) AS m5_retention_pct
FROM cohort_size cs
LEFT JOIN retention_analysis ra0 ON cs.cohort_month = ra0.cohort_month AND ra0.period_number = 0
LEFT JOIN retention_analysis ra1 ON cs.cohort_month = ra1.cohort_month AND ra1.period_number = 1
LEFT JOIN retention_analysis ra2 ON cs.cohort_month = ra2.cohort_month AND ra2.period_number = 2
LEFT JOIN retention_analysis ra3 ON cs.cohort_month = ra3.cohort_month AND ra3.period_number = 3
LEFT JOIN retention_analysis ra4 ON cs.cohort_month = ra4.cohort_month AND ra4.period_number = 4
LEFT JOIN retention_analysis ra5 ON cs.cohort_month = ra5.cohort_month AND ra5.period_number = 5
ORDER BY cs.cohort_month;

-- Query A4: Customer Churn Prediction Indicators
-- Business Purpose: Identify customers at risk of churning based on behavioral indicators
WITH customer_behavior AS (
    SELECT 
        c.customer_key,
        c.customer_name,
        MAX(st.transaction_date) AS last_purchase_date,
        COUNT(st.sales_transaction_key) AS total_transactions,
        SUM(st.total_revenue) AS total_revenue,
        AVG(st.total_revenue) AS avg_transaction_value,
        -- Days since last purchase
        EXTRACT(DAY FROM (CURRENT_DATE - MAX(st.transaction_date))) AS days_since_last_purchase,
        -- Average time between purchases
        AVG(EXTRACT(DAY FROM (st.transaction_date - LAG(st.transaction_date) 
            OVER (PARTITION BY c.customer_key ORDER BY st.transaction_date)))) AS avg_days_between_purchases
    FROM dim_customer c
    JOIN fact_sales_transactions st ON c.customer_key = st.customer_key
    WHERE st.transaction_type = 'Purchase'
    GROUP BY c.customer_key, c.customer_name
),
churn_risk AS (
    SELECT 
        *,
        CASE 
            WHEN days_since_last_purchase > COALESCE(avg_days_between_purchases * 2, 365) THEN 'High Risk'
            WHEN days_since_last_purchase > COALESCE(avg_days_between_purchases * 1.5, 270) THEN 'Medium Risk'
            WHEN days_since_last_purchase > COALESCE(avg_days_between_purchases, 180) THEN 'Low Risk'
            ELSE 'Active'
        END AS churn_risk_level,
        -- Calculate trend in recent purchases
        ROW_NUMBER() OVER (PARTITION BY customer_key ORDER BY last_purchase_date DESC) AS purchase_rank
    FROM customer_behavior
)
SELECT 
    customer_key,
    customer_name,
    total_transactions,
    total_revenue,
    days_since_last_purchase,
    avg_days_between_purchases,
    churn_risk_level,
    CASE 
        WHEN churn_risk_level = 'High Risk' THEN 'Immediate outreach required'
        WHEN churn_risk_level = 'Medium Risk' THEN 'Targeted retention campaign'
        WHEN churn_risk_level = 'Low Risk' THEN 'Monitor engagement'
        ELSE 'Maintain regular communication'
    END AS recommended_action
FROM churn_risk
WHERE churn_risk_level IN ('High Risk', 'Medium Risk', 'Low Risk')
ORDER BY days_since_last_purchase DESC
LIMIT 25;

-- Query A5: Top Customers by Various Metrics
-- Business Purpose: Identify top customers across different business dimensions
WITH customer_metrics AS (
    SELECT 
        c.customer_key,
        c.customer_name,
        c.customer_segment,
        SUM(st.total_revenue) AS total_revenue,
        COUNT(DISTINCT st.order_id) AS total_orders,
        AVG(st.total_revenue) AS avg_order_value,
        COUNT(DISTINCT st.product_key) AS unique_products_purchased,
        AVG(st.customer_satisfaction_score) AS avg_satisfaction_score,
        MAX(st.transaction_date) AS last_purchase_date,
        COUNT(CASE WHEN st.is_return = TRUE THEN 1 END) AS return_count
    FROM dim_customer c
    JOIN fact_sales_transactions st ON c.customer_key = st.customer_key
    WHERE st.transaction_type = 'Purchase'
    GROUP BY c.customer_key, c.customer_name, c.customer_segment
)
SELECT 
    customer_key,
    customer_name,
    customer_segment,
    total_revenue,
    total_orders,
    avg_order_value,
    unique_products_purchased,
    avg_satisfaction_score,
    return_count,
    -- Revenue rank
    RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
    -- Order count rank
    RANK() OVER (ORDER BY total_orders DESC) AS order_count_rank,
    -- Product diversity rank
    RANK() OVER (ORDER BY unique_products_purchased DESC) AS product_diversity_rank
FROM customer_metrics
WHERE total_revenue > 0
ORDER BY total_revenue DESC
LIMIT 15;

-- ============================================================================
-- QUERY CATEGORY B: SALES ANALYTICS
-- ============================================================================

-- Query B1: Year-over-Year Sales Growth by Product Category
-- Business Purpose: Track performance trends across product categories
SELECT 
    dpt.product_category,
    dt.calendar_year,
    SUM(fst.total_revenue) AS total_revenue,
    COUNT(fst.sales_transaction_key) AS transaction_count,
    AVG(fst.total_revenue) AS avg_transaction_value,
    LAG(SUM(fst.total_revenue)) OVER (
        PARTITION BY dpt.product_category 
        ORDER BY dt.calendar_year
    ) AS prev_year_revenue,
    CASE 
        WHEN LAG(SUM(fst.total_revenue)) OVER (
            PARTITION BY dpt.product_category 
            ORDER BY dt.calendar_year
        ) > 0 THEN
            ROUND(
                (SUM(fst.total_revenue) - LAG(SUM(fst.total_revenue)) OVER (
                    PARTITION BY dpt.product_category 
                    ORDER BY dt.calendar_year
                )) * 100.0 / 
                LAG(SUM(fst.total_revenue)) OVER (
                    PARTITION BY dpt.product_category 
                    ORDER BY dt.calendar_year
                ), 2)
        ELSE NULL
    END AS yoy_growth_percent
FROM fact_sales_transactions fst
JOIN dim_product dpt ON fst.product_key = dpt.product_key
JOIN dim_time dt ON fst.time_key = dt.time_key
GROUP BY dpt.product_category, dt.calendar_year
HAVING dt.calendar_year >= 2023
ORDER BY dpt.product_category, dt.calendar_year;

-- Query B2: Month-over-Month Comparison with Percentage Change
-- Business Purpose: Analyze monthly performance trends with growth metrics
WITH monthly_sales AS (
    SELECT 
        dt.calendar_year,
        dt.calendar_month_number_in_year,
        dt.calendar_month_name,
        SUM(fst.total_revenue) AS monthly_revenue,
        COUNT(fst.sales_transaction_key) AS transaction_count,
        COUNT(DISTINCT fst.customer_key) AS unique_customers
    FROM fact_sales_transactions fst
    JOIN dim_time dt ON fst.time_key = dt.time_key
    WHERE fst.transaction_type = 'Purchase'
    GROUP BY dt.calendar_year, dt.calendar_month_number_in_year, dt.calendar_month_name
    ORDER BY dt.calendar_year, dt.calendar_month_number_in_year
),
mom_comparison AS (
    SELECT 
        *,
        LAG(monthly_revenue) OVER (ORDER BY calendar_year, calendar_month_number_in_year) AS prev_month_revenue,
        LAG(transaction_count) OVER (ORDER BY calendar_year, calendar_month_number_in_year) AS prev_month_transactions,
        LAG(unique_customers) OVER (ORDER BY calendar_year, calendar_month_number_in_year) AS prev_month_customers
    FROM monthly_sales
)
SELECT 
    calendar_year,
    calendar_month_name,
    monthly_revenue,
    transaction_count,
    unique_customers,
    prev_month_revenue,
    prev_month_transactions,
    prev_month_customers,
    CASE 
        WHEN prev_month_revenue > 0 THEN
            ROUND(((monthly_revenue - prev_month_revenue) * 100.0 / prev_month_revenue), 2)
        ELSE NULL
    END AS revenue_growth_percent,
    CASE 
        WHEN prev_month_transactions > 0 THEN
            ROUND(((transaction_count - prev_month_transactions) * 100.0 / prev_month_transactions), 2)
        ELSE NULL
    END AS transaction_growth_percent,
    CASE 
        WHEN prev_month_customers > 0 THEN
            ROUND(((unique_customers - prev_month_customers) * 100.0 / prev_month_customers), 2)
        ELSE NULL
    END AS customer_growth_percent
FROM mom_comparison
ORDER BY calendar_year, 
         CASE calendar_month_name
             WHEN 'January' THEN 1
             WHEN 'February' THEN 2
             WHEN 'March' THEN 3
             WHEN 'April' THEN 4
             WHEN 'May' THEN 5
             WHEN 'June' THEN 6
             WHEN 'July' THEN 7
             WHEN 'August' THEN 8
             WHEN 'September' THEN 9
             WHEN 'October' THEN 10
             WHEN 'November' THEN 11
             WHEN 'December' THEN 12
         END;

-- Query B3: Sales Funnel Conversion Analysis
-- Business Purpose: Track conversion rates from product view to purchase
WITH funnel_stages AS (
    SELECT 
        fw.event_date,
        fw.session_id,
        COUNT(CASE WHEN fw.event_type = 'page_view' THEN 1 END) AS viewed_product_count,
        COUNT(CASE WHEN fw.event_type = 'add_to_cart' THEN 1 END) AS added_to_cart_count,
        COUNT(CASE WHEN fw.event_type = 'checkout_start' THEN 1 END) AS checkout_started_count,
        COUNT(CASE WHEN fw.event_type = 'purchase' THEN 1 END) AS purchased_count
    FROM fact_web_events fw
    WHERE fw.event_type IN ('page_view', 'add_to_cart', 'checkout_start', 'purchase')
    GROUP BY fw.event_date, fw.session_id
),
funnel_summary AS (
    SELECT 
        COUNT(DISTINCT session_id) AS total_sessions,
        COUNT(DISTINCT CASE WHEN viewed_product_count > 0 THEN session_id END) AS visited_product_pages,
        COUNT(DISTINCT CASE WHEN added_to_cart_count > 0 THEN session_id END) AS added_to_cart,
        COUNT(DISTINCT CASE WHEN checkout_started_count > 0 THEN session_id END) AS started_checkout,
        COUNT(DISTINCT CASE WHEN purchased_count > 0 THEN session_id END) AS completed_purchase
    FROM funnel_stages
)
SELECT 
    total_sessions,
    visited_product_pages,
    ROUND((visited_product_pages * 100.0 / total_sessions), 2) AS visit_to_product_view_rate,
    added_to_cart,
    ROUND((added_to_cart * 100.0 / visited_product_pages), 2) AS product_view_to_cart_rate,
    started_checkout,
    ROUND((started_checkout * 100.0 / added_to_cart), 2) AS cart_to_checkout_rate,
    completed_purchase,
    ROUND((completed_purchase * 100.0 / started_checkout), 2) AS checkout_to_purchase_rate,
    ROUND((completed_purchase * 100.0 / total_sessions), 2) AS overall_conversion_rate
FROM funnel_summary;

-- Query B4: Cart Abandonment Rate Calculation
-- Business Purpose: Measure and analyze cart abandonment to improve conversion
WITH cart_analysis AS (
    SELECT 
        DATE_TRUNC('month', fw.event_date)::DATE AS month_year,
        fw.session_id,
        COUNT(CASE WHEN fw.event_type = 'add_to_cart' THEN 1 END) AS cart_additions,
        COUNT(CASE WHEN fw.event_type = 'checkout_start' THEN 1 END) AS checkout_starts,
        COUNT(CASE WHEN fw.event_type = 'purchase' THEN 1 END) AS purchases,
        -- Mark sessions that have cart additions but no purchases
        CASE 
            WHEN COUNT(CASE WHEN fw.event_type = 'add_to_cart' THEN 1 END) > 0 
                 AND COUNT(CASE WHEN fw.event_type = 'purchase' THEN 1 END) = 0 
            THEN 1 ELSE 0 
        END AS abandoned_cart_session
    FROM fact_web_events fw
    WHERE fw.event_type IN ('add_to_cart', 'checkout_start', 'purchase')
    GROUP BY DATE_TRUNC('month', fw.event_date), fw.session_id
),
monthly_cart_metrics AS (
    SELECT 
        month_year,
        COUNT(session_id) AS total_sessions_with_cart_activity,
        COUNT(CASE WHEN cart_additions > 0 THEN 1 END) AS sessions_with_cart_additions,
        COUNT(CASE WHEN purchases > 0 THEN 1 END) AS sessions_with_purchases,
        COUNT(CASE WHEN abandoned_cart_session = 1 THEN 1 END) AS abandoned_cart_sessions,
        SUM(cart_additions) AS total_cart_additions,
        SUM(purchases) AS total_purchases
    FROM cart_analysis
    GROUP BY month_year
)
SELECT 
    month_year,
    total_cart_additions,
    total_purchases,
    abandoned_cart_sessions,
    sessions_with_cart_additions,
    ROUND((abandoned_cart_sessions * 100.0 / sessions_with_cart_additions), 2) AS cart_abandonment_rate,
    ROUND((total_purchases * 100.0 / total_cart_additions), 2) AS cart_to_purchase_conversion_rate
FROM monthly_cart_metrics
ORDER BY month_year;

-- Query B5: Revenue Trending and Forecasting Indicators
-- Business Purpose: Analyze revenue trends and identify forecasting patterns
WITH revenue_by_period AS (
    SELECT 
        dt.date_value,
        dt.calendar_year,
        dt.calendar_month_number_in_year,
        dt.calendar_month_name,
        dt.day_number_in_year,
        SUM(COALESCE(fst.total_revenue, 0)) AS daily_revenue
    FROM dim_time dt
    LEFT JOIN fact_sales_transactions fst ON dt.time_key = fst.time_key
    WHERE dt.date_value >= '2024-01-01' AND dt.date_value <= '2024-12-31'
    GROUP BY dt.date_value, dt.calendar_year, dt.calendar_month_number_in_year, dt.calendar_month_name, dt.day_number_in_year
),
revenue_with_lag AS (
    SELECT 
        *,
        -- 7-day moving average
        AVG(daily_revenue) OVER (
            ORDER BY date_value 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS seven_day_moving_avg,
        -- 30-day moving average
        AVG(daily_revenue) OVER (
            ORDER BY date_value 
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) AS thirty_day_moving_avg,
        -- Previous week revenue for comparison
        LAG(daily_revenue, 7) OVER (ORDER BY date_value) AS prev_week_revenue,
        -- Revenue 4 weeks ago (seasonal comparison)
        LAG(daily_revenue, 28) OVER (ORDER BY date_value) AS four_weeks_ago_revenue
    FROM revenue_by_period
)
SELECT 
    date_value,
    daily_revenue,
    ROUND(seven_day_moving_avg, 2) AS seven_day_moving_avg,
    ROUND(thirty_day_moving_avg, 2) AS thirty_day_moving_avg,
    prev_week_revenue,
    four_weeks_ago_revenue,
    CASE 
        WHEN prev_week_revenue IS NOT NULL AND prev_week_revenue > 0 THEN
            ROUND(((daily_revenue - prev_week_revenue) * 100.0 / prev_week_revenue), 2)
        ELSE NULL
    END AS wow_growth_percent,
    CASE 
        WHEN four_weeks_ago_revenue IS NOT NULL AND four_weeks_ago_revenue > 0 THEN
            ROUND(((daily_revenue - four_weeks_ago_revenue) * 100.0 / four_weeks_ago_revenue), 2)
        ELSE NULL
    END AS yoy_growth_percent
FROM revenue_with_lag
WHERE date_value >= '2024-02-01'  -- After first 30 days for moving averages
ORDER BY date_value;

-- ============================================================================
-- QUERY CATEGORY C: PRODUCT ANALYTICS
-- ============================================================================

-- Query C1: Best/Worst Performing Products
-- Business Purpose: Identify top and bottom performing products for inventory and marketing decisions
SELECT 
    dp.product_name,
    dp.product_category,
    dp.product_brand,
    SUM(fst.quantity_sold) AS total_quantity_sold,
    SUM(fst.total_revenue) AS total_revenue,
    SUM(fst.total_profit) AS total_profit,
    COUNT(DISTINCT fst.order_id) AS unique_orders,
    AVG(fst.total_revenue) AS avg_revenue_per_transaction,
    AVG(fst.review_rating) AS avg_review_rating,
    COUNT(CASE WHEN fst.review_rating IS NOT NULL THEN 1 END) AS review_count,
    -- Profit margin
    CASE 
        WHEN SUM(fst.total_revenue) > 0 THEN
            ROUND((SUM(fst.total_profit) * 100.0 / SUM(fst.total_revenue)), 2)
        ELSE 0
    END AS profit_margin_percent,
    -- Ranking
    RANK() OVER (ORDER BY SUM(fst.total_revenue) DESC) AS revenue_rank,
    RANK() OVER (ORDER BY SUM(fst.total_profit) DESC) AS profit_rank,
    RANK() OVER (ORDER BY SUM(fst.quantity_sold) DESC) AS quantity_rank
FROM dim_product dp
JOIN fact_sales_transactions fst ON dp.product_key = fst.product_key
WHERE fst.transaction_type = 'Purchase'
GROUP BY dp.product_key, dp.product_name, dp.product_category, dp.product_brand
HAVING SUM(fst.total_revenue) > 0
ORDER BY total_revenue DESC
LIMIT 20;

-- Query C2: Product Affinity Analysis (Frequently Bought Together)
-- Business Purpose: Identify products that are frequently purchased together for cross-selling
WITH order_products AS (
    SELECT 
        fst.order_id,
        fst.customer_key,
        dp.product_name,
        dp.product_category,
        fst.product_key
    FROM fact_sales_transactions fst
    JOIN dim_product dp ON fst.product_key = dp.product_key
    WHERE fst.transaction_type = 'Purchase'
),
product_pairs AS (
    SELECT 
        op1.product_name AS product_a,
        op1.product_category AS category_a,
        op2.product_name AS product_b,
        op2.product_category AS category_b,
        op1.product_key AS key_a,
        op2.product_key AS key_b,
        COUNT(*) AS co_occurrence_count
    FROM order_products op1
    JOIN order_products op2 ON op1.order_id = op2.order_id AND op1.product_key < op2.product_key
    GROUP BY op1.product_name, op1.product_category, op2.product_name, op2.product_category, op1.product_key, op2.product_key
    HAVING COUNT(*) >= 2  -- Only pairs that appear together at least twice
)
SELECT 
    product_a,
    category_a,
    product_b,
    category_b,
    co_occurrence_count,
    -- Calculate affinity score (how frequently they appear together relative to individual popularity)
    (co_occurrence_count * 100.0 / 
        (SELECT COUNT(*) FROM order_products WHERE product_key = key_a)) AS a_to_b_affinity_percent,
    (co_occurrence_count * 100.0 / 
        (SELECT COUNT(*) FROM order_products WHERE product_key = key_b)) AS b_to_a_affinity_percent
FROM product_pairs
ORDER BY co_occurrence_count DESC, product_a, product_b
LIMIT 25;

-- Query C3: Inventory Turnover Calculations
-- Business Purpose: Analyze inventory efficiency and optimize stock levels
WITH product_sales_summary AS (
    SELECT 
        dp.product_key,
        dp.product_name,
        dp.product_category,
        dp.base_price,
        dp.cost_price,
        SUM(fst.quantity_sold) AS total_quantity_sold,
        SUM(fst.total_cost) AS total_cost_of_goods_sold,
        AVG(fst.total_revenue) AS avg_selling_price,
        COUNT(DISTINCT fst.order_id) AS total_orders,
        MIN(fst.transaction_date) AS first_sale_date,
        MAX(fst.transaction_date) AS last_sale_date
    FROM dim_product dp
    LEFT JOIN fact_sales_transactions fst ON dp.product_key = fst.product_key
    WHERE fst.transaction_type = 'Purchase' OR fst IS NULL
    GROUP BY dp.product_key, dp.product_name, dp.product_category, dp.base_price, dp.cost_price
),
inventory_analysis AS (
    SELECT 
        *,
        -- Assumed average inventory (in real world, this would come from inventory table)
        (total_quantity_sold / 4) AS assumed_avg_inventory, -- Simplified: 3 months of average sales
        CASE 
            WHEN (total_quantity_sold / 4) > 0 THEN
                total_quantity_sold / (total_quantity_sold / 4)  -- COGS / Avg Inventory
            ELSE 0
        END AS inventory_turnover_ratio,
        CASE 
            WHEN total_quantity_sold > 0 THEN
                365 / (total_quantity_sold / (total_quantity_sold / 4))  -- 365 / Turnover Ratio
            ELSE NULL
        END AS days_to_turn_inventory,
        -- Calculate days on market
        CASE 
            WHEN first_sale_date IS NOT NULL THEN
                EXTRACT(DAY FROM (last_sale_date - first_sale_date))
            ELSE 0
        END AS days_on_market
    FROM product_sales_summary
)
SELECT 
    product_name,
    product_category,
    total_quantity_sold,
    total_cost_of_goods_sold,
    inventory_turnover_ratio,
    days_to_turn_inventory,
    CASE 
        WHEN inventory_turnover_ratio >= 12 THEN 'Fast Moving'
        WHEN inventory_turnover_ratio >= 6 THEN 'Medium Moving'
        WHEN inventory_turnover_ratio >= 2 THEN 'Slow Moving'
        ELSE 'Dead Stock'
    END AS inventory_classification,
    total_orders
FROM inventory_analysis
WHERE total_quantity_sold > 0  -- Only products that have been sold
ORDER BY inventory_turnover_ratio DESC
LIMIT 20;

-- Query C4: Product Category Performance Comparison
-- Business Purpose: Compare performance across different product categories
SELECT 
    dp.product_category,
    COUNT(DISTINCT dp.product_key) AS product_count,
    SUM(fst.total_revenue) AS total_category_revenue,
    SUM(fst.total_profit) AS total_category_profit,
    SUM(fst.quantity_sold) AS total_category_quantity_sold,
    COUNT(DISTINCT fst.order_id) AS unique_orders,
    AVG(fst.total_revenue) AS avg_transaction_value,
    AVG(fst.review_rating) AS avg_category_rating,
    -- Profit margin by category
    CASE 
        WHEN SUM(fst.total_revenue) > 0 THEN
            ROUND((SUM(fst.total_profit) * 100.0 / SUM(fst.total_revenue)), 2)
        ELSE 0
    END AS category_profit_margin_percent,
    -- Revenue per product
    ROUND(SUM(fst.total_revenue) / COUNT(DISTINCT dp.product_key), 2) AS revenue_per_product,
    -- Quantity sold per product
    ROUND(SUM(fst.quantity_sold) / COUNT(DISTINCT dp.product_key), 2) AS quantity_per_product,
    -- Market share by revenue
    ROUND((SUM(fst.total_revenue) * 100.0 / 
        (SELECT SUM(total_revenue) FROM fact_sales_transactions WHERE transaction_type = 'Purchase')), 2) AS market_share_percent
FROM dim_product dp
JOIN fact_sales_transactions fst ON dp.product_key = fst.product_key
WHERE fst.transaction_type = 'Purchase'
GROUP BY dp.product_category
HAVING SUM(fst.total_revenue) > 0
ORDER BY total_category_revenue DESC;

-- Query C5: Cross-sell and Upsell Opportunity Identification
-- Business Purpose: Identify opportunities to increase average order value
WITH customer_purchase_history AS (
    SELECT 
        fst.customer_key,
        fst.product_key,
        dp.product_category,
        dp.product_name,
        SUM(fst.total_revenue) AS total_spent,
        SUM(fst.quantity_sold) AS total_quantity,
        AVG(fst.review_rating) AS avg_rating,
        COUNT(DISTINCT fst.order_id) AS order_frequency,
        MAX(fst.transaction_date) AS last_purchase_date
    FROM fact_sales_transactions fst
    JOIN dim_product dp ON fst.product_key = dp.product_key
    WHERE fst.transaction_type = 'Purchase'
    GROUP BY fst.customer_key, fst.product_key, dp.product_category, dp.product_name
),
potential_upsell_customers AS (
    SELECT 
        cph.customer_key,
        cph.product_category,
        cph.product_name,
        cph.total_spent,
        c.customer_segment,
        -- Identify customers who might be interested in premium versions
        CASE 
            WHEN dp.category_ranking < 50 AND c.loyalty_member = TRUE THEN 'Premium Upgrade'
            WHEN cph.order_frequency >= 5 THEN 'Frequent Buyer'
            WHEN cph.total_spent > 500 THEN 'High Value'
            ELSE 'Standard'
        END AS customer_type
    FROM customer_purchase_history cph
    JOIN dim_customer c ON cph.customer_key = c.customer_key
    JOIN dim_product dp ON cph.product_key = dp.product_key
)
SELECT 
    customer_type,
    COUNT(DISTINCT customer_key) AS customer_count,
    AVG(total_spent) AS avg_spent_per_customer,
    COUNT(*) AS total_product_interactions,
    -- Potential revenue opportunity
    SUM(total_spent) AS total_revenue_from_segment,
    -- Opportunity for cross-sell/upsell
    CASE 
        WHEN customer_type = 'Premium Upgrade' THEN 'Recommend premium products'
        WHEN customer_type = 'Frequent Buyer' THEN 'Suggest related accessories'
        WHEN customer_type = 'High Value' THEN 'Offer loyalty rewards'
        ELSE 'Standard recommendations'
    END AS recommended_strategy
FROM potential_upsell_customers
GROUP BY customer_type
ORDER BY total_revenue_from_segment DESC;

-- ============================================================================
-- QUERY CATEGORY D: MARKETING ANALYTICS
-- ============================================================================

-- Query D1: Multi-touch Attribution Modeling
-- Business Purpose: Understand marketing channel contribution to conversions
WITH customer_journey AS (
    SELECT 
        fw.customer_key,
        fw.session_id,
        fw.event_date,
        fw.event_type,
        fw.marketing_channel_key,
        dmc.channel_name,
        dmc.channel_type,
        -- Assign touchpoint weight based on position in journey
        ROW_NUMBER() OVER (PARTITION BY fw.customer_key, fw.session_id ORDER BY fw.event_time) AS touchpoint_order,
        COUNT(*) OVER (PARTITION BY fw.customer_key, fw.session_id) AS total_touchpoints_in_journey
    FROM fact_web_events fw
    JOIN dim_marketing_channel dmc ON fw.marketing_channel_key = dmc.marketing_channel_key
    WHERE fw.event_type IN ('page_view', 'add_to_cart', 'checkout_start', 'purchase')
),
conversion_touchpoints AS (
    SELECT 
        cj.customer_key,
        cj.session_id,
        cj.event_date,
        cj.marketing_channel_key,
        cj.channel_name,
        cj.channel_type,
        cj.touchpoint_order,
        cj.total_touchpoints_in_journey,
        -- Identify if this touchpoint led to a conversion
        CASE WHEN EXISTS (
            SELECT 1 FROM fact_web_events fw2 
            WHERE fw2.customer_key = cj.customer_key 
            AND fw2.session_id = cj.session_id 
            AND fw2.event_type = 'purchase'
        ) THEN 1 ELSE 0 END AS led_to_conversion
    FROM customer_journey cj
),
attribution_analysis AS (
    SELECT 
        channel_name,
        channel_type,
        COUNT(*) AS total_touchpoints,
        COUNT(CASE WHEN led_to_conversion = 1 THEN 1 END) AS conversion_touchpoints,
        -- Last touch attribution (common model)
        COUNT(CASE WHEN touchpoint_order = total_touchpoints_in_journey AND led_to_conversion = 1 THEN 1 END) AS last_touch_conversions,
        -- First touch attribution
        COUNT(CASE WHEN touchpoint_order = 1 AND led_to_conversion = 1 THEN 1 END) AS first_touch_conversions,
        -- Linear attribution (equal credit to all touchpoints in conversion journey)
        COUNT(CASE WHEN led_to_conversion = 1 THEN 1 END) / 
        NULLIF(AVG(CASE WHEN led_to_conversion = 1 THEN total_touchpoints_in_journey END), 0) AS linear_attribution_score
    FROM conversion_touchpoints
    GROUP BY channel_name, channel_type
)
SELECT 
    channel_name,
    channel_type,
    total_touchpoints,
    conversion_touchpoints,
    last_touch_conversions,
    first_touch_conversions,
    ROUND(linear_attribution_score, 2) AS linear_attribution_score,
    ROUND((last_touch_conversions * 100.0 / NULLIF(conversion_touchpoints, 0)), 2) AS last_touch_conversion_rate,
    ROUND((first_touch_conversions * 100.0 / NULLIF(conversion_touchpoints, 0)), 2) AS first_touch_conversion_rate
FROM attribution_analysis
ORDER BY total_touchpoints DESC;

-- Query D2: Marketing Channel ROI Analysis
-- Business Purpose: Measure return on investment for different marketing channels
SELECT 
    dmc.channel_name,
    dmc.channel_type,
    dmc.campaign_type,
    dmc.cost_per_click,
    COUNT(fst.sales_transaction_key) AS total_conversions,
    SUM(fst.total_revenue) AS total_revenue_from_channel,
    SUM(fst.total_profit) AS total_profit_from_channel,
    AVG(fst.total_revenue) AS avg_revenue_per_conversion,
    -- Calculate marketing cost (simplified - in real world, would come from marketing cost tables)
    COUNT(fst.sales_transaction_key) * AVG(dmc.cost_per_click) AS estimated_marketing_cost,
    -- ROI calculation
    CASE 
        WHEN COUNT(fst.sales_transaction_key) * AVG(dmc.cost_per_click) > 0 THEN
            ROUND((SUM(fst.total_revenue) - (COUNT(fst.sales_transaction_key) * AVG(dmc.cost_per_click))) * 100.0 / 
                  (COUNT(fst.sales_transaction_key) * AVG(dmc.cost_per_click)), 2)
        ELSE NULL
    END AS roi_percent,
    -- Revenue per marketing dollar spent
    CASE 
        WHEN COUNT(fst.sales_transaction_key) * AVG(dmc.cost_per_click) > 0 THEN
            ROUND(SUM(fst.total_revenue) / (COUNT(fst.sales_transaction_key) * AVG(dmc.cost_per_click)), 2)
        ELSE NULL
    END AS revenue_per_dollar_spent,
    -- Profit margin for channel-specific sales
    CASE 
        WHEN SUM(fst.total_revenue) > 0 THEN
            ROUND(SUM(fst.total_profit) * 100.0 / SUM(fst.total_revenue), 2)
        ELSE 0
    END AS channel_profit_margin
FROM fact_sales_transactions fst
JOIN dim_marketing_channel dmc ON fst.marketing_channel_key = dmc.marketing_channel_key
WHERE fst.transaction_type = 'Purchase'
GROUP BY dmc.channel_name, dmc.channel_type, dmc.campaign_type, dmc.cost_per_click
HAVING COUNT(fst.sales_transaction_key) > 0
ORDER BY total_revenue_from_channel DESC;

-- Query D3: Campaign Performance Metrics
-- Business Purpose: Evaluate effectiveness of marketing campaigns
SELECT 
    dmc.channel_name,
    dmc.campaign_type,
    dmc.target_audience,
    COUNT(DISTINCT fst.customer_key) AS unique_customers_reached,
    COUNT(fst.sales_transaction_key) AS total_transactions,
    SUM(fst.total_revenue) AS total_revenue,
    SUM(fst.total_profit) AS total_profit,
    -- Conversion rate (assuming we can identify campaign-driven sessions in web events)
    (SELECT COUNT(DISTINCT fw.session_id) 
     FROM fact_web_events fw 
     JOIN dim_marketing_channel dmc2 ON fw.marketing_channel_key = dmc2.marketing_channel_key
     WHERE dmc2.channel_name = dmc.channel_name AND fw.event_type = 'purchase'
    ) AS campaign_driven_purchases,
    -- Average order value for campaign
    AVG(fst.total_revenue) AS avg_order_value,
    -- Customer acquisition metrics
    COUNT(DISTINCT fst.customer_key) AS new_customers_acquired,
    -- Channel effectiveness score
    CASE 
        WHEN COUNT(DISTINCT fst.customer_key) > 0 THEN
            ROUND(SUM(fst.total_revenue) / COUNT(DISTINCT fst.customer_key), 2)
        ELSE 0
    END AS revenue_per_customer
FROM fact_sales_transactions fst
JOIN dim_marketing_channel dmc ON fst.marketing_channel_key = dmc.marketing_channel_key
WHERE fst.transaction_type = 'Purchase'
GROUP BY dmc.channel_name, dmc.campaign_type, dmc.target_audience
HAVING COUNT(fst.sales_transaction_key) > 0
ORDER BY total_revenue DESC;

-- Query D4: Customer Acquisition Cost by Channel
-- Business Purpose: Measure cost efficiency of customer acquisition by marketing channel
WITH first_time_customers AS (
    SELECT 
        fst.customer_key,
        fst.marketing_channel_key,
        fst.transaction_date,
        fst.total_revenue,
        ROW_NUMBER() OVER (PARTITION BY fst.customer_key ORDER BY fst.transaction_date) AS purchase_order
    FROM fact_sales_transactions fst
    WHERE fst.transaction_type = 'Purchase'
),
acquisition_metrics AS (
    SELECT 
        ftc.marketing_channel_key,
        dmc.channel_name,
        dmc.channel_type,
        COUNT(ftc.customer_key) AS new_customers_acquired,
        SUM(ftc.total_revenue) AS revenue_from_new_customers,
        -- Assuming cost based on click-based attribution for first-time customers
        COUNT(ftc.customer_key) * AVG(dmc.cost_per_click) AS estimated_acquisition_cost
    FROM first_time_customers ftc
    JOIN dim_marketing_channel dmc ON ftc.marketing_channel_key = dmc.marketing_channel_key
    WHERE ftc.purchase_order = 1  -- First purchase
    GROUP BY ftc.marketing_channel_key, dmc.channel_name, dmc.channel_type
)
SELECT 
    channel_name,
    channel_type,
    new_customers_acquired,
    revenue_from_new_customers,
    ROUND(estimated_acquisition_cost, 2) AS total_acquisition_cost,
    CASE 
        WHEN new_customers_acquired > 0 THEN
            ROUND(estimated_acquisition_cost / new_customers_acquired, 2)
        ELSE 0
    END AS cac_per_customer,
    CASE 
        WHEN new_customers_acquired > 0 THEN
            ROUND(revenue_from_new_customers / new_customers_acquired, 2)
        ELSE 0
    END AS revenue_per_acquired_customer,
    CASE 
        WHEN estimated_acquisition_cost > 0 THEN
            ROUND((revenue_from_new_customers - estimated_acquisition_cost) * 100.0 / estimated_acquisition_cost, 2)
        ELSE 0
    END AS roi_on_acquisition
FROM acquisition_metrics
ORDER BY cac_per_customer ASC;  -- Order by most cost-effective channels first