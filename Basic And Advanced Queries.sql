
/****************************************** Basic And Advanced Queries ********************************************/
--1) total sales revenue from all orders

select sum(total_amount) as total_amounts
from orders

select sum(total_amount) as total_amounts
from orders
where status = 'delivered'
---------------------------------------------------------------------------

--2) List the top 5 best-selling products by quantity sold.                         
SELECT TOP 5
p.id AS product_id,
p.name AS product_name,
SUM(od.quantity) AS total_quantity_sold
FROM
order_details od
JOIN
Products p ON od.product_id = p.id
GROUP BY
p.id, p.name
ORDER BY
total_quantity_sold DESC;

select * from orders
---------------------------------------------------------------------------

--3) Identify customers with the highest number of orders.
SELECT 
  c.id ,c.first_name + ' ' + c.last_name AS full_name,
  COUNT(o.customer_id) AS num_of_orders
FROM customers c 
JOIN orders o ON c.id = o.customer_id
GROUP BY c.id, c.first_name, c.last_name
ORDER BY num_of_orders DESC;
---------------------------------------------------------------------------

--4) Generate an alert for products with stock quantities below 20 units
SELECT id, name, stock_quantity , 'LOW STOCK ALERT' AS AlertMessage
FROM products
WHERE stock_quantity < 20;
---------------------------------------------------------------------------

--5)Determine the percentage of orders that used a discount
WITH
total_orders AS (
  SELECT COUNT(*) AS totalOrdersCnt
  FROM orders
  WHERE status <> 'cancelled'
),
orders_with_discount AS (
  SELECT COUNT(DISTINCT o.id) AS orderWithDiscnt
  FROM orders o
  JOIN order_details od ON od.order_id = o.id
  JOIN discounts d
    ON d.is_active = 1
   AND o.order_date BETWEEN d.start_date AND d.end_date
   AND (
	 (d.product_id = od.product_id) OR 
	 (d.category_id = (SELECT category_id FROM products p WHERE p.id = od.product_id))
       )
  WHERE o.status <> 'cancelled'
)
SELECT
  cast(ROUND(owd.orderWithDiscnt * 100.0 / to_cnt.totalOrdersCnt, 2) as float) AS percent_with_discount
FROM orders_with_discount owd
JOIN total_orders to_cnt on 1 = 1

---------------------------------------------------------------------------
--6) Avg rating Per product
select p.id , p.name as product_name ,
	round(avg(r.rating*1.0),2) as Rating
from customers c
join reviews r
on c.id = r.customer_id
join products p 
on p.id =  r.product_id
group by  p.id , p.name 
order by round(avg(r.rating*1.0),2) desc
---------------------------------------------------------------------------
--7)the 30-day customer retention rate after their first purchase
with orderDates as (
	select 
		CONCAT(c.first_name, ' ', c.last_name) CustName, o.order_date, o.total_amount, o.status, ROW_NUMBER() over(partition by c.id order by o.order_date) rn,
		lag(order_date) over(partition by c.id order by o.order_date) firstOrder
	from customers c
	join orders o on c.id = o.customer_id
	and o.status <> 'cancelled'
), with2ndDate as (
	select CustName, firstOrder fstOrdDate, order_date sndOrdDate, DATEDIFF(Day, firstOrder, order_date) noOfDays
	from orderDates 
	where firstOrder is not null
	and order_date <= DATEADD(DAY, 30, firstOrder)
	and rn = 2
), TOTALCUST AS 
(
select count(distinct CustName) totalCust from orderDates
), retainedCustomers as (
select 
	count(CustName) retainedcust from with2ndDate)
	select *, round(cast(retainedcust * 100 as float) / totalCust, 2) [customer%]
	from  retainedCustomers
	JOIN TOTALCUST ON 1 = 1

---------------------------------------------------------------------------

--8)products frequently bought together with items in customer wishlists
select
w1.product_id as product_1_id,
p1.name       as product_1_name,
w2.product_id as product_2_id,
p2.name       as product_2_name,
count(*)      as purchase_frequency
from wishlists w1
join wishlists w2
on w1.customer_id = w2.customer_id
and w1.product_id  < w2.product_id -- to not dublicate eg. AAA BBB - BBB AAA count 1 time
join products p1
on w1.product_id  = p1.id
join products p2
on w2.product_id  = p2.id
group by w1.product_id, p1.name, w2.product_id, p2.name
order by count(*) desc


