--Inspecting Data--

select *
from [dbo].[sales_data_sample]

--Checking Unique Values 

select distinct status from [dbo].[sales_data_sample] --Good one to plot
select distinct year_id from[dbo].[sales_data_sample]
select distinct PRODUCTLINE from [dbo].[sales_data_sample] --Good to plot as well
select distinct COUNTRY from [dbo].[sales_data_sample] -- Good to plot
select distinct DEALSIZE from [dbo].[sales_data_sample] -- Good to plot
select distinct TERRITORY from [dbo].[sales_data_sample] -- Good to plot

---Analysis---
--We'll start by grouping sales by productline
select PRODUCTLINE, sum(sales) Revenue -- Using PRODUCTLINE to see the different types of units sold as well as the aggregate function sum to create a new column aliased as Revenue to see what each has made
from [dbo].[sales_data_sample] -- Pulling this the data from our sales data sample table
group by PRODUCTLINE -- I want it organize by the product since it is not apart of the aggregate function
order by 2 desc -- To show greatest to least and the 2nd column Revenue is how I want it ordered

--We now know what car sells the most, which is classic cars, now lets see what year had the highest sales

select YEAR_ID, sum(sales) Revenue
from [dbo].[sales_data_sample]
group by YEAR_ID
order by 2 desc

-- 2004 is the year that had the most sales. 2005 is the least and is significantly lower. Why?

select distinct MONTH_ID from [dbo].[sales_data_sample]
where YEAR_ID = 2005

select distinct MONTH_ID from [dbo].[sales_data_sample]
where YEAR_ID = 2003

select distinct MONTH_ID from [dbo].[sales_data_sample]
where YEAR_ID = 2004

-- Turns out sales where only made for 5 months out of the year in 2005 whereas 2003 and 2004 made sales all throughout the year

-- I want to see whats up with the deal sizes

select DEALSIZE, sum(sales) Revenue
from [dbo].[sales_data_sample]
group by DEALSIZE
order by 2 desc 

-- Medium dealsize oupace small and large 

--What is the best month for sales in a specific year? How much was earned that month?

-- 2003
select MONTH_ID, sum(sales) Revenue, count(ORDERNUMBER) Frequency -- Pulling each months revenue as well as order number aliased as Frequency to see how many sales were made
from [dbo].[sales_data_sample]
where YEAR_ID = 2003
group by MONTH_ID
order by 2 desc


-- 2004
select MONTH_ID, sum(sales) Revenue, count(ORDERNUMBER) Frequency
from [dbo].[sales_data_sample]
where YEAR_ID = 2004
group by MONTH_ID
order by 2 desc


-- 2005
select MONTH_ID, sum(sales) Revenue, count(ORDERNUMBER) Frequency
from [dbo].[sales_data_sample]
where YEAR_ID = 2005
group by MONTH_ID
order by 2 desc

-- Sales really pick up towards the end of the year with November being number 1 in 2003 and 2004

--What product sells the most in November? I feel it will be classic

--November 2003
select MONTH_ID, PRODUCTLINE, sum(sales) Revenue, count(ORDERNUMBER) Frequency -- Same query as before, just adding PRODUCTLINE
from [dbo].[sales_data_sample]
where YEAR_ID = 2003 and MONTH_ID = 11 --Specifying that I want to look at the the data from November of 2003
group by MONTH_ID, PRODUCTLINE -- I want the data grouped by these two since they are not apart of the aggregate function
order by 3 desc -- Again I want it to show the data from greatest to least and since Revenue has now been moved to the 3rd column I specify thats the column to order the data by

-- Turns out my guess was correct and Classic Cars lead the way in revenue and amount sold for 2003

-- November 2004
select MONTH_ID, PRODUCTLINE, sum(sales) Revenue, count(ORDERNUMBER) Frequency
from [dbo].[sales_data_sample]
where YEAR_ID = 2004 and MONTH_ID = 11 
group by MONTH_ID, PRODUCTLINE 
order by 3 desc

-- Same results as 2003 however, Motorcycles took 3rd place in 2004


---RFM Analysis---

-- Recency-Frequency-Monetary (RFM)
-- An indexing technique thay uses past purchase behavior to segment customers
-- Customers are segmented using 3 metrics:
-- Recency: how long ago was their last purchase
-- Frequency: how often they purchase
-- Monetary: how much they spent


-- Now, who is our best customer?

