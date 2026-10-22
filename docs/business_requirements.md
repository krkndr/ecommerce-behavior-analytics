# Business requirements

The brief this project answers, written as a request from the business to the analytics team. Each section maps to a report page.

## 1. Business health → Executive Summary

A top-level view of October:

- **GMV**: total value of all products sold (`purchase` events × `price`).
- **Orders**: total number of orders.
- **AOV**: average order value (GMV / orders).
- **DAU, WAU, MAU**: unique active users per day, week and month.
- **ARPU and ARPPU**: revenue per user and revenue per paying user.
- **Peak hours and days**: on which weekdays and hours (UTC) traffic and sales are highest, for planning marketing campaigns.
- **Daily trend**: GMV by day from 1 to 31 October, with any unusual spikes or drops.

## 2. Sales funnel → Sales Funnel

Where the business loses money:

- **Overall conversion**: share of sessions that end with a purchase.
- **Step conversion**: view → cart and cart → purchase, plus the cart abandonment rate.
- **Time to purchase**: how long it takes from adding to cart to buying.
- **Loyalty**: share of customers with more than one order and their share of GMV.
- **Viewing depth**: how many products a user views per session.

## 3. Catalog and pricing → Catalog & Pricing

What to buy, promote or fix:

- **Top categories**: top categories by GMV and by units sold, using the category hierarchy in `category_code`.
- **Top brands**: top 10 brands by revenue.
- **Dead weight**: categories with many views but very few purchases. This signals problems with price, description or stock.
- **Price segments**: split products into < $10, $10–$50, $50–$200 and $200+. Which segment brings the most transactions and which brings the most money?

## 4. Abandoned carts → Cart Abandonment

- **Profile of abandoned carts**: which brands, categories and price segments are most often added to cart and not bought.
- **Price and drop-off**: is there a link between product price and the chance of being abandoned at the cart step?
- **Money at stake**: the value left in carts and how much of it is never recovered.
