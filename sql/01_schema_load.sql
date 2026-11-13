-- =====================================================================
-- Superstore Sales Analysis: table description (SQLite)
-- Database: data/processed/superstore.db
-- Loaded from data/processed/superstore_clean.csv by
-- notebooks/03_sql_analysis.ipynb (pandas DataFrame.to_sql).
-- The .db file is not committed to GitHub (see .gitignore); the
-- notebook rebuilds it.
-- =====================================================================

-- Equivalent table definition (the notebook creates it automatically)
CREATE TABLE orders (
    row_id         INTEGER,
    order_id       TEXT,
    order_date     TEXT,     -- YYYY-MM-DD
    ship_date      TEXT,     -- YYYY-MM-DD
    ship_mode      TEXT,
    customer_id    TEXT,
    customer_name  TEXT,
    segment        TEXT,     -- Consumer / Corporate / Home Office
    country        TEXT,
    city           TEXT,
    state          TEXT,
    postal_code    TEXT,     -- 5-character text, keeps leading zeros
    region         TEXT,     -- West / East / Central / South
    product_id     TEXT,
    category       TEXT,     -- Furniture / Office Supplies / Technology
    sub_category   TEXT,
    product_name   TEXT,
    sales          REAL,
    year           INTEGER,  -- derived from order_date
    month          INTEGER,
    month_name     TEXT,
    quarter        INTEGER,
    shipping_days  INTEGER   -- ship_date minus order_date
);

-- Grain: one row = one product line inside an order.
-- An order can have several rows: use COUNT(DISTINCT order_id) to count orders.

-- Quick check
SELECT COUNT(*) AS rows FROM orders;   -- expected: 9799