USE WideWorldImporters;

/*=====================================================
  Sales Revenue Analysis
  Database: WideWorldImporters
  Dataset: portfolio_dataset1
=====================================================*/



/*=====================================================
  1. Are there nulls ?
=====================================================*/

SELECT
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS Null_Order_ID
    ,SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS Null_Customer_ID
    ,SUM(CASE WHEN customer_name IS NULL THEN 1 ELSE 0 END) AS Null_Customer_Name
    ,SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS Null_Product_ID
    ,SUM(CASE WHEN product_name IS NULL THEN 1 ELSE 0 END) AS Null_Product_Name
    ,SUM(CASE WHEN product_category IS NULL THEN 1 ELSE 0 END) AS Null_Product_Category
    ,SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) AS Null_Order_Date
    ,SUM(CASE WHEN revenue IS NULL THEN 1 ELSE 0 END) AS Null_Revenue
    ,SUM(CASE WHEN region IS NULL THEN 1 ELSE 0 END) AS Null_Region
FROM portfolio_dataset1;


/*=====================================================
    2. Data Cleaning: Remove Duplicate Records
=====================================================*/
SELECT COUNT(*) AS TotalRows FROM portfolio_dataset1;

WITH DuplicateCheck AS (
    SELECT *,
           ROW_NUMBER() OVER(PARTITION BY order_id, product_id, customer_id, order_date ORDER BY order_id) AS row_num
    FROM portfolio_dataset1
)

DELETE FROM DuplicateCheck
WHERE row_num > 1;


SELECT COUNT(*) AS TotalRowsAfterCleanup
FROM portfolio_dataset1;

/*=====================================================
  3. Total Revenue
=====================================================*/
SELECT 
   ROUND(SUM(revenue), 2) AS Total_Revenue
FROM portfolio_dataset1;



/*=====================================================
  4. Monthly Revenue Trend & Month-over-Month Growth
=====================================================*/

WITH MonthlyRevenue AS (
    SELECT
        DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS MonthStart
        ,SUM(revenue) AS MonthlyRevenue
    FROM portfolio_dataset1
    GROUP BY DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)
),
RevenueComparison AS (
    SELECT
        MonthStart
        ,MonthlyRevenue
        ,LAG(MonthlyRevenue) OVER (ORDER BY MonthStart) AS PreviousMonthRevenue
    FROM MonthlyRevenue
)

SELECT
    MonthStart
    ,CAST(ROUND(MonthlyRevenue,2) AS DECIMAL(18,2)) AS Monthly_Revenue
    ,CAST(ROUND(PreviousMonthRevenue,2) AS DECIMAL(18,2)) AS Previous_Month_Revenue
    ,CASE
        WHEN PreviousMonthRevenue IS NULL THEN NULL
        WHEN MonthlyRevenue > PreviousMonthRevenue THEN 'Increased'
        WHEN MonthlyRevenue < PreviousMonthRevenue THEN 'Decreased'
        ELSE 'No Change'
    END AS Revenue_Trend
    ,ROUND(MonthlyRevenue - PreviousMonthRevenue,2) AS Revenue_Difference
    ,ROUND(((MonthlyRevenue - PreviousMonthRevenue) / NULLIF(PreviousMonthRevenue,0)) * 100,2) AS MoM_Growth_Percent

FROM RevenueComparison
ORDER BY MonthStart;


/*=====================================================
  5. Revenue by Product Category
=====================================================*/
SELECT
    product_category
    ,CAST(ROUND(SUM(revenue),2) AS DECIMAL(18,2)) AS Category_Revenue
FROM portfolio_dataset1
GROUP BY product_category
ORDER BY Category_Revenue DESC;



/*=====================================================
  6. Top 10 Customers by Revenue
=====================================================*/
SELECT TOP 10
    customer_id
    ,customer_name
    ,CAST(ROUND(SUM(revenue),2) AS DECIMAL(18,2)) AS Customer_Revenue
FROM portfolio_dataset1
GROUP BY 
    customer_id
    ,customer_name
ORDER BY SUM(revenue) DESC;


/*=====================================================
  7. Top 10 Products by Revenue
=====================================================*/
SELECT TOP 10
    product_id
    ,product_name
    ,CAST(ROUND(SUM(revenue),2) AS DECIMAL(18,2)) AS Product_Revenue
FROM portfolio_dataset1
GROUP BY 
    product_id
    ,product_name
ORDER BY SUM(revenue) DESC;


/*=====================================================
  8. Revenue by Region
=====================================================*/
SELECT
    region
    ,ROUND(SUM(revenue),2) AS Region_Revenue
FROM portfolio_dataset1
GROUP BY region
ORDER BY Region_Revenue DESC;

/*=====================================================
  9. Ranking Months by Revenue Performance
=====================================================*/
WITH MonthlyRevenue AS (
    SELECT
        DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS MonthStart
        ,SUM(revenue) AS MonthlyRevenue
    FROM portfolio_dataset1
    GROUP BY DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)
)
    SELECT
        mr.MonthStart
        ,mr.MonthlyRevenue
        ,row_number() over(order by mr.MonthlyRevenue desc) as Row_Number_Test
        ,Rank() over(order by mr.MonthlyRevenue desc) as Rank_Test
        ,Dense_Rank() over(order by mr.MonthlyRevenue desc) as Dense_Rank_Test
    FROM MonthlyRevenue mr
    ORDER BY mr.MonthlyRevenue DESC;

/*=====================================================
 10. Top 3 product per category.
=====================================================*/
WITH ProductRevenue AS (
    SELECT
        p.product_category
        ,p.product_id 
        ,SUM(p.revenue) AS Revenue
    FROM portfolio_dataset1 p
    GROUP BY p.product_category,p.product_id
),
    RankedProducts as (
    SELECT        
        pp.product_category
        ,pp.product_id 
        ,pp.revenue
       ,Row_Number() over(partition by pp.product_category order by pp.revenue desc) as Row_Rank
    FROM ProductRevenue pp
    
    )

    select 
        pr.product_category
        ,pr.product_id
        ,cast(round(pr.revenue,2) as decimal(18,2)) As Product_Revenue
        ,pr.Row_Rank
        from RankedProducts pr
        where pr.row_rank <=3
    ORDER BY pr.product_category, pr.Row_Rank;

/*=====================================================
 11. Running Revenue Total by Date
=====================================================*/

WITH DailyRevenue AS (
    SELECT
        order_date
        ,SUM(revenue) AS DailyRevenue
    FROM portfolio_dataset1
    GROUP BY order_date
)

SELECT
    order_date
    ,DailyRevenue
    ,SUM(DailyRevenue) OVER(ORDER BY order_date) AS Running_Total_Revenue
FROM DailyRevenue
ORDER BY order_date;

/*=====================================================
12.  Top 3 Customers Per Region
=====================================================*/

WITH CustomerRevenue AS (
    SELECT
        region
        ,customer_name,
        SUM(revenue) AS CustomerRevenue
    FROM portfolio_dataset1
    GROUP BY region, customer_name
)

SELECT *
FROM (
    SELECT
        region,
        customer_name,
        CustomerRevenue,
        ROW_NUMBER() OVER(
            PARTITION BY region
            ORDER BY CustomerRevenue DESC
        ) AS Rank_In_Region
    FROM CustomerRevenue
) ranked
WHERE Rank_In_Region <= 3
ORDER BY region, Rank_In_Region;
