# KPI definitions

The single source of truth for every calculation in SQL and Power BI. Reference values come from `06_data_validation.sql`, and the Power BI measures match them.

## Key assumptions

- **Order = a session with a purchase** (`fact_sessions.has_purchase`). The data has no order ID, so several purchases in one session count as one order.
- **Revenue (GMV)** uses `fact_events.price` for `purchase` events, which is the price at the moment of purchase.
- **Users** are counted by `user_id`. All time breakdowns are in UTC.
- **Active user** = a user with at least one event (view, cart or purchase) in the period.

## Business health

| Metric | Definition | DAX measure | October 2019 |
|---|---|---|---:|
| GMV | Sum of `price` of all `purchase` events | `GMV` | $229 933 212.63 |
| Orders | Sessions with a purchase | `Total Orders` | 629 560 |
| Units sold | Number of `purchase` events | `Total Purchases` | 742 773 |
| AOV | GMV / orders | `AOV` | $365.23 |
| Payers | Unique `user_id` with at least one purchase | `Unique Payers` | 347 118 |
| Active users (MAU) | Unique `user_id` with any event | `Total Active Users (MAU)` | 3 022 061 |
| ARPU | GMV / all active users | `ARPU` | $76.08 |
| ARPPU | GMV / payers | `ARPPU` | $662.41 |
| Avg DAU | Average of daily unique users | `Avg DAU` | ≈ 209 000 |
| WAU | Unique users over a rolling 7-day window | `WAU (rolling 7d)` | per day, on a line chart |

Sanity check: ARPU is always lower than ARPPU because its denominator is larger.

The user measures ignore the `event_type` slicer (`REMOVEFILTERS`). Otherwise, selecting "cart" would count only users who added to cart, and ARPU and DAU would be wrong.

## Sales funnel

All funnel metrics are session based and use `fact_sessions`.

| Metric | Definition | DAX measure | October 2019 |
|---|---|---|---:|
| Session conversion rate | Sessions with a purchase / all sessions | `Session CR` | 6.81% |
| View → Cart | Sessions with a cart / sessions with a view | `View to Cart Rate` | ≈ 6.2% |
| Cart → Purchase | Sessions with **both** a cart and a purchase / sessions with a cart | `Cart to Purchase Rate` | ≈ 50.9% |
| Cart abandonment (sessions) | 1 − Cart → Purchase | `Cart Abandonment Rate` | 49.07% |
| Orders without a cart | Orders whose session had no `cart` event / all orders | `Orders without Cart %` | 53.64% |
| Time from cart to purchase | Average `minutes_to_next_step` for `cart → purchase` transitions | `Avg Minutes to Purchase` | 1.57 min |
| Viewing depth | Total views / sessions | `Avg Views per Session` | 4.41 |
| Unique products viewed | Average `distinct_products_viewed` in sessions with a view | `Avg Products Viewed per Session` | |

Why the funnel ends at 3.2% while session CR is 6.81%: more than half of orders (53.64%) happen without an add-to-cart event, so they never enter the view → cart → purchase path.

## Customer behaviour

| Metric | Definition | DAX measure |
|---|---|---|
| One-time buyers | Payers with exactly one order | `Buyers (1 Purchase)` |
| Repeat buyers | Payers with two or more orders (sessions with a purchase) | `Buyers (2+ Purchases)` |
| GMV of one-time / repeat buyers | GMV split by the same groups | `GMV (1 Purchase)`, `GMV (2+ Purchases)` |

In October 2019, repeat buyers were 32% of payers and brought 69% of GMV.

## Catalog and pricing

| Metric | Definition | DAX measure |
|---|---|---|
| Category conversion | Purchases / views of a category | `Category CR` |
| Dead weight | Categories with many views and the lowest conversion | `Category CR` on a table sorted ascending |
| Price segments | `fact_events.price_segment`: < $10, $10–$50, $50–$200, $200+ | `GMV`, `Total Purchases` |
| Top-2 brand concentration | GMV of the two brands with the most revenue (excluding `Unknown`) / total GMV | `Top 2 Brands GMV %` (≈ 69%) |

For price analysis based on views or carts, exclude rows with `price = 0` (see [data_quality.md](data_quality.md), section 3).

## Abandoned carts

Product level, from `fact_cart_items`. This is different from the session-level cart abandonment rate above.

| Metric | Definition | DAX measure | October 2019 |
|---|---|---|---:|
| Cart items | Products added to cart (unique per session) | `Cart Items` | ≈ 628 000 |
| Abandoned cart items | Cart items not bought in the same session | `Abandoned Cart Items` | ≈ 324 000 |
| Cart item abandonment rate | Abandoned cart items / cart items | `Cart Item Abandonment Rate` | 51.60% |
| Value left in carts | Sum of `cart_price` of abandoned cart items | `Abandoned Cart Value` | $108.20M |
| Never recovered | Value of abandoned items the user never bought later | `Lost Cart Value` | $92.64M |

The $15.6M difference is the value of items that users came back and bought in a later session.

## Measure folders in Power BI

| Folder | What is inside |
|---|---|
| 01_Business Health | GMV, orders, units sold, events |
| 02_Unit Economics | AOV, ARPU, ARPPU |
| 03_Active Users | MAU, payers, average DAU, rolling WAU |
| 04_Sales Funnel | Session funnel, conversion rates, cart abandonment, time to convert |
| 05_Catalog | Views, carts, category conversion, top-2 brand concentration |
| 06_User Behavior | One-time vs repeat buyers, viewing depth |
| 07_Abandoned Carts | Cart items, abandonment rate, value left and never recovered |
| 08_Traffic | Average events per day, highlight colour for the busiest weekday |
