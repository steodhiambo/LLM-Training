-- ============================================================================
-- E-COMMERCE ANALYTICS & CUSTOMER INTELLIGENCE PLATFORM
-- COMPLEX SQL QUERIES PART 2 - ADVANCED TECHNIQUES
-- Author: SQL Developer Portfolio
-- Date: 2025-01-04
-- Description: Additional complex queries demonstrating advanced SQL techniques
-- ============================================================================

-- ============================================================================
-- ADVANCED SQL TECHNIQUES DEMONSTRATION
-- ============================================================================

-- Query D5: Advanced Window Functions with Custom Frames
-- Business Purpose: Calculate running averages and trend analysis for sales forecasting
WITH daily_sales_with_trends AS (
    SELECT 
        dt.date_value,
        dt.calendar_month_name,
        dt.day_name_of_week,
        SUM(fst.total_revenue) AS daily_revenue,
        COUNT(fst.sales_transaction_key) AS daily_transactions,
        -- 7-day running total
        SUM(SUM(fst.total_revenue)) OVER (
            ORDER BY dt.date_value 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS seven_day_revenue_total,
        -- 7-day running average
        AVG(SUM(fst.total_revenue)) OVER (
            ORDER BY dt.date_value 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS seven_day_revenue_avg,
        -- 30-day running average
        AVG(SUM(fst.total_revenue)) OVER (
            ORDER BY dt.date_value 
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) AS thirty_day_revenue_avg,
        -- Revenue difference from 30-day average
        SUM(fst.total_revenue) - AVG(SUM(fst.total_revenue)) OVER (
            ORDER BY dt.date_value 
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) AS revenue_diff_from_avg,
        -- Percentage above/below average
        CASE 
            WHEN AVG(SUM(fst.total_revenue)) OVER (
                ORDER BY dt.date_value 
                ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
            ) > 0 THEN
                ROUND(
                    (SUM(fst.total_revenue) - AVG(SUM(fst.total_revenue)) OVER (
                        ORDER BY dt.date_value 
                        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
                    )) * 100.0 / 
                    AVG(SUM(fst.total_revenue)) OVER (
                        ORDER BY dt.date_value 
                        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
                    ), 2
                )
            ELSE 0
        END AS pct_diff_from_avg
    FROM dim_time dt
    LEFT JOIN fact_sales_transactions fst ON dt.time_key = fst.time_key
    WHERE dt.date_value >= '2024-01-01' AND dt.date_value <= '2024-12-31'
    GROUP BY dt.date_value, dt.calendar_month_name, dt.day_name_of_week
)
SELECT 
    date_value,
    daily_revenue,
    daily_transactions,
    seven_day_revenue_avg,
    thirty_day_revenue_avg,
    revenue_diff_from_avg,
    pct_diff_from_avg,
    -- Identify trend direction
    CASE 
        WHEN seven_day_revenue_avg > thirty_day_revenue_avg THEN 'UPWARD_TREND'
        WHEN seven_day_revenue_avg < thirty_day_revenue_avg THEN 'DOWNWARD_TREND'
        ELSE 'STABLE'
    END AS trend_direction,
    -- Flag unusual days (more than 20% above/below average)
    CASE 
        WHEN ABS(pct_diff_from_avg) > 20 THEN 'UNUSUAL'
        ELSE 'NORMAL'
    END AS day_type
FROM daily_sales_with_trends
WHERE date_value >= '2024-02-01'  -- After initial windows are filled
ORDER BY date_value;

-- Query D6: Complex CTE with Recursive Elements
-- Business Purpose: Find hierarchical product relationships for recommendation engine
WITH RECURSIVE category_hierarchy AS (
    -- Base case: Top level categories
    SELECT 
        product_category AS node_name,
        product_category AS root_category,
        1 AS level,
        ARRAY[product_category] AS path
    FROM dim_product
    WHERE product_category IS NOT NULL
    GROUP BY product_category
    
    UNION ALL
    
    -- Recursive case: Subcategories (simplified for this example)
    SELECT 
        dp.product_subcategory AS node_name,
        ch.root_category,
        ch.level + 1 AS level,
        ch.path || dp.product_subcategory AS path
    FROM dim_product dp
    JOIN category_hierarchy ch ON ch.node_name = dp.product_category
    WHERE dp.product_subcategory IS NOT NULL AND ch.level < 3  -- Limit depth
),
product_relationships AS (
    SELECT 
        p1.product_key AS product_a_key,
        p1.product_name AS product_a_name,
        p1.product_category AS category_a,
        p2.product_key AS product_b_key,
        p2.product_name AS product_b_name,
        p2.product_category AS category_b,
        COUNT(fst1.order_id) AS co_purchase_count
    FROM dim_product p1
    JOIN fact_sales_transactions fst1 ON p1.product_key = fst1.product_key
    JOIN fact_sales_transactions fst2 ON fst1.order_id = fst2.order_id AND fst1.product_key != fst2.product_key
    JOIN dim_product p2 ON fst2.product_key = p2.product_key
    WHERE fst1.transaction_type = 'Purchase' AND fst2.transaction_type = 'Purchase'
    GROUP BY p1.product_key, p1.product_name, p1.product_category, p2.product_key, p2.product_name, p2.product_category
    HAVING COUNT(fst1.order_id) >= 3  -- At least 3 times purchased together
)
SELECT 
    pr.product_a_name,
    pr.category_a,
    pr.product_b_name,
    pr.category_b,
    pr.co_purchase_count,
    -- Calculate relationship strength
    ROUND(pr.co_purchase_count * 100.0 / (
        SELECT COUNT(*) 
        FROM fact_sales_transactions fst 
        WHERE fst.product_key = pr.product_a_key
    ), 2) AS pct_of_a_purchases_with_b,
    ROUND(pr.co_purchase_count * 100.0 / (
        SELECT COUNT(*) 
        FROM fact_sales_transactions fst 
        WHERE fst.product_key = pr.product_b_key
    ), 2) AS pct_of_b_purchases_with_a
FROM product_relationships pr
ORDER BY pr.co_purchase_count DESC
LIMIT 20;

-- Query D7: Advanced Subqueries and Correlated Analysis
-- Business Purpose: Identify customers with unusual spending patterns compared to peers
WITH customer_stats AS (
    SELECT 
        c.customer_key,
        c.customer_name,
        c.customer_segment,
        c.geography_key,
        dg.country_name,
        dg.region_name,
        SUM(fst.total_revenue) AS total_spending,
        COUNT(fst.sales_transaction_key) AS transaction_count,
        AVG(fst.total_revenue) AS avg_transaction_value,
        COUNT(DISTINCT fst.product_key) AS unique_products_bought,
        -- Customer tenure in months
        EXTRACT(MONTH FROM (MAX(fst.transaction_date) - MIN(fst.transaction_date))) + 
        (EXTRACT(YEAR FROM MAX(fst.transaction_date)) - EXTRACT(YEAR FROM MIN(fst.transaction_date))) * 12 AS tenure_months
    FROM dim_customer c
    JOIN dim_geography dg ON c.geography_key = dg.geography_key
    JOIN fact_sales_transactions fst ON c.customer_key = fst.customer_key
    WHERE fst.transaction_type = 'Purchase'
    GROUP BY c.customer_key, c.customer_name, c.customer_segment, c.geography_key, dg.country_name, dg.region_name
),
segment_benchmarks AS (
    SELECT 
        customer_segment,
        country_name,
        AVG(total_spending) AS segment_avg_spending,
        AVG(transaction_count) AS segment_avg_transactions,
        AVG(avg_transaction_value) AS segment_avg_atv,
        AVG(unique_products_bought) AS segment_avg_unique_products
    FROM customer_stats
    GROUP BY customer_segment, country_name
)
SELECT 
    cs.customer_name,
    cs.customer_segment,
    cs.country_name,
    cs.total_spending,
    cs.transaction_count,
    cs.avg_transaction_value,
    cs.unique_products_bought,
    sb.segment_avg_spending,
    sb.segment_avg_transactions,
    sb.segment_avg_atv,
    -- Identify significant deviations from segment norms (more than 50% different)
    CASE 
        WHEN ABS(cs.total_spending - sb.segment_avg_spending) > sb.segment_avg_spending * 0.5 THEN 'SIGNIFICANT_DEVIATION'
        ELSE 'WITHIN_NORM'
    END AS spending_pattern,
    ROUND(cs.total_spending * 100.0 / sb.segment_avg_spending, 2) AS spending_ratio_to_segment
FROM customer_stats cs
JOIN segment_benchmarks sb ON cs.customer_segment = sb.customer_segment AND cs.country_name = sb.country_name
WHERE cs.tenure_months >= 3  -- Only customers with at least 3 months history
ORDER BY ABS(cs.total_spending - sb.segment_avg_spending) DESC
LIMIT 15;

-- Query D8: PIVOT Operation for Multi-Dimensional Analysis
-- Business Purpose: Create a pivot table showing revenue by product category and month
WITH monthly_category_revenue AS (
    SELECT 
        dp.product_category,
        dt.calendar_month_name,
        dt.calendar_year,
        SUM(fst.total_revenue) AS monthly_revenue
    FROM dim_product dp
    JOIN fact_sales_transactions fst ON dp.product_key = fst.product_key
    JOIN dim_time dt ON fst.time_key = dt.time_key
    WHERE fst.transaction_type = 'Purchase'
    GROUP BY dp.product_category, dt.calendar_month_name, dt.calendar_year
),
pivot_data AS (
    SELECT 
        product_category,
        calendar_year,
        SUM(CASE WHEN calendar_month_name = 'January' THEN monthly_revenue ELSE 0 END) AS Jan_Revenue,
        SUM(CASE WHEN calendar_month_name = 'February' THEN monthly_revenue ELSE 0 END) AS Feb_Revenue,
        SUM(CASE WHEN calendar_month_name = 'March' THEN monthly_revenue ELSE 0 END) AS Mar_Revenue,
        SUM(CASE WHEN calendar_month_name = 'April' THEN monthly_revenue ELSE 0 END) AS Apr_Revenue,
        SUM(CASE WHEN calendar_month_name = 'May' THEN monthly_revenue ELSE 0 END) AS May_Revenue,
        SUM(CASE WHEN calendar_month_name = 'June' THEN monthly_revenue ELSE 0 END) AS Jun_Revenue,
        SUM(CASE WHEN calendar_month_name = 'July' THEN monthly_revenue ELSE 0 END) AS Jul_Revenue,
        SUM(CASE WHEN calendar_month_name = 'August' THEN monthly_revenue ELSE 0 END) AS Aug_Revenue,
        SUM(CASE WHEN calendar_month_name = 'September' THEN monthly_revenue ELSE 0 END) AS Sep_Revenue,
        SUM(CASE WHEN calendar_month_name = 'October' THEN monthly_revenue ELSE 0 END) AS Oct_Revenue,
        SUM(CASE WHEN calendar_month_name = 'November' THEN monthly_revenue ELSE 0 END) AS Nov_Revenue,
        SUM(CASE WHEN calendar_month_name = 'December' THEN monthly_revenue ELSE 0 END) AS Dec_Revenue,
        SUM(monthly_revenue) AS total_yearly_revenue
    FROM monthly_category_revenue
    GROUP BY product_category, calendar_year
)
SELECT 
    product_category,
    calendar_year,
    Jan_Revenue,
    Feb_Revenue,
    Mar_Revenue,
    Apr_Revenue,
    total_yearly_revenue
FROM pivot_data
WHERE calendar_year >= 2023
ORDER BY product_category, calendar_year;

-- Query D9: Advanced GROUP BY with ROLLUP, CUBE, and GROUPING SETS
-- Business Purpose: Multi-level aggregation for executive dashboard
-- ROLLUP example: Drill down from total to category to product
SELECT 
    COALESCE(dp.product_category, 'ALL CATEGORIES') AS category,
    COALESCE(dp.product_name, 'ALL PRODUCTS IN CATEGORY') AS product,
    COUNT(fst.sales_transaction_key) AS transaction_count,
    SUM(fst.total_revenue) AS total_revenue,
    AVG(fst.total_revenue) AS avg_transaction_value,
    GROUPING(dp.product_category) AS category_grouping,
    GROUPING(dp.product_name) AS product_grouping
FROM dim_product dp
JOIN fact_sales_transactions fst ON dp.product_key = fst.product_key
WHERE fst.transaction_type = 'Purchase'
GROUP BY ROLLUP(dp.product_category, dp.product_name)
HAVING GROUPING(dp.product_category) = 0  -- Exclude grand total for this example
ORDER BY GROUPING(dp.product_category), dp.product_category, total_revenue DESC;

-- CUBE example: All possible combinations of category and region
SELECT 
    COALESCE(dp.product_category, 'ALL CATEGORIES') AS category,
    COALESCE(dg.region_name, 'ALL REGIONS') AS region,
    COUNT(fst.sales_transaction_key) AS transaction_count,
    SUM(fst.total_revenue) AS total_revenue,
    AVG(fst.total_revenue) AS avg_transaction_value
FROM dim_product dp
JOIN fact_sales_transactions fst ON dp.product_key = fst.product_key
JOIN dim_customer dc ON fst.customer_key = dc.customer_key
JOIN dim_geography dg ON dc.geography_key = dg.geography_key
WHERE fst.transaction_type = 'Purchase'
GROUP BY CUBE(dp.product_category, dg.region_name)
HAVING NOT (dp.product_category IS NULL AND dg.region_name IS NULL)  -- Exclude grand total
ORDER BY total_revenue DESC;

-- GROUPING SETS example: Specific aggregations only
SELECT 
    'By Category' AS aggregation_level,
    dp.product_category AS dimension_value,
    COUNT(fst.sales_transaction_key) AS transaction_count,
    SUM(fst.total_revenue) AS total_revenue
FROM dim_product dp
JOIN fact_sales_transactions fst ON dp.product_key = fst.product_key
WHERE fst.transaction_type = 'Purchase'
GROUP BY dp.product_category

UNION ALL

SELECT 
    'By Customer Segment' AS aggregation_level,
    dc.customer_segment AS dimension_value,
    COUNT(fst.sales_transaction_key) AS transaction_count,
    SUM(fst.total_revenue) AS total_revenue
FROM dim_customer dc
JOIN fact_sales_transactions fst ON dc.customer_key = fst.customer_key
WHERE fst.transaction_type = 'Purchase'
GROUP BY dc.customer_segment

UNION ALL

SELECT 
    'By Month' AS aggregation_level,
    dt.calendar_month_name AS dimension_value,
    COUNT(fst.sales_transaction_key) AS transaction_count,
    SUM(fst.total_revenue) AS total_revenue
FROM dim_time dt
JOIN fact_sales_transactions fst ON dt.time_key = fst.time_key
WHERE fst.transaction_type = 'Purchase'
GROUP BY dt.calendar_month_name

ORDER BY aggregation_level, total_revenue DESC;

-- Query D10: Complex CASE Statements and Conditional Logic
-- Business Purpose: Customer tier classification with complex business rules
WITH customer_behavior_metrics AS (
    SELECT 
        c.customer_key,
        c.customer_name,
        c.customer_segment,
        c.loyalty_member,
        SUM(fst.total_revenue) AS lifetime_value,
        COUNT(fst.sales_transaction_key) AS transaction_count,
        COUNT(DISTINCT fst.order_id) AS order_count,
        COUNT(DISTINCT fst.product_key) AS unique_products_purchased,
        AVG(fst.total_revenue) AS avg_order_value,
        MAX(fst.transaction_date) AS last_purchase_date,
        MIN(fst.transaction_date) AS first_purchase_date,
        AVG(fst.review_rating) AS avg_review_rating,
        COUNT(CASE WHEN fst.is_express_delivery = TRUE THEN 1 END) AS express_delivery_orders,
        COUNT(CASE WHEN fst.is_gift = TRUE THEN 1 END) AS gift_orders,
        -- Calculate days since last purchase
        EXTRACT(DAY FROM (CURRENT_DATE - MAX(fst.transaction_date))) AS days_since_last_purchase
    FROM dim_customer c
    JOIN fact_sales_transactions fst ON c.customer_key = fst.customer_key
    WHERE fst.transaction_type = 'Purchase'
    GROUP BY c.customer_key, c.customer_name, c.customer_segment, c.loyalty_member
)
SELECT 
    customer_name,
    customer_segment,
    lifetime_value,
    transaction_count,
    avg_order_value,
    days_since_last_purchase,
    avg_review_rating,
    express_delivery_orders,
    gift_orders,
    -- Complex business rule for customer tier classification
    CASE 
        -- Premium tier: High value, frequent, recent purchaser
        WHEN lifetime_value >= 2000 
             AND transaction_count >= 10 
             AND days_since_last_purchase <= 60 
             AND avg_order_value >= 100 
             AND loyalty_member = TRUE
        THEN 'Diamond'
        
        -- Gold tier: Good value, regular purchaser
        WHEN lifetime_value >= 1000 
             AND transaction_count >= 5 
             AND days_since_last_purchase <= 90 
             AND avg_order_value >= 75
        THEN 'Gold'
        
        -- Silver tier: Moderate value, less frequent
        WHEN lifetime_value >= 500 
             AND transaction_count >= 3 
             AND days_since_last_purchase <= 120 
             AND avg_order_value >= 50
        THEN 'Silver'
        
        -- Bronze tier: Lower value, less frequent
        WHEN lifetime_value >= 200 
             AND days_since_last_purchase <= 180
        THEN 'Bronze'
        
        -- Inactive: Had transactions but not recently
        WHEN days_since_last_purchase > 180
        THEN 'Inactive'
        
        -- Low value: Doesn't meet other criteria
        ELSE 'Low_Value'
    END AS calculated_customer_tier,
    -- Additional business logic for marketing strategy
    CASE 
        WHEN days_since_last_purchase <= 30 THEN 'Retain_Active'
        WHEN days_since_last_purchase BETWEEN 31 AND 90 THEN 'Reconnect'
        WHEN days_since_last_purchase BETWEEN 91 AND 180 THEN 'Win_Back'
        ELSE 'Reactivate'
    END AS marketing_strategy
FROM customer_behavior_metrics
ORDER BY lifetime_value DESC
LIMIT 20;

-- Query D11: Date/Time Manipulation and Advanced Calculations
-- Business Purpose: Analyze seasonal trends and cyclical patterns
WITH time_series_analysis AS (
    SELECT 
        dt.date_value,
        dt.calendar_year,
        dt.calendar_month_number_in_year,
        dt.calendar_month_name,
        dt.day_name_of_week,
        dt.day_number_in_year,
        dt.weekend_flag,
        dt.holiday_flag,
        SUM(COALESCE(fst.total_revenue, 0)) AS daily_revenue,
        COUNT(COALESCE(fst.sales_transaction_key, 0)) AS daily_transactions,
        -- Calculate week number in year (ISO standard)
        EXTRACT(WEEK FROM dt.date_value) AS iso_week_number,
        -- Calculate day of week number (Monday = 1, Sunday = 7)
        CASE EXTRACT(DOW FROM dt.date_value) 
            WHEN 1 THEN 7  -- Sunday
            WHEN 2 THEN 1  -- Monday
            WHEN 3 THEN 2  -- Tuesday
            WHEN 4 THEN 3  -- Wednesday
            WHEN 5 THEN 4  -- Thursday
            WHEN 6 THEN 5  -- Friday
            WHEN 0 THEN 6  -- Saturday
        END AS iso_day_of_week,
        -- Calculate days from beginning of year
        dt.day_number_in_year AS days_from_year_start,
        -- Calculate days from end of year
        365 - dt.day_number_in_year AS days_to_year_end
    FROM dim_time dt
    LEFT JOIN fact_sales_transactions fst ON dt.time_key = fst.time_key
    WHERE dt.date_value BETWEEN '2023-01-01' AND '2024-12-31'
    GROUP BY dt.date_value, dt.calendar_year, dt.calendar_month_number_in_year, 
             dt.calendar_month_name, dt.day_name_of_week, dt.day_number_in_year,
             dt.weekend_flag, dt.holiday_flag
),
seasonal_patterns AS (
    SELECT 
        *,
        -- Calculate moving average (5-day window)
        AVG(daily_revenue) OVER (
            ORDER BY date_value 
            ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING
        ) AS five_day_moving_avg,
        -- Calculate revenue compared to same day last year
        LAG(daily_revenue, 365) OVER (ORDER BY date_value) AS last_year_same_day_revenue,
        -- Calculate percent change from same day last year
        CASE 
            WHEN LAG(daily_revenue, 365) OVER (ORDER BY date_value) > 0 THEN
                ROUND(((daily_revenue - LAG(daily_revenue, 365) OVER (ORDER BY date_value)) * 100.0 / 
                       LAG(daily_revenue, 365) OVER (ORDER BY date_value)), 2)
            ELSE NULL
        END AS yoy_change_percent,
        -- Calculate week-over-week change
        LAG(daily_revenue, 7) OVER (ORDER BY date_value) AS week_ago_revenue,
        CASE 
            WHEN LAG(daily_revenue, 7) OVER (ORDER BY date_value) > 0 THEN
                ROUND(((daily_revenue - LAG(daily_revenue, 7) OVER (ORDER BY date_value)) * 100.0 / 
                       LAG(daily_revenue, 7) OVER (ORDER BY date_value)), 2)
            ELSE NULL
        END AS wow_change_percent
    FROM time_series_analysis
)
SELECT 
    date_value,
    daily_revenue,
    daily_transactions,
    calendar_month_name,
    day_name_of_week,
    weekend_flag,
    holiday_flag,
    five_day_moving_avg,
    yoy_change_percent,
    wow_change_percent,
    -- Identify seasonal patterns
    CASE 
        WHEN calendar_month_number_in_year IN (11, 12) AND daily_revenue > five_day_moving_avg THEN 'Holiday_Spike'
        WHEN calendar_month_number_in_year IN (6, 7, 8) AND day_name_of_week IN ('Saturday', 'Sunday') THEN 'Summer_Weekend_Pattern'
        WHEN weekend_flag = TRUE AND daily_revenue > five_day_moving_avg THEN 'Weekend_Pattern'
        WHEN holiday_flag = TRUE THEN 'Holiday_Pattern'
        ELSE 'Regular_Day'
    END AS day_pattern_type
FROM seasonal_patterns
WHERE date_value >= '2024-01-01'  -- Focus on complete year
ORDER BY date_value;

-- Query D12: String Functions and Pattern Matching
-- Business Purpose: Analyze customer feedback and product descriptions for insights
WITH feedback_analysis AS (
    SELECT 
        fst.review_text,
        fst.review_rating,
        dp.product_name,
        dp.product_category,
        dc.customer_segment,
        -- Extract useful information using string functions
        LENGTH(fst.review_text) AS review_length,
        LOWER(fst.review_text) AS lower_review,
        UPPER(dp.product_name) AS upper_product_name,
        -- Count positive/negative words (simplified approach)
        (LENGTH(fst.review_text) - LENGTH(REPLACE(LOWER(fst.review_text), 'good', ''))) / 4 AS good_mentions,
        (LENGTH(fst.review_text) - LENGTH(REPLACE(LOWER(fst.review_text), 'excellent', ''))) / 9 AS excellent_mentions,
        (LENGTH(fst.review_text) - LENGTH(REPLACE(LOWER(fst.review_text), 'bad', ''))) / 3 AS bad_mentions,
        (LENGTH(fst.review_text) - LENGTH(REPLACE(LOWER(fst.review_text), 'poor', ''))) / 4 AS poor_mentions,
        -- Extract the first sentence for sentiment analysis
        SPLIT_PART(fst.review_text, '.', 1) AS first_sentence,
        -- Check if review mentions specific features
        CASE 
            WHEN fst.review_text ILIKE '%quality%' THEN 1 ELSE 0 
        END AS mentions_quality,
        CASE 
            WHEN fst.review_text ILIKE '%price%' OR fst.review_text ILIKE '%value%' THEN 1 ELSE 0 
        END AS mentions_price,
        CASE 
            WHEN fst.review_text ILIKE '%delivery%' OR fst.review_text ILIKE '%shipping%' THEN 1 ELSE 0 
        END AS mentions_delivery
    FROM fact_sales_transactions fst
    JOIN dim_product dp ON fst.product_key = dp.product_key
    JOIN dim_customer dc ON fst.customer_key = dc.customer_key
    WHERE fst.review_text IS NOT NULL AND LENGTH(fst.review_text) > 0
),
sentiment_score AS (
    SELECT 
        product_category,
        product_name,
        review_rating,
        review_length,
        (good_mentions + excellent_mentions) - (bad_mentions + poor_mentions) AS sentiment_score,
        mentions_quality,
        mentions_price,
        mentions_delivery,
        COUNT(*) AS review_count,
        AVG(review_rating) AS avg_rating
    FROM feedback_analysis
    GROUP BY product_category, product_name, review_rating, review_length,
             (good_mentions + excellent_mentions) - (bad_mentions + poor_mentions),
             mentions_quality, mentions_price, mentions_delivery
)
SELECT 
    product_category,
    product_name,
    review_count,
    avg_rating,
    AVG(sentiment_score) AS avg_sentiment_score,
    SUM(mentions_quality) AS quality_mentions,
    SUM(mentions_price) AS price_mentions,
    SUM(mentions_delivery) AS delivery_mentions,
    -- Business insights
    CASE 
        WHEN AVG(sentiment_score) > 1 THEN 'Strong_Positive_Sentiment'
        WHEN AVG(sentiment_score) > 0 THEN 'Mild_Positive_Sentiment'
        WHEN AVG(sentiment_score) = 0 THEN 'Neutral_Sentiment'
        WHEN AVG(sentiment_score) > -1 THEN 'Mild_Negative_Sentiment'
        ELSE 'Strong_Negative_Sentiment'
    END AS overall_sentiment_category
FROM sentiment_score
GROUP BY product_category, product_name
HAVING review_count >= 3  -- Only include products with sufficient reviews
ORDER BY avg_sentiment_score DESC, review_count DESC;

-- Query D13: Set Operations (UNION, INTERSECT, EXCEPT) for Customer Analysis
-- Business Purpose: Identify customers who use multiple channels vs single channel
-- Find customers who engage with both web and customer service
WITH web_active_customers AS (
    SELECT DISTINCT customer_key
    FROM fact_web_events
    WHERE customer_key IS NOT NULL
),
interaction_active_customers AS (
    SELECT DISTINCT customer_key
    FROM fact_customer_interactions
),
sales_active_customers AS (
    SELECT DISTINCT customer_key
    FROM fact_sales_transactions
)

-- Multi-channel customers (appear in all three sources)
SELECT 'multi_channel_customer' AS customer_type, customer_key, 'Uses web, interactions, and makes purchases' AS description
FROM web_active_customers
INTERSECT
SELECT customer_key, 'Uses web, interactions, and makes purchases' AS description
FROM interaction_active_customers
INTERSECT
SELECT customer_key, 'Uses web, interactions, and makes purchases' AS description
FROM sales_active_customers

UNION ALL

-- Web-only customers (in web but not in interactions or sales)
SELECT 'web_only_customer' AS customer_type, customer_key, 'Active on web but no interactions or purchases' AS description
FROM web_active_customers
EXCEPT
SELECT customer_key, 'Active on web but no interactions or purchases' AS description
FROM interaction_active_customers
EXCEPT
SELECT customer_key, 'Active on web but no interactions or purchases' AS description
FROM sales_active_customers

UNION ALL

-- Interaction-only customers (in interactions but not in web or sales)
SELECT 'interaction_only_customer' AS customer_type, customer_key, 'Only uses customer service interactions' AS description
FROM interaction_active_customers
EXCEPT
SELECT customer_key, 'Only uses customer service interactions' AS description
FROM web_active_customers
EXCEPT
SELECT customer_key, 'Only uses customer service interactions' AS description
FROM sales_active_customers

ORDER BY customer_type, customer_key;

-- Query D14: Self-Join for Customer Cohort Analysis
-- Business Purpose: Analyze customer behavior patterns by comparing similar customers
WITH customer_profiles AS (
    SELECT 
        c.customer_key,
        c.customer_name,
        c.customer_segment,
        c.age_group,
        c.annual_income,
        c.geography_key,
        dg.country_name,
        SUM(fst.total_revenue) AS lifetime_value,
        COUNT(fst.sales_transaction_key) AS transaction_count,
        AVG(fst.total_revenue) AS avg_transaction_value
    FROM dim_customer c
    JOIN dim_geography dg ON c.geography_key = dg.geography_key
    JOIN fact_sales_transactions fst ON c.customer_key = fst.customer_key
    WHERE fst.transaction_type = 'Purchase'
    GROUP BY c.customer_key, c.customer_name, c.customer_segment, c.age_group, 
             c.annual_income, c.geography_key, dg.country_name
),
customer_comparisons AS (
    SELECT 
        c1.customer_name AS customer_1,
        c2.customer_name AS customer_2,
        c1.country_name,
        c1.lifetime_value AS c1_lifetime_value,
        c2.lifetime_value AS c2_lifetime_value,
        c1.avg_transaction_value AS c1_avg_atv,
        c2.avg_transaction_value AS c2_avg_atv,
        c1.transaction_count AS c1_transactions,
        c2.transaction_count AS c2_transactions,
        c1.customer_segment AS c1_segment,
        c2.customer_segment AS c2_segment,
        -- Calculate similarity score (simplified)
        CASE 
            WHEN c1.customer_segment = c2.customer_segment AND 
                 c1.country_name = c2.country_name THEN 1
            WHEN c1.customer_segment = c2.customer_segment OR 
                 c1.country_name = c2.country_name THEN 0.5
            ELSE 0
        END AS similarity_score
    FROM customer_profiles c1
    JOIN customer_profiles c2 ON c1.country_name = c2.country_name
        AND c1.customer_key != c2.customer_key
        AND ABS(c1.lifetime_value - c2.lifetime_value) <= GREATEST(c1.lifetime_value, c2.lifetime_value) * 0.2  -- Within 20% lifetime value
    WHERE c1.customer_key < c2.customer_key  -- To avoid duplicates and self-joins
)
SELECT 
    customer_1,
    customer_2,
    country_name,
    c1_lifetime_value,
    c2_lifetime_value,
    c1_avg_atv,
    c2_avg_atv,
    similarity_score,
    CASE 
        WHEN similarity_score = 1 THEN 'Very Similar'
        WHEN similarity_score = 0.5 THEN 'Somewhat Similar'
        ELSE 'Different'
    END AS comparison_category
FROM customer_comparisons
WHERE similarity_score > 0
ORDER BY similarity_score DESC, c1_lifetime_value DESC
LIMIT 15;

-- Query D15: Advanced Aggregation with FILTER Clause
-- Business Purpose: Calculate various metrics with conditional aggregation
SELECT 
    dp.product_category,
    -- All transactions
    COUNT(fst.sales_transaction_key) AS total_transactions,
    SUM(fst.total_revenue) AS total_revenue,
    AVG(fst.total_revenue) AS overall_avg_order_value,
    
    -- Filtered aggregations using FILTER clause
    COUNT(*) FILTER (WHERE fst.is_return = FALSE) AS non_return_transactions,
    COUNT(*) FILTER (WHERE fst.is_return = TRUE) AS return_transactions,
    SUM(fst.total_revenue) FILTER (WHERE fst.review_rating >= 4) AS revenue_from_4_5_star_reviews,
    SUM(fst.total_revenue) FILTER (WHERE fst.review_rating <= 2) AS revenue_from_1_2_star_reviews,
    AVG(fst.total_revenue) FILTER (WHERE fst.is_express_delivery = TRUE) AS avg_order_value_express_delivery,
    AVG(fst.total_revenue) FILTER (WHERE fst.is_express_delivery = FALSE) AS avg_order_value_regular_delivery,
    COUNT(fst.product_key) FILTER (WHERE dp.product_brand = 'TechBrand') AS techbrand_product_sales,
    AVG(fst.review_rating) FILTER (WHERE fst.customer_satisfaction_score >= 4.0) AS avg_rating_high_satisfaction_orders,
    
    -- Calculate return rate
    ROUND(
        (COUNT(*) FILTER (WHERE fst.is_return = TRUE) * 100.0 / COUNT(fst.sales_transaction_key)), 2
    ) AS return_rate_percent,
    
    -- Calculate high satisfaction rate
    ROUND(
        (COUNT(fst.sales_transaction_key) FILTER (WHERE fst.review_rating >= 4) * 100.0 / 
         COUNT(fst.sales_transaction_key)), 2
    ) AS high_satisfaction_rate_percent,
    
    -- Revenue from different product lines
    SUM(fst.total_revenue) FILTER (WHERE dp.product_line = 'Premium') AS premium_product_revenue,
    SUM(fst.total_revenue) FILTER (WHERE dp.product_line = 'Standard') AS standard_product_revenue,
    SUM(fst.total_revenue) FILTER (WHERE dp.product_line = 'Budget') AS budget_product_revenue
    
FROM dim_product dp
JOIN fact_sales_transactions fst ON dp.product_key = fst.product_key
WHERE fst.transaction_type = 'Purchase'
GROUP BY dp.product_category
HAVING COUNT(fst.sales_transaction_key) >= 10  -- Only categories with significant volume
ORDER BY total_revenue DESC;

-- Query D16: Complex Business Intelligence with Multiple Fact Tables
-- Business Purpose: Comprehensive customer intelligence view combining sales, web, and interaction data
WITH customer_comprehensive_view AS (
    SELECT 
        c.customer_key,
        c.customer_name,
        c.customer_segment,
        c.loyalty_member,
        c.geography_key,
        dg.country_name,
        
        -- Sales metrics
        COALESCE(sales_agg.total_revenue, 0) AS sales_total_revenue,
        COALESCE(sales_agg.total_transactions, 0) AS sales_transaction_count,
        COALESCE(sales_agg.avg_order_value, 0) AS sales_avg_order_value,
        COALESCE(sales_agg.total_profit, 0) AS sales_total_profit,
        COALESCE(sales_agg.return_count, 0) AS sales_return_count,
        
        -- Web engagement metrics
        COALESCE(web_agg.total_events, 0) AS web_total_events,
        COALESCE(web_agg.page_views, 0) AS web_page_views,
        COALESCE(web_agg.add_to_cart_events, 0) AS web_add_to_cart_events,
        COALESCE(web_agg.purchase_events, 0) AS web_purchase_events,
        COALESCE(web_agg.avg_session_duration, 0) AS web_avg_session_duration,
        
        -- Customer interaction metrics
        COALESCE(interaction_agg.total_interactions, 0) AS interaction_total_count,
        COALESCE(interaction_agg.avg_satisfaction_score, 0) AS interaction_avg_satisfaction,
        COALESCE(interaction_agg.total_sentiment_impact, 0) AS interaction_sentiment_impact,
        COALESCE(interaction_agg.high_priority_count, 0) AS interaction_high_priority_count
        
    FROM dim_customer c
    JOIN dim_geography dg ON c.geography_key = dg.geography_key
    
    -- Left join with sales aggregation
    LEFT JOIN (
        SELECT 
            fst.customer_key,
            SUM(fst.total_revenue) AS total_revenue,
            COUNT(fst.sales_transaction_key) AS total_transactions,
            AVG(fst.total_revenue) AS avg_order_value,
            SUM(fst.total_profit) AS total_profit,
            COUNT(CASE WHEN fst.is_return = TRUE THEN 1 END) AS return_count
        FROM fact_sales_transactions fst
        WHERE fst.transaction_type = 'Purchase'
        GROUP BY fst.customer_key
    ) sales_agg ON c.customer_key = sales_agg.customer_key
    
    -- Left join with web aggregation
    LEFT JOIN (
        SELECT 
            fw.customer_key,
            COUNT(fw.web_event_key) AS total_events,
            COUNT(CASE WHEN fw.event_type = 'page_view' THEN 1 END) AS page_views,
            COUNT(CASE WHEN fw.event_type = 'add_to_cart' THEN 1 END) AS add_to_cart_events,
            COUNT(CASE WHEN fw.event_type = 'purchase' THEN 1 END) AS purchase_events,
            AVG(fw.session_duration_seconds) AS avg_session_duration
        FROM fact_web_events fw
        GROUP BY fw.customer_key
    ) web_agg ON c.customer_key = web_agg.customer_key
    
    -- Left join with interaction aggregation
    LEFT JOIN (
        SELECT 
            fci.customer_key,
            COUNT(fci.interaction_key) AS total_interactions,
            AVG(fci.satisfaction_score) AS avg_satisfaction_score,
            SUM(fci.revenue_impact) AS total_sentiment_impact,
            COUNT(CASE WHEN fci.priority_level = 'High' THEN 1 END) AS high_priority_count
        FROM fact_customer_interactions fci
        GROUP BY fci.customer_key
    ) interaction_agg ON c.customer_key = interaction_agg.customer_key
)
SELECT 
    customer_name,
    customer_segment,
    loyalty_member,
    country_name,
    sales_total_revenue,
    sales_transaction_count,
    sales_avg_order_value,
    web_total_events,
    web_page_views,
    web_purchase_events,
    interaction_total_count,
    interaction_avg_satisfaction,
    
    -- Calculate derived intelligence metrics
    CASE 
        WHEN sales_transaction_count > 0 AND web_total_events > 0 THEN
            ROUND(web_purchase_events * 100.0 / web_total_events, 2)
        ELSE 0
    END AS web_conversion_rate,
    
    CASE 
        WHEN sales_transaction_count > 0 THEN
            ROUND((sales_total_revenue / sales_transaction_count), 2)
        ELSE 0
    END AS revenue_per_transaction,
    
    CASE 
        WHEN web_total_events > 0 THEN
            ROUND(web_avg_session_duration / 60.0, 2)  -- Convert to minutes
        ELSE 0
    END AS avg_session_minutes,
    
    -- Customer intelligence score combining multiple factors
    ROUND(
        (sales_total_revenue * 0.4 + 
         (web_total_events * 0.1) + 
         (interaction_total_count * 0.05) + 
         (interaction_avg_satisfaction * 20 * 0.15)) / 1.7, 2
    ) AS customer_intelligence_score,
    
    -- Customer classification based on multi-dimensional analysis
    CASE 
        WHEN sales_total_revenue >= 1000 AND web_total_events >= 50 AND interaction_total_count <= 5 THEN 'High Value Digital Native'
        WHEN sales_total_revenue >= 1000 AND web_total_events < 50 AND interaction_total_count > 5 THEN 'High Value Support Dependent'
        WHEN sales_total_revenue < 1000 AND web_total_events >= 50 AND interaction_total_count <= 3 THEN 'Engaged Low Value'
        WHEN sales_total_revenue < 500 AND web_total_events < 20 AND interaction_total_count > 10 THEN 'Disengaged High Maintenance'
        ELSE 'Standard Customer'
    END AS customer_classification
    
FROM customer_comprehensive_view
ORDER BY customer_intelligence_score DESC
LIMIT 25;