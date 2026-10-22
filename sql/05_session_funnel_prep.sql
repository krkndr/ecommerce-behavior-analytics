/* ============================================================================
   05_session_funnel_prep.sql
   ----------------------------------------------------------------------------
   Purpose : Build the tables behind the funnel, session and cart analysis.
             1) fact_funnel_steps : step-to-step transitions per product in a
                                    session (LEAD window function)
             2) fact_sessions     : one row per session (CR, AOV, time to
                                    purchase, viewing depth).
                                    An order = a session with a purchase.
             3) fact_cart_items   : one row per product added to cart in a
                                    session (abandoned cart analysis)
   Input   : analytics.fact_events
   Output  : analytics.fact_funnel_steps, analytics.fact_sessions,
             analytics.fact_cart_items
   Depends : 03_build_fact_events.sql
============================================================================ */

-- ----------------------------------------------------------------------------
-- 1. fact_funnel_steps
--    Grain: one row = a move between two different consecutive steps of
--    one product within a session (e.g. view -> cart).
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS analytics.fact_funnel_steps CASCADE;

CREATE TABLE analytics.fact_funnel_steps AS
WITH UserJourney AS (
    SELECT
        user_session,
        user_id,
        product_id,
        event_type AS current_step,
        event_time AS step_time,
        LEAD(event_type) OVER w AS next_step,
        LEAD(event_time) OVER w AS next_step_time
    FROM analytics.fact_events
    WINDOW w AS (
        PARTITION BY user_session, product_id
        ORDER BY event_time,
                 -- Tie-breaker: if two steps share a timestamp, use the
                 -- logical order of the funnel
                 CASE event_type
                     WHEN 'view'             THEN 1
                     WHEN 'cart'             THEN 2
                     WHEN 'remove_from_cart' THEN 3
                     WHEN 'purchase'         THEN 4
                     ELSE 5
                 END
    )
)
SELECT
    user_session,
    user_id,
    product_id,
    current_step,
    next_step,
    step_time,
    next_step_time,
    -- Time between the two steps, in minutes
    ROUND(CAST(EXTRACT(EPOCH FROM (next_step_time - step_time)) / 60.0 AS NUMERIC), 2)
        AS minutes_to_next_step
FROM UserJourney
WHERE next_step IS NOT NULL
  AND current_step <> next_step;   -- skip repeats in a row (view -> view)

-- Date column for the relationship with dim_date in Power BI
ALTER TABLE analytics.fact_funnel_steps
ADD COLUMN step_date date GENERATED ALWAYS AS (step_time::date) STORED;

CREATE INDEX idx_funnel_session ON analytics.fact_funnel_steps(user_session);
CREATE INDEX idx_funnel_date    ON analytics.fact_funnel_steps(step_date);

-- ----------------------------------------------------------------------------
-- 2. fact_sessions
--    Grain: one row = one session. Primary key: user_session.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS analytics.fact_sessions CASCADE;

CREATE TABLE analytics.fact_sessions AS
SELECT
    user_session,
    MIN(user_id)                                                    AS user_id,
    MIN(event_time)                                                 AS session_start,
    MAX(event_time)                                                 AS session_end,
    DATE(MIN(event_time))                                           AS session_date,
    COUNT(*) FILTER (WHERE event_type = 'view')                     AS views,
    COUNT(*) FILTER (WHERE event_type = 'cart')                     AS carts,
    COUNT(*) FILTER (WHERE event_type = 'remove_from_cart')         AS removes,
    COUNT(*) FILTER (WHERE event_type = 'purchase')                 AS items_purchased,
    COUNT(DISTINCT product_id) FILTER (WHERE event_type = 'view')   AS distinct_products_viewed,
    COALESCE(SUM(price) FILTER (WHERE event_type = 'purchase'), 0)  AS gmv,
    (COUNT(*) FILTER (WHERE event_type = 'cart') > 0)               AS has_cart,
    (COUNT(*) FILTER (WHERE event_type = 'purchase') > 0)           AS has_purchase,
    MIN(event_time) FILTER (WHERE event_type = 'cart')              AS first_cart_time,
    MIN(event_time) FILTER (WHERE event_type = 'purchase')          AS first_purchase_time
FROM analytics.fact_events
GROUP BY user_session;

ALTER TABLE analytics.fact_sessions ADD PRIMARY KEY (user_session);
CREATE INDEX idx_sessions_user ON analytics.fact_sessions(user_id);
CREATE INDEX idx_sessions_date ON analytics.fact_sessions(session_date);

-- ----------------------------------------------------------------------------
-- 3. fact_cart_items
--    Grain: one row = one product added to cart in a session.
--    purchased_same_session = FALSE  -> abandoned cart item
--    purchased_later        = TRUE   -> the same user bought the product in
--                                       any session after adding it
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS analytics.fact_cart_items CASCADE;

CREATE TABLE analytics.fact_cart_items AS
WITH carts AS (
    SELECT
        user_session,
        product_id,
        MIN(user_id)    AS user_id,
        MIN(event_time) AS first_cart_time,
        COUNT(*)        AS cart_events,
        -- Price at the moment of the first add to cart
        (ARRAY_AGG(price ORDER BY event_time))[1] AS cart_price
    FROM analytics.fact_events
    WHERE event_type = 'cart'
    GROUP BY user_session, product_id
),
purchases_session AS (
    SELECT user_session, product_id, MAX(event_time) AS last_purchase_time
    FROM analytics.fact_events
    WHERE event_type = 'purchase'
    GROUP BY user_session, product_id
),
purchases_user AS (
    SELECT user_id, product_id, MAX(event_time) AS last_purchase_time
    FROM analytics.fact_events
    WHERE event_type = 'purchase'
    GROUP BY user_id, product_id
)
SELECT
    c.user_session,
    c.user_id,
    c.product_id,
    c.first_cart_time,
    DATE(c.first_cart_time) AS cart_date,
    c.cart_events,
    c.cart_price,
    -- Zero-price cart rows go to a separate segment so they do not
    -- distort the "< $10" segment
    CASE
        WHEN c.cart_price <= 0  THEN '5. Unknown'
        WHEN c.cart_price < 10  THEN '1. < $10 (Low)'
        WHEN c.cart_price < 50  THEN '2. $10 - $50 (Mid)'
        WHEN c.cart_price < 200 THEN '3. $50 - $200 (High)'
        ELSE                         '4. $200+ (Premium)'
    END AS price_segment,
    -- Was the product bought after the first add to cart?
    COALESCE(ps.last_purchase_time >= c.first_cart_time, FALSE) AS purchased_same_session,
    COALESCE(pu.last_purchase_time >= c.first_cart_time, FALSE) AS purchased_later
FROM carts c
LEFT JOIN purchases_session ps
       ON ps.user_session = c.user_session AND ps.product_id = c.product_id
LEFT JOIN purchases_user pu
       ON pu.user_id = c.user_id AND pu.product_id = c.product_id;

ALTER TABLE analytics.fact_cart_items ADD PRIMARY KEY (user_session, product_id);
CREATE INDEX idx_cart_items_product ON analytics.fact_cart_items(product_id);
CREATE INDEX idx_cart_items_date    ON analytics.fact_cart_items(cart_date);
