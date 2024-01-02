--Pizza Runner
--00 - Initial Cleaning
--CTEs of the cleaned tables
WITH cleanedRunnerOrders AS (
    SELECT CAST(order_id AS integer) AS order_id, CAST(runner_id AS integer) AS runner_id, NULLIF(pickup_time,'null') AS pickup_time, CAST(NULLIF(REPLACE(distance,'km',''),'null') AS numeric) AS distance_km, CAST(NULLIF(LEFT(duration,2),'nu') AS integer) AS duration_min, CASE WHEN RIGHT(cancellation,12) = 'Cancellation' THEN cancellation ELSE NULL END AS cancellation
    FROM pizza_runner.runner_orders
),

cleanedCustomerOrders AS (
    SELECT CAST(order_id AS integer) AS order_id, CAST(customer_id AS integer) AS customer_id, CAST(pizza_id AS integer) AS pizza_id, NULLIF(NULLIF(exclusions,'null'),'') AS exclusions, NULLIF(NULLIF(extras,'null'),'') AS extras, order_time
    FROM pizza_runner.customer_orders
)


--A - Pizza Metrics
--A1
SELECT COUNT(pizza_id)
FROM cleanedCustomerOrders;

--A2 - counting as unique order ids
SELECT COUNT(DISTINCT order_id)
FROM cleanedCustomerOrders;

--A3
SELECT runner_id, COUNT(*)
FROM cleanedRunnerOrders
WHERE cancellation IS NULL
GROUP BY runner_id;

--A4
SELECT p.pizza_name, COUNT(*)
FROM cleanedCustomerOrders c
JOIN cleanedRunnerOrders r
ON c.order_id = r.order_id
JOIN pizza_runner.pizza_names p
ON c.pizza_id = p.pizza_id
WHERE r.cancellation IS NULL
GROUP BY p.pizza_name;

--A5
SELECT c.customer_id, p.pizza_name, COUNT(*)
FROM cleanedCustomerOrders c
JOIN cleanedRunnerOrders r
ON c.order_id = r.order_id
JOIN pizza_runner.pizza_names p
ON c.pizza_id = p.pizza_id
WHERE r.cancellation IS NULL
GROUP BY c.customer_id, p.pizza_name
ORDER BY c.customer_id;


--A6
SELECT c.order_id, COUNT(*) As num_pizzas_ordered
FROM cleanedCustomerOrders c
JOIN cleanedRunnerOrders r
ON c.order_id = r.order_id
WHERE r.cancellation IS NULL
GROUP BY c.order_id
ORDER BY num_pizzas_ordered DESC
LIMIT 1;

--A7
SELECT c.customer_id, CASE WHEN c.exclusions IS NULL AND c.extras IS NULL THEN 'unmodified' ELSE 'modified' END AS modification_status, COUNT(*)
FROM cleanedCustomerOrders c
JOIN cleanedRunnerOrders r
ON c.order_id = r.order_id
WHERE r.cancellation IS NULL
GROUP BY c.customer_id, modification_status
ORDER BY c.customer_id, modification_status;

--A8
SELECT CASE WHEN c.exclusions IS NOT NULL AND c.extras IS NOT NULL THEN 'exclusions and extras' ELSE NULL END AS modification_status, COUNT(*)
FROM cleanedCustomerOrders c
JOIN cleanedRunnerOrders r
ON c.order_id = r.order_id
WHERE r.cancellation IS NULL AND CASE WHEN c.exclusions IS NOT NULL AND c.extras IS NOT NULL THEN 'exclusions and extras' ELSE NULL END = 'exclusions and extras'
GROUP BY modification_status;

--A9
SELECT EXTRACT(HOUR FROM order_time) AS hour, COUNT(*)
FROM cleanedCustomerOrders
GROUP BY hour
ORDER BY hour;

--A10
SELECT EXTRACT(dow FROM order_time) AS dow, COUNT(*)
FROM cleanedCustomerOrders
GROUP BY dow
ORDER BY dow;


--B - Runner and Customer Experience
--B1 - week starting Jan 1st
SELECT to_char(registration_date, 'ww') AS week, COUNT(*)
FROM pizza_runner.runners
GROUP BY week
ORDER BY week;

