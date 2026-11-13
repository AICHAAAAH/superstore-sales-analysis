-- =====================================================================
-- Superstore Sales Analysis: SQL queries (SQLite)
-- Table: orders (see 01_schema_load.sql)
-- Note: the dataset has no Profit, Quantity or Discount columns,
--       so all queries are based on sales.
-- =====================================================================


-- Q1. Headline KPIs
-- Business question: how big is the business over the whole period?
-- Result: 2,261,255.41 total sales, 4,922 orders, 793 customers,
--         average order value 459.42 (2015-01-03 to 2018-12-30).
SELECT ROUND(SUM(sales), 2)                        AS total_sales,
       COUNT(DISTINCT order_id)                    AS orders,
       COUNT(DISTINCT customer_id)                 AS customers,
       ROUND(SUM(sales) / COUNT(DISTINCT order_id), 2) AS avg_order_value,
       MIN(order_date)                             AS first_order,
       MAX(order_date)                             AS last_order
FROM orders;


-- Q2. Year-over-year growth (window function LAG)
-- Business question: is the business growing?
-- Result: -4.2% (2016), +30.6% (2017), +20.3% (2018).
WITH yearly AS (
    SELECT year, ROUND(SUM(sales), 2) AS sales
    FROM orders
    GROUP BY year
)
SELECT year,
       sales,
       LAG(sales) OVER (ORDER BY year) AS prev_year_sales,
       ROUND((sales - LAG(sales) OVER (ORDER BY year)) * 100.0
             / LAG(sales) OVER (ORDER BY year), 1) AS growth_pct
FROM yearly
ORDER BY year;


-- Q3. Seasonality: share and rank of each month (RANK)
-- Business question: which months matter most?
-- Result: Sep-Dec = 51.8% of sales; November is #1 (15.5%);
--         February is the weakest (2.6%).
SELECT month,
       month_name,
       ROUND(SUM(sales), 2) AS sales,
       ROUND(SUM(sales) * 100.0 / SUM(SUM(sales)) OVER (), 1) AS share_pct,
       RANK() OVER (ORDER BY SUM(sales) DESC) AS sales_rank
FROM orders
GROUP BY month, month_name
ORDER BY month;


-- Q4. Category share
-- Business question: which product category sells the most?
-- Result: Technology 36.6%, Furniture 32.2%, Office Supplies 31.2%.
SELECT category,
       ROUND(SUM(sales), 2) AS sales,
       ROUND(SUM(sales) * 100.0 / SUM(SUM(sales)) OVER (), 1) AS share_pct
FROM orders
GROUP BY category
ORDER BY sales DESC;


-- Q5. Top 3 sub-categories inside each category (ROW_NUMBER + PARTITION BY)
-- Business question: what are the leading products in each category?
-- Result: Chairs, Storage and Phones lead their categories.
WITH ranked AS (
    SELECT category,
           sub_category,
           ROUND(SUM(sales), 2) AS sales,
           ROW_NUMBER() OVER (PARTITION BY category ORDER BY SUM(sales) DESC) AS rn
    FROM orders
    GROUP BY category, sub_category
)
SELECT category, sub_category, sales, rn AS rank_in_category
FROM ranked
WHERE rn <= 3
ORDER BY category, rn;


-- Q6. Top 10 states with cumulative share (running total window)
-- Business question: how concentrated are sales geographically?
-- Result: California 19.7% + New York 13.5% = 33.3%; top 10 states = 69.1%.
SELECT state,
       ROUND(SUM(sales), 2) AS sales,
       ROUND(SUM(sales) * 100.0 / SUM(SUM(sales)) OVER (), 1) AS share_pct,
       ROUND(SUM(SUM(sales)) OVER (ORDER BY SUM(sales) DESC) * 100.0
             / SUM(SUM(sales)) OVER (), 1) AS cumulative_share_pct
FROM orders
GROUP BY state
ORDER BY sales DESC
LIMIT 10;


-- Q7. Segment sales by year (pivot with CASE)
-- Business question: how does each customer segment evolve?
-- Result: all segments grew in 2017-2018; Corporate grew fastest
--         (127.8K in 2015 to 236.0K in 2018).
SELECT segment,
       ROUND(SUM(CASE WHEN year = 2015 THEN sales END), 0) AS y2015,
       ROUND(SUM(CASE WHEN year = 2016 THEN sales END), 0) AS y2016,
       ROUND(SUM(CASE WHEN year = 2017 THEN sales END), 0) AS y2017,
       ROUND(SUM(CASE WHEN year = 2018 THEN sales END), 0) AS y2018,
       ROUND(SUM(sales), 0) AS total
FROM orders
GROUP BY segment
ORDER BY total DESC;


-- Q8. Customer concentration by decile (NTILE)
-- Business question: do a few customers produce most of the sales?
-- Result: the top 10% of customers (80 customers) produce 31.2% of sales;
--         the top 20% produce 48.7%; the bottom 50% only about 19.4%.
WITH cust AS (
    SELECT customer_id, SUM(sales) AS sales
    FROM orders
    GROUP BY customer_id
),
bucketed AS (
    SELECT *, NTILE(10) OVER (ORDER BY sales DESC) AS decile
    FROM cust
)
SELECT decile,
       COUNT(*) AS customers,
       ROUND(SUM(sales), 2) AS sales,
       ROUND(SUM(sales) * 100.0 / SUM(SUM(sales)) OVER (), 1) AS share_pct
FROM bucketed
GROUP BY decile
ORDER BY decile;


-- Q9. Repeat customers
-- Business question: do customers come back?
-- Result: 780 of 793 customers (98.4%) ordered more than once;
--         6.2 orders per customer on average.
WITH per_customer AS (
    SELECT customer_id, COUNT(DISTINCT order_id) AS orders
    FROM orders
    GROUP BY customer_id
)
SELECT COUNT(*) AS customers,
       SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END) AS repeat_customers,
       ROUND(SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS repeat_rate_pct,
       ROUND(AVG(orders), 1) AS avg_orders_per_customer
FROM per_customer;


-- Q10. Shipping performance
-- Business question: how fast is each ship mode and how much is it used?
-- Result: Standard Class = 59.3% of sales (5.01 days on average);
--         Same Day 0.04 days; First Class 2.18; Second Class 3.25.
SELECT ship_mode,
       COUNT(*) AS order_lines,
       ROUND(AVG(shipping_days), 2) AS avg_days,
       ROUND(SUM(sales), 2) AS sales,
       ROUND(SUM(sales) * 100.0 / SUM(SUM(sales)) OVER (), 1) AS share_pct
FROM orders
GROUP BY ship_mode
ORDER BY sales DESC;


-- Q11. Running total of sales in 2018 (cumulative window)
-- Business question: how does the latest year build up month by month?
-- Result: 722,052 in total; November alone adds about 118K.
WITH m AS (
    SELECT year, month, SUM(sales) AS sales
    FROM orders
    GROUP BY year, month
)
SELECT year,
       month,
       ROUND(sales, 0) AS sales,
       ROUND(SUM(sales) OVER (PARTITION BY year ORDER BY month), 0) AS running_total
FROM m
WHERE year = 2018
ORDER BY month;
