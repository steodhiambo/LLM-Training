# SQL Portfolio Project

This repository contains a comprehensive SQL portfolio demonstrating various database concepts, queries, and implementations. The project showcases expertise in SQL development, database design, and business intelligence solutions.

## Project Structure

```
sql_portfolio/
├── business_documentation.md         # Business requirements and context
├── business_intelligence_views.sql   # BI views for reporting and analytics
├── complex_queries_part1.sql         # Advanced SQL queries (part 1)
├── complex_queries_part2.sql         # Advanced SQL queries (part 2)
├── comprehensive_documentation.md    # Detailed technical documentation
├── data_dictionary.txt              # Description of all tables and columns
├── data_generation.sql              # Scripts to populate sample data
├── ddl_schema.sql                   # Database schema definition
├── design_decisions.txt             # Rationale behind design choices
├── erd_description.txt              # Entity Relationship Diagram description
├── etl_pipeline.sql                 # Extract, Transform, Load processes
├── github_repository_structure.md   # Repository organization details
├── query_optimization.sql           # Performance tuning examples
├── snowflake_implementation.sql     # Snowflake-specific implementations
├── stored_procedures_functions.sql  # Custom procedures and functions
└── technical_documentation.md       # Technical specifications
```

## Prerequisites

Before running the SQL scripts in this portfolio, ensure you have:

- A SQL database management system (such as PostgreSQL, MySQL, SQL Server, or Snowflake)
- SQL client tool (like pgAdmin, MySQL Workbench, or command-line interface)
- Basic knowledge of SQL syntax and concepts

## Setup Instructions

### Option 1: Using Docker (Recommended)

1. Install Docker on your machine
2. Create a database container:
   ```bash
   docker run --name sql-portfolio-db -e POSTGRES_PASSWORD=your_password -p 5432:5432 -d postgres
   ```
3. Connect to the database using your favorite SQL client

### Option 2: Using Local Database

1. Install your preferred database system locally
2. Create a new database for this project
3. Configure the connection settings in your SQL client

## Running the SQL Files

### 1. Database Schema Setup

Start by creating the database schema:

```sql
-- Execute DDL statements to create tables and relationships
\i sql_portfolio/ddl_schema.sql
```

### 2. Data Population

Once the schema is created, populate the database with sample data:

```sql
-- Insert sample data into the tables
\i sql_portfolio/data_generation.sql
```

### 3. Explore Complex Queries

Run the complex queries to see advanced SQL techniques:

```sql
-- Part 1: Basic to intermediate complex queries
\i sql_portfolio/complex_queries_part1.sql

-- Part 2: Advanced complex queries
\i sql_portfolio/complex_queries_part2.sql
```

### 4. Business Intelligence Views

Create views for reporting and analytics:

```sql
-- Create business intelligence views
\i sql_portfolio/business_intelligence_views.sql
```

### 5. Stored Procedures and Functions

Implement custom business logic:

```sql
-- Create stored procedures and functions
\i sql_portfolio/stored_procedures_functions.sql
```

### 6. ETL Pipeline

Execute the ETL pipeline:

```sql
-- Run the ETL process
\i sql_portfolio/etl_pipeline.sql
```

### 7. Query Optimization Examples

Review and execute optimized queries:

```sql
-- See various optimization techniques
\i sql_portfolio/query_optimization.sql
```

### 8. Snowflake Implementation

If working with Snowflake, execute the specific implementations:

```sql
-- Snowflake-specific features and optimizations
\i sql_portfolio/snowflake_implementation.sql
```

## Understanding the Documentation

- Read `business_documentation.md` for the business context
- Check `data_dictionary.txt` to understand table structures
- Review `design_decisions.txt` to understand architectural choices
- Examine `erd_description.txt` for entity relationships
- Consult `technical_documentation.md` for technical details

## Tips for Best Experience

1. Follow the recommended execution order: schema → data → queries → views → procedures → ETL
2. Refer to the data dictionary while running queries to understand the data structure
3. Compare the original queries with optimized versions in `query_optimization.sql`
4. Use the business documentation to understand the purpose of each query
5. Experiment with modifying queries to practice SQL skills

## Troubleshooting

- If queries fail due to missing tables, ensure the `ddl_schema.sql` has been executed
- If data queries fail, verify that `data_generation.sql` has populated the tables
- Check your database connection settings if experiencing connectivity issues
- Ensure your database supports all SQL features used in the scripts

## Dependencies Between Files

Understanding the relationship between SQL files:

- `ddl_schema.sql` must be executed first to create the database structure
- `data_generation.sql` depends on the schema and should be executed second
- `complex_queries_part1.sql` and `complex_queries_part2.sql` rely on the populated data
- `business_intelligence_views.sql` uses tables created in `ddl_schema.sql`
- `stored_procedures_functions.sql` may reference tables from the schema
- `etl_pipeline.sql` typically operates on existing tables and views
- `query_optimization.sql` contains improved versions of queries from other files

## Usage Examples

### Example 1: Creating Customer Analysis Report
```sql
-- Step 1: Ensure schema and data exist
\i sql_portfolio/ddl_schema.sql
\i sql_portfolio/data_generation.sql

-- Step 2: Create BI view for customer analysis
\i sql_portfolio/business_intelligence_views.sql

-- Step 3: Run complex analysis query
SELECT customer_segment, AVG(purchase_amount) as avg_purchase
FROM customer_analysis_view
GROUP BY customer_segment;
```

### Example 2: Performance Comparison
```sql
-- First, run the original query
SELECT department, COUNT(*) as employee_count
FROM employees e
JOIN departments d ON e.dept_id = d.id
WHERE e.hire_date > '2020-01-01'
GROUP BY department;

-- Then compare with the optimized version
\i sql_portfolio/query_optimization.sql
-- Run the optimized equivalent for performance comparison
```

### Example 3: Full ETL Process
```sql
-- Set up schema and data
\i sql_portfolio/ddl_schema.sql
\i sql_portfolio/data_generation.sql

-- Create stored procedures for processing
\i sql_portfolio/stored_procedures_functions.sql

-- Execute ETL pipeline
\i sql_portfolio/etl_pipeline.sql

-- Query the results
SELECT * FROM transformed_data_summary LIMIT 10;
```

## License

This project is available for educational purposes. Feel free to explore, modify, and learn from the code.