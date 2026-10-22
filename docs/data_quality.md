# Data quality

Findings from `02_exploratory_data_analysis.sql` (raw data) and `06_data_validation.sql` (final model). Data: October 2019, 42 448 764 events.

## 1. What the data contains

| Event type | Events | Share |
|---|---:|---:|
| view | 40 779 399 | 96.07% |
| cart | 926 516 | 2.18% |
| purchase | 742 849 | 1.75% |

Period: 2019-10-01 00:00:00 to 2019-10-31 23:59:59 (UTC).

The dataset description mentions `remove_from_cart` events, but the October file has none. So `fact_sessions.removes` is always 0, and the funnel is built on `view`, `cart` and `purchase`.

## 2. Missing values

| Field | Share empty |
|---|---:|
| category_code | 31.84% |
| brand | 14.40% |
| user_session | 0.00% |
| user_id | 0.00% |

Handling: an empty category becomes `Other`, an empty brand becomes `Unknown`. There are no purchases without a session.

## 3. Zero prices

| Event type | Rows with price = 0 |
|---|---:|
| view | 68 523 |
| cart | 150 |
| purchase | 0 |

68 673 rows in total (0.16%). No purchase has a zero price, so GMV is not affected. View and cart rows stay in the fact table because they are real browsing behaviour.

**Limitation:** in `fact_events` these rows fall into the `1. < $10 (Low)` segment. Price analysis based on views or carts should exclude them with `price > 0`. `fact_cart_items` already puts them in a separate `5. Unknown` segment.

## 4. Bot traffic

Rule: a session with more than 500 events. 4 sessions were found, none with a purchase.

| Events | Duration | Purchases |
|---:|---|---:|
| 1 159 | ≈ 6.4 days | 0 |
| 1 137 | ≈ 6.1 hours | 0 |
| 584 | ≈ 9.2 hours | 0 |
| 564 | ≈ 2.8 hours | 0 |

### Threshold sensitivity

| Threshold (events per session) | Sessions removed | Events removed | Share of events |
|---:|---:|---:|---:|
| 100 | 2 398 | 318 884 | 0.7512% |
| 200 | 112 | 30 711 | 0.0723% |
| 300 | 23 | 9 970 | 0.0235% |
| **500** | **4** | **3 444** | **0.0081%** |
| 1 000 | 2 | 2 296 | 0.0054% |

The 500 threshold is deliberately conservative. There is no clear line between people and bots in the data, and lower thresholds risk removing very active real users. None of the removed sessions had purchases, so the filter does not change GMV, orders or conversion. It only removes a negligible number of views.

## 5. Duplicate purchases

Rule: the same `user_id`, `user_session`, `product_id` and `event_time` (to the second) for a `purchase`.

76 such duplicates were found. This is the difference between raw (742 849) and cleaned (742 773) purchases. One row of each group is kept.

**Assumption:** the data has no quantity column. Two real purchases of the same product in the same second are therefore treated as one. Impact is small: 76 of 742 849 rows (0.01%).

**Worth checking:** many duplicates fall into a short window on 2019-10-25, roughly 12:07–12:14 UTC. This may point to a short logging issue.

Duplicates of views and carts are kept. Their impact is minimal, and removing them could delete real repeated views.

## 6. Price changes

57 550 products changed price during the month. That is why GMV uses `fact_events.price` (the price at the moment of purchase) and not the product's last price.

Effect: GMV based on the last known price would be 227 021 598.07. GMV based on the price at purchase is 229 933 212.63. The difference is +2.91M (+1.28%).

## 7. Impact of cleaning

| | Rows |
|---|---:|
| Raw data | 42 448 764 |
| After cleaning (`fact_events`) | 42 445 242 |
| Removed | 3 522 |

What was removed:

- 3 444 rows: bot sessions
- 76 rows: duplicate purchases
- 2 rows: empty `product_id`, `user_id` or `user_session`

## 8. Integrity checks on the final model

| Check | Result |
|---|---|
| GMV from events = GMV from sessions | 229 933 212.63 in both |
| Purchases with price ≤ 0 in the fact table | 0 |
| Facts without a product in `dim_products` | 0 |
| Facts without a user in `dim_users` | 0 |
| Date range of the fact table | 2019-10-01 … 2019-10-31 |
| Power BI measures vs SQL reference values | Match (see [kpi_definitions.md](kpi_definitions.md)) |
