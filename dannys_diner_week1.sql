/* --------------------
   Case Study Questions
   --------------------*/

-- 1. What is the total amount each customer spent at the restaurant?
-- 2. How many days has each customer visited the restaurant?
-- 3. What was the first item from the menu purchased by each customer?
-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
-- 5. Which item was the most popular for each customer?
-- 6. Which item was purchased first by the customer after they became a member?
-- 7. Which item was purchased just before the customer became a member?
-- 8. What is the total items and amount spent for each member before they became a member?
-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

--1
SELECT
  	s.customer_id, SUM(m.price) AS total_amt_spent
FROM dannys_diner.sales s
INNER JOIN 
dannys_diner.menu m
ON s.product_id = m.product_id
GROUP BY s.customer_id;

--2
SELECT s.customer_id, COUNT(DISTINCT s.order_date)
FROM dannys_diner.sales s
GROUP BY s.customer_id;

--3
WITH cte AS (
SELECT s.customer_id, RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) rank, m.product_name, ROW_NUMBER() OVER(PARTITION BY s.customer_id, m.product_name ORDER BY s.order_date) row_number_for_duplicates
FROM dannys_diner.sales s
INNER JOIN dannys_diner.menu m
ON s.product_id = m.product_id)

SELECT customer_id, product_name 
FROM cte
WHERE rank = 1
AND row_number_for_duplicates = 1;

--4
SELECT m.product_name, COUNT(s.product_id) AS times_purchased
FROM dannys_diner.menu m
INNER JOIN dannys_diner.sales s
ON m.product_id = s.product_id
GROUP BY m.product_name;

--5
WITH cte AS (
SELECT s.customer_id, m.product_name, COUNT(s.product_id) AS times_purchased
FROM dannys_diner.menu m
INNER JOIN dannys_diner.sales s
ON m.product_id = s.product_id
GROUP BY s.customer_id, m.product_name),

cte2 AS(
SELECT customer_id, product_name, times_purchased, RANK() OVER(PARTITION BY customer_id ORDER BY times_purchased DESC)
FROM cte)

SELECT *
FROM cte2
WHERE rank = 1;


--6
WITH cte AS (
SELECT e.customer_id, e.join_date, s.order_date, s.product_id, m.product_name, RANK() OVER(PARTITION BY e.customer_id ORDER BY s.order_date) ord
FROM dannys_diner.members e
INNER JOIN dannys_diner.sales s
ON e.customer_id = s.customer_id
INNER JOIN dannys_diner.menu m
ON s.product_id = m.product_id
WHERE e.join_date <= s.order_date
ORDER BY s.order_date)

SELECT customer_id, product_name
FROM cte
WHERE ord = 1;

--7
WITH cte AS (
SELECT e.customer_id, e.join_date, s.order_date, s.product_id, m.product_name, RANK() OVER(PARTITION BY e.customer_id ORDER BY s.order_date DESC) ord
FROM dannys_diner.members e
INNER JOIN dannys_diner.sales s
ON e.customer_id = s.customer_id
INNER JOIN dannys_diner.menu m
ON s.product_id = m.product_id
WHERE e.join_date >= s.order_date
ORDER BY s.order_date)


SELECT customer_id, product_name
FROM cte
WHERE ord = 1;

--8
SELECT e.customer_id, COUNT(*) AS total_items, SUM(m.price) AS total_spent
FROM dannys_diner.members e
INNER JOIN dannys_diner.sales s
ON e.customer_id = s.customer_id
INNER JOIN dannys_diner.menu m
ON s.product_id = m.product_id
WHERE s.order_date < e.join_date
GROUP BY e.customer_id;

--9
WITH cte AS (
SELECT s.customer_id, SUM(m.price * 20) AS points
FROM dannys_diner.sales s
INNER JOIN dannys_diner.menu m
ON s.product_id = m.product_id
WHERE m.product_name = 'sushi'
GROUP BY s.customer_id
UNION ALL
SELECT s.customer_id, SUM(m.price * 10) AS points
FROM dannys_diner.sales s
INNER JOIN dannys_diner.menu m
ON s.product_id = m.product_id
WHERE m.product_name <> 'sushi'
GROUP BY s.customer_id)

SELECT customer_id, SUM(points)
FROM cte
WHERE customer_id IN ('A','B')
GROUP BY customer_id;


--10
WITH cte AS (
SELECT e.customer_id, e.join_date, e.join_date + 7 AS join_date_plus7, s.order_date, m.price, m.price * 20 AS points
FROM dannys_diner.members e
INNER JOIN dannys_diner.sales s
ON e.customer_id = s.customer_id
INNER JOIN dannys_diner.menu m
ON s.product_id = m.product_id
WHERE (s.order_date >= e.join_date AND s.order_date < e.join_date + 7) OR m.product_name = 'sushi'
UNION
SELECT e.customer_id, e.join_date, e.join_date + 7 AS join_date_plus7, s.order_date, m.price, m.price * 10 AS points
FROM dannys_diner.members e
INNER JOIN dannys_diner.sales s
ON e.customer_id = s.customer_id
INNER JOIN dannys_diner.menu m
ON s.product_id = m.product_id
WHERE m.product_name <> 'sushi' AND (s.order_date < e.join_date OR s.order_date > e.join_date + 7))

SELECT customer_id, SUM(points)
FROM cte
WHERE order_date < '2021-02-01'
GROUP BY customer_id;

Bonus Questions

Join All the Things
SELECT s.customer_id, s.order_date, m.product_name, m.price, CASE WHEN e.join_date IS NULL THEN 'N' ELSE 'Y' END AS member
FROM dannys_diner.sales s
INNER JOIN dannys_diner.menu m
ON s.product_id = m.product_id
LEFT JOIN dannys_diner.members e
ON s.customer_id = e.customer_id;

Rank All the Things
SELECT s.customer_id, s.order_date, m.product_name, m.price, CASE WHEN e.join_date <= s.order_date THEN 'Y' ELSE 'N' END AS member, CASE WHEN e.join_date <= s.order_date THEN RANK() OVER(PARTITION BY e.customer_id ORDER BY s.order_date) ELSE null END AS ranking
FROM dannys_diner.members e
RIGHT JOIN dannys_diner.sales s
ON e.customer_id = s.customer_id
INNER JOIN dannys_diner.menu m
ON s.product_id = m.product_id;