--B2
cte AS (
SELECT DISTINCT c.order_id, r.runner_id, EXTRACT(minute from r.pickup_time::TIMESTAMP - c.order_time::TIMESTAMP) AS minutes
FROM cleanedCustomerOrders c
JOIN cleanedRunnerOrders r
ON c.order_id = r.order_id
WHERE r.pickup_time IS NOT NULL
)

SELECT runner_id, AVG(minutes)
FROM cte
GROUP BY runner_id
ORDER BY runner_id;

--B3 - yes, more pizzas = more time. however the repeated averaging could have distored things slightly
cte AS (
SELECT DISTINCT c.order_id, COUNT(c.order_id) AS num_pizzas, AVG(EXTRACT(minute from r.pickup_time::TIMESTAMP - c.order_time::TIMESTAMP)) AS avg_minutes
FROM cleanedCustomerOrders c
JOIN cleanedRunnerOrders r
ON c.order_id = r.order_id
WHERE r.pickup_time IS NOT NULL
GROUP BY c.order_id
)

SELECT num_pizzas, AVG(avg_minutes)
FROM cte
GROUP BY num_pizzas
ORDER BY num_pizzas;

--B4
SELECT c.customer_id, ROUND(AVG(r.distance_km),2) AS avg_distance_km
FROM cleanedRunnerOrders r
JOIN cleanedCustomerOrders c
ON r.order_id = c.order_id
WHERE r.distance_km IS NOT NULL
GROUP BY c.customer_id
ORDER BY c.customer_id;

--B5
SELECT MAX(duration_min) - MIN(duration_min) AS difference
FROM cleanedRunnerOrders;

--B6 - runner 2 is much faster
SELECT runner_id, ROUND(AVG(distance_km/duration_min),2) AS avg_speed
FROM cleanedRunnerOrders
GROUP BY runner_id
ORDER BY runner_id;

--B7
SELECT runner_id, ROUND(AVG(CASE WHEN cancellation IS NULL THEN 0 ELSE 1 END),2) AS delivered_percent
FROM cleanedRunnerOrders
GROUP BY runner_id
ORDER BY runner_id;


--C - Ingredient Optimization
--C1
topnum AS (
SELECT n.pizza_name, REGEXP_SPLIT_TO_TABLE(r.toppings , ', ')::integer AS top_id
FROM pizza_runner.pizza_recipes r
JOIN pizza_runner.pizza_names n
ON r.pizza_id = n.pizza_id
)

SELECT topnum.pizza_name, array_to_string(array_agg(t.topping_name),', ')
FROM topnum
JOIN pizza_runner.pizza_toppings t
ON topnum.top_id = t.topping_id
GROUP BY topnum.pizza_name;

--C2 - IT'S BACON!!!1
idList AS (
SELECT regexp_split_to_table(c.extras,', ')::integer AS topping_id
FROM cleanedCustomerOrders c
WHERE extras IS NOT NULL)

SELECT t.topping_name, COUNT(*)
FROM idList i
JOIN pizza_runner.pizza_toppings t
ON i.topping_id = t.topping_id
GROUP BY t.topping_name
ORDER BY count DESC
LIMIT 1;

--C3 - Cheese
idList AS (
SELECT regexp_split_to_table(c.exclusions,', ')::integer AS topping_id
FROM cleanedCustomerOrders c
WHERE c.exclusions IS NOT NULL)

SELECT t.topping_name, COUNT(*)
FROM idList i
JOIN pizza_runner.pizza_toppings t
ON i.topping_id = t.topping_id
GROUP BY t.topping_name
ORDER BY count DESC
LIMIT 1;

--C4 - ***NOT DONE***
SELECT c.order_id, ROW_NUMBER() OVER(PARTITION BY c.order_id) AS pizza_number_in_order, STRING_TO_ARRAY(c.exclusions, ', ') AS exclusions,STRING_TO_ARRAY(c.extras, ', ') AS extras
FROM cleanedCustomerOrders c;

