IF OBJECT_ID('hifical.cal_actual', 'U') IS NOT NULL
  TRUNCATE TABLE hifical.cal_actual
;

IF OBJECT_ID('tempdb..#date_rows', 'U') IS NOT NULL
  DROP TABLE #date_rows
;

GO

declare @priorYears int = 10
declare @futureYears int = 50

/* an extra year at each end will be generated and later dumped in order to proper calculate things like ActualWeekStartDate of the desired first year */
declare @startYear int = year(getdate()) - (1 + @priorYears)
declare @endYear int = year(getdate()) + 1 + @futureYears

declare @startDate date = datefromparts(@startYear,1,1)
declare @qtyRows int = datediff(dd,@startDate, datefromparts(@endYear,12,31))


/* define a CTE that will generate a table with a single column of sequential numbers and the exact number of rows as dates in our year range */
; WITH InfiniteRows (RowNumber) AS (
   -- Anchor member definition
   SELECT 1 AS RowNumber
   UNION ALL
   -- Recursive member definition
   SELECT a.RowNumber + 1 AS RowNumber
   FROM   InfiniteRows a
   WHERE  a.RowNumber <= @qtyRows
)

/* Execute the CTE and populate a temp table with a row for each date in our range */
SELECT  dateadd(dd,RowNumber-1,@startDate) as datekey

into    #date_rows
FROM    InfiniteRows
OPTION  (MAXRECURSION 0) --careful, but def ok for 50k rows
;   

/* insert all the date rows and the populate core fields */
insert into hifical.cal_actual (
  datekey                   
, datekey_int                
, cal_day                 
, cal_day_name_long         
, cal_day_name_short        
, cal_day_of_year           
, cal_month               
, cal_month_end_date        
, cal_month_name_long       
, cal_month_name_short      
, cal_month_begin_date      
, cal_quarter_num             
, cal_weekday_num             
, cal_weekday_month_instance
, cal_week_of_year          
, cal_is_holiday           
, cal_is_workday           
, cal_year                
, cal_yyyymm
, cal_yyyyww
)
select

  datekey                   
, datekey_int              = (year(datekey) * 100 + month(datekey)) * 100 + day(datekey)
, cal_day                     = day(datekey)
, cal_day_name_long             = format(datekey, 'dddd')
, cal_day_name_short            = format(datekey, 'ddd')
, cal_day_of_year               = datepart(dy, datekey)
, cal_month                   = month(datekey)
, cal_month_end_date           = eomonth(datekey)
, cal_month_name_long           = format(datekey, 'MMMM')
, cal_month_name_short          = format(datekey, 'MMM')
, cal_month_begin_date          = datefromparts(year(datekey),month(datekey),1)
, cal_quarter_num                 = datepart(qq, datekey)
, cal_weekday_num                 = datepart(dw, datekey)
, cal_weekday_month_instance    = ROW_NUMBER() over (partition by year(datekey), month(datekey), datepart(dw,datekey) ORDER BY datekey)
, cal_week_of_year              = datepart(ww, datekey)
, cal_is_holiday               = 0
, cal_is_workday               = case when datepart(dw, datekey) between 2 and 6 then 1 else 0 end --will be refined later
, cal_year                    = year(datekey)
, cal_yyyymm               = year(datekey) * 100 + month(datekey)
, cal_yyyyww                = year(datekey) * 100 + datepart(ww, datekey) 


from #date_rows;
