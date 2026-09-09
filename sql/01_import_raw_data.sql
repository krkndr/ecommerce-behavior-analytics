-- Create the staging table for raw e-commerce events
CREATE TABLE staging.raw_events (
    event_time TIMESTAMP,
    event_type VARCHAR(50),
    product_id BIGINT,
    category_id BIGINT,
    category_code VARCHAR(255),
    brand VARCHAR(255),
    price NUMERIC(10, 2),
    user_id BIGINT,
    user_session VARCHAR(255)
);

-- Load raw data from the CSV dump
COPY staging.raw_events FROM 'D:\KaggleData\2019-Oct.csv' DELIMITER ',' CSV HEADER;

