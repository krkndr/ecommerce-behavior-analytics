-- Create the Users dimension table (Unique customers)
CREATE TABLE analytics.dim_users AS
SELECT DISTINCT user_id
FROM staging.events_subset
WHERE user_id IS NOT NULL;
-- Create the Products dimension table (Unique products with their latest attributes)
CREATE TABLE analytics.dim_products AS
SELECT DISTINCT ON (product_id) product_id,
    category_id,
    category_code,
    brand,
    price
FROM staging.events_subset
WHERE product_id IS NOT NULL
ORDER BY product_id,
    event_time DESC;
-- Create the Events fact table (Narrow table with keys and event details)
CREATE TABLE analytics.fact_events AS
SELECT event_time,
    event_type,
    product_id,
    user_id,
    user_session
FROM staging.events_subset
WHERE product_id IS NOT NULL
    AND user_id IS NOT NULL;