DROP TABLE IF EXISTS #rfm -- Creating a local temp table so I don't have tp keep running this entire script
;with rfm as
(
	select
		CUSTOMERNAME, -- Name of our customers
		sum(sales) MonetaryValue, -- total sales
		avg(sales) AvgMonetaryValue, -- average sales
		count(ORDERNUMBER) Frequency, -- amount purchased
		max(ORDERDATE) last_order_date, -- the last time the purchased
		(select max(ORDERDATE) from [dbo].[sales_data_sample]) max_order_date, -- This is a nested query that adds a column to show the maximum order date wich is 2005-05-31
		DATEDIFF(DD, max(ORDERDATE), (select max(ORDERDATE) from [dbo].[sales_data_sample])) Recency -- DATEDIFF to show how many days (DD) since each customers last purchase from the max date in the data set aliased as Recency
	from [dbo].[sales_data_sample]
	group by CUSTOMERNAME
),
rfm_calc as
(
	select r.*, -- I am creating a scaling system for each RFM metric from 1-4 with 4 being the most desirebale 
		NTILE(4) OVER (order by Recency desc) rfm_recency, -- NTILE creates a set amount of "buckets", in this case 4, that will place customers in depending how they meet each criterea  
		NTILE(4) OVER (order by Frequency desc) rfm_frequency,
		NTILE(4) OVER (order by MonetaryValue desc) rfm_monetary
	from rfm r
)
select 
	c.*, rfm_recency + rfm_frequency + rfm_monetary as rfm_cell, -- Concatinating the RFM numbers that each customer has 
	cast(rfm_recency as varchar) + cast(rfm_frequency as varchar) + cast(rfm_monetary as varchar) rfm_cell_string -- Using cast to change the concat number to strings so they don't get added as numerics
into #rfm
from rfm_calc c

select * from #rfm -- Test to see if the temp table works

select CUSTOMERNAME, rfm_recency, rfm_frequency, rfm_monetary,
	case -- using the cell string, we can now run each customer through case statetemnts which wiil act as a labeler to show where each customer stands with us
		when rfm_cell_string in (111, 112, 121, 122, 123, 132, 211, 212, 114, 141) then 'lost costomer'
		when rfm_cell_string in (133, 134, 143, 244, 334, 343, 344, 144) then 'slipping away, cannot lose'
		when rfm_cell_string in (311,411,331) then 'new customers'
		when rfm_cell_string in (222, 223, 233, 322) then 'potential churners'
		when rfm_cell_string in (323, 333, 321, 422, 332, 432) then 'active'
		when rfm_cell_string in (433,434, 443, 444) then 'loyal'
	end rfm_segment
from #rfm

-- What products are most often sold together?
-- select * from [dbo].[sales_data_sample] where ORDERNUMBER = 10411

-- orders where 2 products are sold together
select distinct OrderNumber, stuff( -- using stuff function to change out xml path to a string
	
	(select ',' + PRODUCTCODE -- to list out the products for each order
	from [dbo].[sales_data_sample] p
	where ORDERNUMBER in
		(

			select ORDERNUMBER -- this is our base query showing which products have shipped
			from(
				select ORDERNUMBER, count(*) rn
				from [dbo].[sales_data_sample]
				where STATUS = 'Shipped'
				group by ORDERNUMBER
			)m
			where rn = 2
		)
		and p.ORDERNUMBER = s.ORDERNUMBER 
		for xml path (''))

		, 1, 1, '') ProductCodes -- removing the first comma that displays when the code is run

from [dbo].[sales_data_sample] s
order by 2 desc

-- orders where 3 products are sold together
select distinct OrderNumber, stuff(
	
	(select ',' + PRODUCTCODE
	from [dbo].[sales_data_sample] p -- Since I am calling from this table more than once in this query I'll give it an alias as p
	where ORDERNUMBER in
		(

			select ORDERNUMBER
			from(
				select ORDERNUMBER, count(*) rn
				from [dbo].[sales_data_sample]
				where STATUS = 'Shipped'
				group by ORDERNUMBER
			)m
			where rn = 3
		)
		and p.ORDERNUMBER = s.ORDERNUMBER -- Using a join to combine the two calls
		for xml path (''))

		, 1, 1, '') ProductCodes

from [dbo].[sales_data_sample] s -- This is the second call from this table so it is aliased as s
order by 2 desc -- Order by 2 , which is the second column, so that the orders that only have 2 products show up first