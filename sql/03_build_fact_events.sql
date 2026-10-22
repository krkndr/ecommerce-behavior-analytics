/* ============================================================================
   03_build_fact_events.sql
   ----------------------------------------------------------------------------
   Purpose : Build the cleaned event fact table.
             - removes bot sessions (more than 500 events)
             - removes duplicate purchases (same session, product and second)
             - removes purchases with price <= 0
             - removes rows without product_id, user_id or user_session
             - adds event_date, event_hour and price_segment
   Input   : staging.raw_events
   Output  : analytics.fact_events (grain: one row = one event)
   Depends : 01_import_raw_data.sql
============================================================================ */

DROP TABLE IF EXISTS analytics.fact_events CASCADE;

CREATE TABLE analytics.fact_events AS
WITH BotSessions AS (
    SELECT user_session
    FROM staging.raw_events
    WHERE user_session IS NOT NULL
    GROUP BY user_session
    HAVING COUNT(*) > 500
),
Ranked AS (
    SELECT
        event_time,
        event_type,
        product_id,
        user_id,
        user_session,
        price,
        -- 1 = first copy of an event; > 1 = duplicate in the same second
        ROW_NUMBER() OVER (
            PARTITION BY user_session, product_id, event_type, event_time
            ORDER BY event_time
        ) AS click_rank
    FROM staging.raw_events
    WHERE product_id   IS NOT NULL
      AND user_id      IS NOT NULL
      AND user_session IS NOT NULL
)
SELECT
    r.event_time,
    DATE(r.event_time)                                 AS event_date,
    CAST(EXTRACT(HOUR FROM r.event_time) AS INTEGER)   AS event_hour,
    r.event_type,
    r.product_id,
    r.user_id,
    r.user_session,
    r.price,
    -- The number prefix keeps the segments in the right order in Power BI
    CASE
        WHEN r.price < 10  THEN '1. < $10 (Low)'
        WHEN r.price < 50  THEN '2. $10 - $50 (Mid)'
        WHEN r.price < 200 THEN '3. $50 - $200 (High)'
        ELSE                    '4. $200+ (Premium)'
    END AS price_segment
FROM Ranked r
WHERE
    -- Deduplicate purchases only; repeated views and carts are real behaviour
    (r.event_type <> 'purchase' OR r.click_rank = 1)
    AND NOT (r.event_type = 'purchase' AND r.price <= 0)
    -- Remove bot sessions
    AND NOT EXISTS (
        SELECT 1 FROM BotSessions b WHERE b.user_session = r.user_session
    );

-- Indexes for fast filtering from Power BI (DirectQuery)
CREATE INDEX idx_fact_product ON analytics.fact_events(product_id);
CREATE INDEX idx_fact_user    ON analytics.fact_events(user_id);
CREATE INDEX idx_fact_date    ON analytics.fact_events(event_date);
CREATE INDEX idx_fact_session ON analytics.fact_events(user_session);
CREATE INDEX idx_fact_type    ON analytics.fact_events(event_type);
