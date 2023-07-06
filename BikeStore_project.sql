-- Overview of dataset
SELECT * 
FROM BikeStore_Project..BikeStore

-- Data Cleaning
sp_RENAME 'BikeStore.[F6]', 'month', 'COLUMN'
GO
sp_RENAME 'BikeStore.[total_units]', 'units_per_cust', 'COLUMN'
GO


-- Data Analysis

-- Year-on-year revenue growth by month
WITH monthly_revenue as (
	SELECT year, month, ROUND(SUM(revenue), 3) as total_revenue
	FROM BikeStore_Project..BikeStore
	WHERE revenue IS NOT NULL
	GROUP BY year, month
)
SELECT
	curr.year,
	curr.month,
	curr.total_revenue,
	prev.total_revenue as prev_year_revenue,
	ROUND((curr.total_revenue - prev.total_revenue) / prev.total_revenue * 100, 2) as YoY_growth_percentage
FROM monthly_revenue as curr
LEFT JOIN monthly_revenue as prev
	on curr.month = prev.month and curr.year = prev.year + 1
ORDER BY curr.year, curr.month;

-- Count of entries for each key column
SELECT SUM(revenue) as total_revenue, SUM(units_per_cust) as total_units, COUNT(DISTINCT order_id) as orders, COUNT(DISTINCT customers) as total_customers, COUNT(DISTINCT sales_rep) as sales_reps
FROM BikeStore_Project..BikeStore;

-- Count of distinct demographics and purchase information
SELECT COUNT(DISTINCT city) as cities, COUNT(DISTINCT state) as states, COUNT(DISTINCT product_name) as products, COUNT(DISTINCT category_name) as categories, COUNT(DISTINCT brand_name) as brands, COUNT(DISTINCT store_name) as stores
FROM BikeStore_Project..BikeStore;

-- Total revenue for each brand
SELECT brand_name, ROUND(SUM(revenue), 3) as total_revenue, SUM(units_per_cust) as total_units
FROM BikeStore_Project..BikeStore
WHERE revenue IS NOT NULL
GROUP BY brand_name
ORDER BY total_revenue DESC;


-- Percentage of total revenue by brand for each year
WITH yearly_brand_revenue as (
	SELECT year, brand_name, SUM(revenue) as total_revenue
	FROM BikeStore_Project..BikeStore
	GROUP BY year, brand_name
),
yearly_total_revenue as (
	SELECT year, SUM(revenue) as total_revenue
	FROM BikeStore_Project..BikeStore
	GROUP BY year
)
SELECT
	ybr.year,
	ybr.brand_name,
	ybr.total_revenue,
	ROUND((ybr.total_revenue / ytr.total_revenue) * 100, 2) as percentage_of_total_revenue
FROM yearly_brand_revenue as ybr
JOIN yearly_total_revenue as ytr ON ybr.year = ytr.year
ORDER BY ybr.year, percentage_of_total_revenue DESC;

-- Total revenue by year
SELECT year, ROUND(SUM(revenue), 3) as total_revenue
FROM BikeStore_Project..BikeStore
WHERE year IS NOT NULL
GROUP BY year
ORDER BY year;

-- Total revenue generated each month
SELECT month, ROUND(SUM(revenue), 3) as total_revenue, SUM(units_per_cust) as units_sold
FROM BikeStore_Project..BikeStore
WHERE month IS NOT NULL
GROUP BY month
ORDER BY total_revenue DESC;

-- Using a CTE with a case function to group months according to seasons of the year 
WITH SeasonData AS (
  SELECT
    CASE
      WHEN month in ('Dec', 'Jan', 'Feb') then 'Winter'
      WHEN month in ('Mar', 'Apr', 'May') then 'Spring'
      WHEN month in ('Jun', 'Jul', 'Aug') then 'Summer'
      ELSE 'Autumn'
    END as season,
    revenue,
    units_per_cust
  FROM BikeStore_Project..BikeStore
)
SELECT
  season,
  ROUND(SUM(revenue), 3) as total_revenue,
  SUM(units_per_cust) as total_units
FROM SeasonData
WHERE revenue IS NOT NULL
GROUP BY season
ORDER BY total_revenue DESC;

-- Total revenue generated in each store
SELECT store_name, ROUND(SUM(revenue), 3) as total_revenue, SUM(units_per_cust) as total_units
FROM BikeStore_Project..BikeStore
WHERE revenue IS NOT NULL
GROUP BY store_name
ORDER BY total_revenue DESC;

