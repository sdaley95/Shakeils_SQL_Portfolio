-- to view vizualization visit https://public.tableau.com/app/profile/shakeil.daley/viz/CohortRetention_16547932056480/CohortDash?publish=yes

-- Cleaning Data


-- Total Records is 541909
-- 135080 Records hve no customer ID
-- 406829 Records have a customer ID number so that is what I'll focus on
SELECT [InvoiceNo]
      ,[StockCode]
      ,[Description]
      ,[Quantity]
      ,[InvoiceDate]
      ,[UnitPrice]
      ,[CustomerID]
      ,[Country]
  FROM [PortfolioDB].[dbo].[online_retail]
  Where CustomerID != 0


 ;with online_retail as -- cte #1 to make calling the entire table easier and filtering out blank customer IDs
	(
	  SELECT [InvoiceNo]
		  ,[StockCode]
		  ,[Description]
		  ,[Quantity]
		  ,[InvoiceDate]
		  ,[UnitPrice]
		  ,[CustomerID]
		  ,[Country]
	  FROM [PortfolioDB].[dbo].[online_retail]
	  Where CustomerID != 0
	)
,quantity_unit_price as -- cte #2 to filter out rows that don't have any data
	
	-- 397882 records with quantity and Unit price
	(
	select *
	from online_retail
	where Quantity > 0 and UnitPrice > 0
	)
, dup_check as -- cte #3 to filter out duplicates
	(
	-- duplicate check
	-- I am using specific criterea to look for duplicates. ROW_NUMBER is used to mark any duplicates however many their are.
	select *, ROW_NUMBER() over (partition by InvoiceNo, StockCode, Quantity order by InvoiceDate) dup_flag 
	from quantity_unit_price
	)
--- 392667 clean data
--- 5215 duplicates; switch dup_flag = 1 to dup_flag> 1
select *
into #online_retail_clean -- creating a local temp table to store the clean data I need so that I no longer need to execute the entire query 
from dup_check
where dup_flag = 1 

---- Clean Data
---- Begin cohort analysis
select * from #online_retail_clean

-- Unique Identifier (CustomerID)
-- Initial Start Date (First Invoice Date)
-- Revenue Data

select
	CustomerID,
	min(InvoiceDate) first_purchase_date,
	DATEFROMPARTS(year(min(InvoiceDate)), month(min(InvoiceDate)), 1) Cohort_Date -- using DATEFROMPARTS to pull the month and year that the customer made the fist purchase to make it easier to group them
into #cohort -- another temp table to store this data
from #online_retail_clean
group by CustomerID

select *
from #cohort


--- Create Cohort Index
-- The purpose is to find out how many months have passed since the customer's first purchase

select
	mmm.*,
	cohort_index = year_diff * 12 + month_diff + 1 -- Fourth, this formula will give us how many months have passed since the customer made their first purchase
into #cohort_retention -- Fifth, I am saving the results into a temp table
from
	(
	select
		mm.*, -- Third, I am finding the year and month differences to get me closer to finding the cohort index
		year_diff = invoice_year - cohort_year,
		month_diff = invoice_month - cohort_month
	from
		(
		select  
			r.*,
			c.Cohort_Date,
			year(r.InvoiceDate) invoice_year, -- Second, I am pulling the individual month and year from all the invoice and cohort dates
			month(r.InvoiceDate) invoice_month,
			year(c.Cohort_Date) cohort_year,
			month(c.Cohort_Date) cohort_month
		from #online_retail_clean r
		left join #cohort c -- First I need to join the two temp tables I have created
			on r.CustomerID = c.CustomerID
		)mm
	)mmm

-- At this point I have extracted the data to be used in a vizualization software
select * from #cohort_retention

-- Before I vizualize the data I saved, I want to find all the distinct customers
select distinct
	CustomerID,
	Cohort_Date,
	cohort_index
from #cohort_retention
order by CustomerID, cohort_index

-- Pivot data to see cohort table
select *
into #cohort_pivot
from
	(
	select distinct
		CustomerID,
		Cohort_Date,
		cohort_index
	from #cohort_retention
	)tbl
	pivot
		(
		count(CustomerID)
		for Cohort_Index In
		(
		[1], -- Each number is a diferent month
		[2],
		[3],
		[4],
		[5],
		[6],
		[7],
		[8],
		[9],
		[10],
		[11],
		[12],
		[13]
		)
	)as pivot_table
	order by Cohort_Date

-- I think it is fascinating that the results of the pivot table is like a techincal vizualization of the how many customer made repeat purchase for each month after their first purchase

-- Now that I have the numbers, I want to create retention rates for each period
select Cohort_Date, 
	(1.0 * [1]/[1] * 100) as [1], -- this formula divides the slected period by the first period to return a retention percentage
	1.0 * [2]/[1] * 100 as [2], -- now I just repeat for each to get the results for all
	1.0 * [3]/[1] * 100 as [3],
	1.0 * [4]/[1] * 100 as [4],
	1.0 * [5]/[1] * 100 as [5],
	1.0 * [6]/[1] * 100 as [6],
	1.0 * [7]/[1] * 100 as [7],
	1.0 * [8]/[1] * 100 as [8],
	1.0 * [9]/[1] * 100 as [9],
	1.0 * [10]/[1] * 100 as [10],
	1.0 * [11]/[1] * 100 as [11],
	1.0 * [12]/[1] * 100 as [12],
	1.0 * [13]/[1] * 100 as [13]
from #cohort_pivot
order by Cohort_Date