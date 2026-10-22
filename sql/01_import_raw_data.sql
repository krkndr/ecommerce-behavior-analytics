/* ============================================================================
   01_import_raw_data.sql
   ----------------------------------------------------------------------------
   Purpose : Create the schemas and the staging table, then load the raw
             October 2019 events (REES46 eCommerce behavior data, Kaggle).
   Input   : 2019-Oct.csv (~42.4M rows, ~5.3 GB)
   Output  : staging.raw_events
   Note    : Update the file path in the COPY command to where the CSV is
             stored on your machine. The path is read by the PostgreSQL
             server, so the server needs access to it.
============================================================================ */

CREATE SCHEMA IF NOT EXISTS staging;   -- raw data, loaded as is
CREATE SCHEMA IF NOT EXISTS analytics; -- cleaned model used by Power BI

CREATE TABLE IF NOT EXISTS staging.raw_events (
    event_time    TIMESTAMP,
    event_type    VARCHAR(50),
    product_id    BIGINT,
    category_id   BIGINT,
    category_code VARCHAR(255),
    brand         VARCHAR(255),
    price         NUMERIC(10, 2),
    user_id       BIGINT,
    user_session  VARCHAR(255)
);

TRUNCATE TABLE staging.raw_events;

COPY staging.raw_events
FROM 'D:/KaggleData/2019-Oct.csv'
DELIMITER ',' CSV HEADER;

-- Expected: 42 448 764 rows
SELECT COUNT(*) AS loaded_rows FROM staging.raw_events;