---------------------------------------------------------------------------
--9)Inventory turnover trends using a 30-day moving average.
SELECT 
    s.order_date AS [date],
    s.total_sales AS [daily_sales],
    i.inventory_value AS [daily_inventory_value],
    
    -- معدل دوران المخزون = المبيعات ÷ المخزون
    ROUND(s.total_sales / NULLIF(i.inventory_value, 0), 2) AS inventory_turnover,

    -- المتوسط المتحرك 30 يوم لمعدل الدوران
    ROUND(
        AVG(s.total_sales / NULLIF(i.inventory_value, 0)) OVER (
            ORDER BY s.order_date 
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ), 2
    ) AS ma_30_turnover

FROM (
    SELECT order_date, SUM(total_amount) AS total_sales
    FROM orders
    GROUP BY order_date
) AS s
INNER JOIN (
    SELECT im.movement_date, SUM(im.quantity * p.price) AS inventory_value
    FROM inventory_movements AS im
    INNER JOIN products AS p ON im.product_id = p.id
    GROUP BY im.movement_date
) AS i
ON s.order_date = i.movement_date
ORDER BY s.order_date;





--9- Track inventory turnover trends using a 30-day moving average. 
WITH daily_sales AS (
  SELECT
    od.product_id,
    p.name                  AS product_name,
    CAST(o.order_date AS date) AS sale_date,
    SUM(od.quantity)        AS units_sold
  FROM order_details od
  JOIN orders o ON od.order_id = o.id
   AND o.status <> 'cancelled'
  JOIN products p ON p.id = od.product_id
  GROUP BY
    od.product_id, p.name,
    CAST(o.order_date AS date)
)
SELECT
  product_id,
  product_name,
  sale_date,
  units_sold,
  AVG(units_sold) OVER (PARTITION BY product_id ORDER BY sale_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS moving_avg_30d_sales
FROM daily_sales
ORDER BY product_id, sale_date



---------------------------------------------------------------------------
--10)Customers who have purchased every product in a specific category
with num_products_per_category as
(
select category_id, count(distinct (id)) as num_of_products
from products
group by category_id
),
customer_purchased_products_per_category as
(
select
o.customer_id,
p.category_id,
count(distinct (od.product_id)) as num_of_products
from orders o
join order_details od on o.id = od.order_id
join products p on od.product_id = p.id
group by o.customer_id, p.category_id
),
filters as
(
select
cpppc.customer_id,
cpppc.category_id
from num_products_per_category nppc
join customer_purchased_products_per_category cpppc
on nppc.category_id = cpppc.category_id
and nppc.num_of_products = cpppc.num_of_products
)
select
customer_id,
category_id
from filters;

---------------------------------------------------------------------------

--11) Find pairs of products commonly bought together in the same order.
WITH order_products AS (
SELECT
order_id,
product_id,
p.name
FROM order_details od
JOIN products p ON od.product_id = p.id
)

SELECT
p1.product_id AS FirstProduct_ID,
p1.name AS FirstProduct_Name,
p2.product_id AS SecondProduct_ID,
p2.name AS SecondProduct_Name,
COUNT(*) AS times_bought_together
FROM
order_products p1
JOIN
order_products p2 ON p1.order_id = p2.order_id
WHERE
p1.product_id < p2.product_id  -- Avoid duplicates and self-pairs
GROUP BY
p1.product_id, p1.name, p2.product_id, p2.name
HAVING
COUNT(*) > 1  -- Only show pairs bought together more than once
ORDER BY p1.product_id
---------------------------------------------------------------------------

--12) Time taken to deliver orders in days
select  o.id, DATEDIFF(DAY, o.order_date, s.shipping_date) AS "shipping duration days"
from shipping s
join orders o on s.order_id = o.id
where s.status = 'delivered'
order by "shipping duration days" desc

select order_id , count(1)from shipping
group by  order_id
having count(1) > 1
