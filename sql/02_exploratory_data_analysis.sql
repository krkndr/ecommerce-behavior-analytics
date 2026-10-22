/* ============================================================================
   02_exploratory_data_analysis.sql
   ----------------------------------------------------------------------------
   Purpose : Profile the raw data before modelling. Find gaps, price
             anomalies, bot traffic, tracking errors and duplicates.
   Input   : staging.raw_events (read only)
   Output  : none. Results are summarised in docs/data_quality.md
============================================================================ */

-- 1. Overview: event types and date range
SELECT
    event_type,
    COUNT(*)                AS events,
    MIN(event_time)         AS first_event,
    MAX(event_time)         AS last_event
FROM staging.raw_events
GROUP BY event_type
ORDER BY events DESC;

-- 2. Missing values in key fields (% of NULL or empty)
SELECT
    COUNT(*)                                                                     AS total_rows,
    ROUND(100.0 * COUNT(*) FILTER (WHERE category_code IS NULL OR category_code = '') / COUNT(*), 2) AS pct_no_category_code,
    ROUND(100.0 * COUNT(*) FILTER (WHERE brand IS NULL OR brand = '') / COUNT(*), 2)                 AS pct_no_brand,
    ROUND(100.0 * COUNT(*) FILTER (WHERE user_session IS NULL OR user_session = '') / COUNT(*), 2)   AS pct_no_session,
    ROUND(100.0 * COUNT(*) FILTER (WHERE user_id IS NULL) / COUNT(*), 2)                             AS pct_no_user
FROM staging.raw_events;

-- 3. Price anomalies (zero or negative prices) by event type
SELECT
    event_type,
    COUNT(*)   AS count_of_anomalies,
    MIN(price) AS min_price,
    MAX(price) AS max_price
FROM staging.raw_events
WHERE price <= 0
GROUP BY event_type;

-- 4. Bot traffic: sessions with an abnormal number of events (> 500)
SELECT
    user_id,
    user_session,
    COUNT(*)                                                    AS total_events,
    COUNT(*) FILTER (WHERE event_type = 'purchase')             AS total_purchases,
    MIN(event_time)                                             AS session_start,
    MAX(event_time)                                             AS session_end,
    EXTRACT(EPOCH FROM (MAX(event_time) - MIN(event_time))) / 60 AS session_duration_minutes
FROM staging.raw_events
GROUP BY user_id, user_session
HAVING COUNT(*) > 500
ORDER BY total_events DESC;

-- 5. Bot threshold sensitivity: sessions and events removed by each threshold
WITH s AS (
    SELECT user_session, COUNT(*) AS n
    FROM staging.raw_events
    WHERE user_session IS NOT NULL
    GROUP BY user_session
)
SELECT
    t.threshold,
    COUNT(*) FILTER (WHERE s.n > t.threshold)                                       AS sessions_cut,
    SUM(s.n) FILTER (WHERE s.n > t.threshold)                                       AS events_cut,
    ROUND(100.0 * SUM(s.n) FILTER (WHERE s.n > t.threshold) / SUM(s.n), 4)          AS pct_of_events
FROM s
CROSS JOIN (VALUES (100), (200), (300), (500), (1000)) AS t(threshold)
GROUP BY t.threshold
ORDER BY t.threshold;

-- 6. Tracking errors: purchases without a session
SELECT COUNT(*) AS missing_session_purchases
FROM staging.raw_events
WHERE event_type = 'purchase'
  AND (user_session IS NULL OR user_session = '');

-- 7. Duplicate purchases (double click: same purchase in the same second)
SELECT
    user_id,
    user_session,
    product_id,
    event_time,
    COUNT(*) AS duplicate_purchases
FROM staging.raw_events
WHERE event_type = 'purchase'
GROUP BY user_id, user_session, product_id, event_time
HAVING COUNT(*) > 1
ORDER BY duplicate_purchases DESC
LIMIT 100;

-- 8. Products whose price changed during the month
SELECT COUNT(*) AS products_with_price_changes
FROM (
    SELECT product_id
    FROM staging.raw_events
    GROUP BY product_id
    HAVING MIN(price) <> MAX(price)
) t;