/*
SELECT c.order_id,
CASE 
WHEN c.exclusions IS NULL AND c.extras IS NULL THEN n.pizza_name 
WHEN c.exclusions IS NOT NULL AND c.extras IS NULL THEN CONCAT(n.pizza_name, ' - Exclude ')
WHEN c.exclusions IS NULL AND c.extras IS NOT NULL THEN CONCAT(n.pizza_name, ' - Extra ')
WHEN c.exclusions IS NOT NULL AND c.extras IS NOT NULL THEN CONCAT(n.pizza_name, ' - Exclude ', ' - Extra ')
END AS order_item 
FROM cleanedCustomerOrders c
JOIN pizza_runner.pizza_names n
ON c.pizza_id = n.pizza_id
ORDER BY c.order_id;*/

--C5

--C6

--D - Pricing and Rating
--D1 - $138
dollarsTable AS (
SELECT p.pizza_name, COUNT(*), CASE WHEN p.pizza_name = 'Meatlovers' THEN COUNT(*)*12 WHEN p.pizza_name = 'Vegetarian' THEN COUNT(*)*10 END AS dollars
FROM cleanedCustomerOrders c
JOIN cleanedRunnerOrders r
ON c.order_id = r.order_id
JOIN pizza_runner.pizza_names p
ON c.pizza_id = p.pizza_id
WHERE r.cancellation IS NULL
GROUP BY p.pizza_name)

SELECT SUM(dollars)
FROM dollarsTable;

--D2 - $142 - some of the extras were canceled, also not sure what was meant by  adding cheese
dollarsTable AS (
SELECT p.pizza_name,
COUNT(*), CASE WHEN p.pizza_name = 'Meatlovers' THEN COUNT(*)*12 + SUM(LENGTH(REPLACE(c.extras, ', ', ''))) WHEN p.pizza_name = 'Vegetarian' THEN COUNT(*)*10 + SUM(LENGTH(REPLACE(c.extras, ', ', ''))) END AS dollars
FROM cleanedCustomerOrders c
JOIN cleanedRunnerOrders r
ON c.order_id = r.order_id
JOIN pizza_runner.pizza_names p
ON c.pizza_id = p.pizza_id
WHERE r.cancellation IS NULL
GROUP BY p.pizza_name)

SELECT SUM(dollars)
FROM dollarsTable;

--D3 - should just need a table of order_id and rating (re: 9 - a customer cancellation probably wouldn't have a rating)
DROP TABLE IF EXISTS ratings;
CREATE TABLE ratings (
  "order_id" INTEGER,
  "rating"  INTEGER
);
INSERT INTO ratings
	("order_id", "rating")
VALUES
  (1, 4),
  (2, 5),
  (3, 3),
  (4, 2),
  (5, 5),
  (6, 1),
  (7, 4),
  (8, 1),
  (9, NULL),
  (10, 5);

  --D4
SELECT DISTINCT ra.order_id, c.customer_id, ru.runner_id, ra.rating, ru.pickup_time, DATE_PART('minute',ru.pickup_time::timestamp - c.order_time::timestamp) AS time_btwn_order_pickup_min, ru.duration_min, ROUND(ru.distance_km/ru.duration_min,2) AS avg_speed_km_per_min, COUNT(c.pizza_id) AS num_pizzas
FROM ratings ra
JOIN cleanedRunnerOrders ru
ON ra.order_id = ru.order_id
JOIN cleanedCustomerOrders c
ON ru.order_id = c.order_id
GROUP BY ra.order_id, c.customer_id, ru.runner_id, ra.rating, ru.pickup_time, time_btwn_order_pickup_min, ru.duration_min, avg_speed_km_per_min;

--D5
netearn AS (
SELECT c.order_id, SUM(CASE WHEN n.pizza_name = 'Meatlovers' THEN 12 WHEN n.pizza_name = 'Vegetarian' THEN 10 END) - (r.distance_km * 0.3) AS net_earnings
FROM cleanedCustomerOrders c
JOIN pizza_runner.pizza_names n
ON c.pizza_id = n.pizza_id
JOIN cleanedRunnerOrders r
ON c.order_id = r.order_id
WHERE r.cancellation IS NULL
GROUP BY c.order_id, r.distance_km
ORDER BY c.order_id)

SELECT SUM(net_earnings) AS net_earnings
FROM netearn;

--E - Bonus Questions
INSERT INTO pizza_names
	("pizza_id", "pizza_name")
VALUES
	(3, 'Supreme');

INSERT INTO pizza_recipes
  ("pizza_id", "toppings")
VALUES
  (3, '1, 2, 3, 4, 5, 6, 7, 8, 9, 10');