-- Total revenue for the top 10 cities and the states they belong to
SELECT TOP 10 city, MIN(state) as state, SUM(revenue) as total_revenue, SUM(units_per_cust) as total_units
FROM BikeStore_Project..BikeStore
WHERE revenue IS NOT NULL
GROUP BY city
ORDER BY total_revenue DESC;

-- Monthly sales performance against the average revenue
WITH monthly_revenue as (
	SELECT year, month, ROUND(SUM(revenue), 2) as total_revenue
	FROM BikeStore_Project..BikeStore
	WHERE revenue IS NOT NULL
	GROUP BY year, month
),
average_monthly_revenue as (
	SELECT ROUND(AVG(total_revenue), 2) as avg_monthly_revenue
	FROM monthly_revenue
)
SELECT
	mr.year,
	mr.month,
	mr.total_revenue,
	amr.avg_monthly_revenue,
	ROUND(mr.total_revenue - amr.avg_monthly_revenue, 2) as difference_from_avg
FROM monthly_revenue as mr
CROSS JOIN average_monthly_revenue as amr
ORDER BY mr.year, mr.month;

-- A query to assess the most profitable sales representatives
SELECT sales_rep, ROUND(SUM(revenue), 3) as total_revenue, SUM(units_per_cust) as total_units
FROM BikeStore_Project..BikeStore
WHERE revenue IS NOT NULL
GROUP BY sales_rep
ORDER BY total_revenue DESC;

-- Sales rep perfomance ranked by total revenue and total units sold
WITH sales_rep_performance as (
	SELECT
		sales_rep,
		ROUND(SUM(revenue), 2) as total_revenue,
		SUM(units_per_cust) as total_units
	FROM BikeStore_Project..BikeStore
	WHERE revenue IS NOT NULL
	GROUP BY sales_rep
),
revenue_rank as (
	SELECT
		sales_rep,
		RANK() OVER (ORDER BY total_revenue DESC) as revenue_rank
	FROM sales_rep_performance
),
units_rank as (
	SELECT
		sales_rep,
		RANK() OVER (ORDER BY total_units DESC) as units_rank
	FROM sales_rep_performance
)
SELECT
	rr.sales_rep,
	rr.revenue_rank,
	ur.units_rank,
	srp.total_revenue,
	srp.total_units
FROM revenue_rank as rr
JOIN units_rank as ur on rr.sales_rep = ur.sales_rep
JOIN sales_rep_performance as srp on rr.sales_rep = srp.sales_rep
ORDER BY rr.revenue_rank;

-- A query to find the 100 most profitable customers, potentially to offer promotions
SELECT TOP 100 customers, SUM(revenue) as total_revenue, SUM(units_per_cust) as total_units
FROM BikeStore_Project..BikeStore
WHERE revenue IS NOT NULL
GROUP BY customers
ORDER BY total_revenue DESC;

-- Top 3 products by total units sold for each category
WITH product_rank as (
	SELECT
		category_name,
		product_name,
		SUM(units_per_cust) as total_units_sold,
		ROW_NUMBER() OVER (PARTITION BY category_name ORDER BY SUM(units_per_cust) DESC) as rank
	FROM BikeStore_Project..BikeStore
	WHERE category_name IS NOT NULL
	GROUP BY category_name, product_name
)
SELECT category_name, product_name, total_units_sold
FROM product_rank
WHERE rank <= 3
ORDER BY category_name, rank;

-- Top 5 products by revenue growth which can be used for predictive analysis to determine most profitable products in the future
WITH product_revenue as (
	SELECT
		year,
		category_name,
		product_name,
		ROUND(SUM(revenue), 2) as total_revenue
	FROM BikeStore_Project..BikeStore
	WHERE revenue IS NOT NULL
	GROUP BY year, category_name, product_name
),
product_revenue_growth as (
	SELECT
		curr.year,
		curr.category_name,
		curr.product_name,
		curr.total_revenue,
		prev.total_revenue as prev_year_revenue,
		ROUND((curr.total_revenue - prev.total_revenue) / prev.total_revenue * 100, 2) as yoy_growth_percentage,
		ROW_NUMBER() OVER (PARTITION BY curr.category_name, curr.year ORDER BY ((curr.total_revenue - prev.total_revenue) / prev.total_revenue * 100) DESC) as rank
	FROM product_revenue as curr
	LEFT JOIN product_revenue as prev
		on curr.category_name = prev.category_name and curr.product_name = prev.product_name and curr.year = prev.year + 1
)
SELECT
	year, 
	category_name, 
	product_name, 
	total_revenue, 
	prev_year_revenue, 
	yoy_growth_percentage
FROM product_revenue_growth
WHERE rank <= 5
ORDER BY year, category_name, rank