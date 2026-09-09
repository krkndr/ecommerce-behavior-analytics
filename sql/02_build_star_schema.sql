-- Create the products dimension table, removing duplicates to ensure unique product IDs
CREATE TABLE analytics.dim_products AS
WITH RankedProducts AS (
    SELECT 
        product_id, 
        category_id, 
        category_code, 
        brand, 
        price,
        ROW_NUMBER() OVER(PARTITION BY product_id ORDER BY event_time DESC) as rn
    FROM staging.raw_events
    WHERE product_id IS NOT NULL
)
SELECT 
        product_id, 
        category_id, 
        category_code, 
        brand, 
        price
FROM RankedProducts
WHERE rn = 1;

-- Create the users dimension table with unique user IDs
CREATE TABLE analytics.dim_users AS
SELECT DISTINCT user_id
FROM staging.raw_events
WHERE user_id IS NOT NULL;

-- Create the fact table for events, filtering out invalid records
CREATE TABLE analytics.fact_events AS
SELECT 
    event_time,
    event_type,
    product_id,
    user_id,
    user_session
FROM staging.raw_events
WHERE product_id IS NOT NULL 
  AND user_id IS NOT NULL;

-- Define primary keys for dimension tables to enforce referential integrity
ALTER TABLE analytics.dim_products ADD PRIMARY KEY (product_id);
ALTER TABLE analytics.dim_users ADD PRIMARY KEY (user_id);

-- Create indexes on the fact table foreign keys to optimize DirectQuery performance
CREATE INDEX idx_fact_product ON analytics.fact_events(product_id);
CREATE INDEX idx_fact_user ON analytics.fact_events(user_id);