/* ============================================================================
   06_data_validation.sql
   ----------------------------------------------------------------------------
   Purpose : Check the quality and integrity of the analytics layer and
             produce the reference values the Power BI measures must match.
   Input   : staging.raw_events, analytics.*
   Run     : after 03-05, one query at a time.
             Expected results are listed in docs/data_quality.md.
============================================================================ */

-- 1. Rows removed by cleaning (expected: 3 522)
SELECT
    (SELECT COUNT(*) FROM staging.raw_events)  AS raw_rows,
    (SELECT COUNT(*) FROM analytics.fact_events) AS fact_rows,
    (SELECT COUNT(*) FROM staging.raw_events) - (SELECT COUNT(*) FROM analytics.fact_events) AS removed_rows;

-- 2. GMV consistency: events vs sessions (both must be 229 933 212.63)
SELECT
    (SELECT SUM(price) FROM analytics.fact_events WHERE event_type = 'purchase') AS gmv_events,
    (SELECT SUM(gmv)   FROM analytics.fact_sessions)                             AS gmv_sessions;

-- 3. No purchases with price <= 0 in the fact table (expected: 0)
SELECT COUNT(*) AS bad_price_purchases
FROM analytics.fact_events
WHERE event_type = 'purchase' AND price <= 0;

-- 4. Referential integrity (both expected: 0)
SELECT
    (SELECT COUNT(*) FROM analytics.fact_events f
        LEFT JOIN analytics.dim_products p USING (product_id)
        WHERE p.product_id IS NULL) AS facts_without_product,
    (SELECT COUNT(*) FROM analytics.fact_events f
        LEFT JOIN analytics.dim_users u USING (user_id)
        WHERE u.user_id IS NULL)    AS facts_without_user;

-- 5. Date range of the fact table (expected: 2019-10-01 ... 2019-10-31)
SELECT MIN(event_date) AS first_date, MAX(event_date) AS last_date
FROM analytics.fact_events;

-- 6. Reference business metrics to reconcile with Power BI
SELECT
    COUNT(*) FILTER (WHERE has_purchase)                                  AS orders,
    COUNT(*)                                                              AS sessions,
    COUNT(DISTINCT user_id)                                               AS users_all,
    COUNT(DISTINCT user_id) FILTER (WHERE has_purchase)                   AS payers,
    ROUND(SUM(gmv), 2)                                                    AS gmv,
    ROUND(SUM(gmv) / COUNT(*) FILTER (WHERE has_purchase), 2)             AS aov,
    ROUND(SUM(gmv) / COUNT(DISTINCT user_id), 2)                          AS arpu,
    ROUND(SUM(gmv) / COUNT(DISTINCT user_id) FILTER (WHERE has_purchase), 2) AS arppu,
    ROUND(100.0 * COUNT(*) FILTER (WHERE has_purchase) / COUNT(*), 2)     AS session_cr_pct
FROM analytics.fact_sessions;
