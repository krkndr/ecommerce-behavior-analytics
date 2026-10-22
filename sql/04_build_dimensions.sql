/* ============================================================================
   04_build_dimensions.sql
   ----------------------------------------------------------------------------
   Purpose : Build the dimension tables.
             1) dim_products: one row per product, with brand and the
                category hierarchy split into levels
             2) dim_users: one row per user from the cleaned fact table
   Input   : staging.raw_events, analytics.fact_events
   Output  : analytics.dim_products, analytics.dim_users
   Depends : 03_build_fact_events.sql (dim_users is built from fact_events)
============================================================================ */

-- 1. dim_products (grain: one row = one product)
DROP TABLE IF EXISTS analytics.dim_products CASCADE;

CREATE TABLE analytics.dim_products AS
WITH RankedProducts AS (
    SELECT
        product_id,
        category_id,
        category_code,
        brand,
        price,
        ROW_NUMBER() OVER (
            PARTITION BY product_id
            ORDER BY
                -- Prefer rows with a filled category, then the most recent one
                (category_code IS NOT NULL AND category_code <> '') DESC,
                event_time DESC
        ) AS rn
    FROM staging.raw_events
    WHERE product_id IS NOT NULL
)
SELECT
    product_id,
    category_id,
    category_code,
    COALESCE(NULLIF(brand, ''), 'Unknown') AS brand,
    -- Last known price. Revenue must use fact_events.price instead.
    price AS last_price,
    -- Category hierarchy, e.g. 'electronics.smartphone'
    CASE
        WHEN category_code IS NULL OR category_code = '' THEN 'Other'
        ELSE SPLIT_PART(category_code, '.', 1)
    END AS category_level_1,
    CASE
        WHEN category_code IS NULL OR category_code = '' THEN 'Other'
        WHEN SPLIT_PART(category_code, '.', 2) = '' THEN SPLIT_PART(category_code, '.', 1)
        ELSE SPLIT_PART(category_code, '.', 2)
    END AS category_level_2
FROM RankedProducts
WHERE rn = 1;

ALTER TABLE analytics.dim_products ADD PRIMARY KEY (product_id);

-- 2. dim_users (grain: one row = one user, bot sessions excluded)
DROP TABLE IF EXISTS analytics.dim_users CASCADE;

CREATE TABLE analytics.dim_users AS
SELECT DISTINCT user_id
FROM analytics.fact_events;

ALTER TABLE analytics.dim_users ADD PRIMARY KEY (user_id);
