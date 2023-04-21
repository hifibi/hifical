/*
  options
  - Week start day
    - set @firstDayOfWeekNum
    - Valid values are integers 1 - 7 where 1 = Sunday.
    - Default: Sunday
  - Year start month
    - set @firstMonthOfYear
    - Valid values are integers 1 - 12 where 1 = January.
    - Default: January
  - Number of years for which the calendar should be generated
    - set @totalYears
    - Valid values are integers
    - Default: 20
    - Implications
      - Fiscal calendar for years not present in hifical.cal_actual cannot be generated.
  - Start Year
    - set @startYear
    - Default: 0
    - Valid values are integers less than select max(cal_year) from hifical.cal_actual
    - Implications
      - The earliest year in hifical.cal_actual that is later than or equal to @startYear where the 1st of @firstMonthOfYear is the weekday specified in @firstDayOfWeekNum will be selected as the base year from which to calculate fiscal dates. In other words, the script finds the earliest year where the fiscal and actual calendars would have aligned and calculates 445 fiscal calendar from there.
      - The default value of 0 generates the fiscal calendar for as many years in the actual calendar as possible.

  requirements
  - a base calendar table with one row per date with none skipped. It must include years beginning with the base year* to the end of period to be generated.
  - *base year is the year equal to or earlier than the start year where Jan 1 day of week = @firstDayOfWeekNum

  basic logic
  - start with a year in which Jan 1 is the selected start of week day which is also on or before the start year
  - add 363 days to get the end date
  - using a recursive CTE, insert one row per year sequentially. Calculate the next year's start date as prior year's end date + 1
    - check whether this is a year that gets an extra week and calculate the end date as dayadd from prior year's end date + 364 or 371.
  - using the results of the recursive CTE (a table with one row per fiscal year and the actual start and end dates of each fiscal year), construct a table with a row for every date in each fiscal year plus typical helper calendar columns relevant to the Fiscal dates.
*/

declare @firstDayOfWeekNum int = 1 --Sunday = 1; Saturday = 7
declare @firstMonthOfYear int = 1
declare @startYear int = 0
declare @totalYears int = 20
declare @baseYear int
select @baseYear = min(cal_year) from hifical.cal_actual where cal_year >= @startYear and cal_month = @firstMonthOfYear and cal_day = 1 and cal_weekday_num = @firstDayOfWeekNum

declare @baseYearStartDate date = DATEFROMPARTS(@baseYear, @firstMonthOfYear, 1)
declare @baseYearNaturalEndDate date = dateadd(dd, -1, dateadd(yy, 1, @baseYearStartDate))
declare @naturalYearEndMonth int = MONTH(@baseYearNaturalEndDate)
declare @naturalYearEndDay int = DAY(@baseYearNaturalEndDate)

if @startYear = 0
	set @startYear = @baseYear
;


IF OBJECT_ID('hifical.cal_fiscal_445', 'U') IS NOT NULL
  TRUNCATE TABLE hifical.cal_fiscal_445
;

declare @maxYear int = @startYear + @totalYears

/* define a CTE that will generate a table with a single column of sequential numbers and the exact number of rows as dates in our year range */
; WITH InfiniteRows (Year, StartDate, EndDate) AS (
   -- Anchor member definition
   SELECT 
    Year = @baseYear
    , StartDate = @baseYearStartDate
    , EndDate = DATEADD(dd, 363, @baseYearStartDate)
   UNION ALL
   -- Recursive member definition
   SELECT 
    a.Year + 1    AS Year
    , StartDate = dateadd(dd, 1, EndDate)
    , EndDate = dateadd(dd, 
                --alternatively, check if the next year's first day of fiscal year falls on @firstDayOfWeekNum. If so, this year needs an extra week.
                CASE when DATEDIFF(dd, dateadd(dd, 364, EndDate), DATEFROMPARTS(a.Year + 1, @naturalYearEndMonth, @naturalYearEndDay)) >=7 then 364 + 7 else 364 end, 
                EndDate)
   FROM   InfiniteRows a
   WHERE  a.Year < @maxYear
)


/* insert base rows with date only */
insert into hifical.cal_fiscal_445 (
    fsc_datekey
  , fsc_year
  , fsc_is_holiday
  , fsc_is_workday
  , fsc_day_of_year
  , fsc_weekday_num
  , fsc_week_of_year
  , fsc_quarter_num
  , fsc_week_of_quarter
)
  select
    datekey
    , fsc_year = fscYr.Year
    , fsc_is_holiday = 0
    , fsc_is_workday = case when datepart(dw, datekey) between 2 and 7 then 1 else 0 end --will be refined later
    , fsc_day_of_year = 1 + datediff(dd,fscYr.StartDate, datekey)
    , fsc_weekday_num = 1 + (datediff(dd,fscYr.StartDate, datekey) % 7)
    , fsc_week_of_year = CEILING(datediff(dd,fscYr.StartDate, datekey)  / 7) + 1
    , fsc_quarter_num = CASE   when 1 + datediff(dd,fscYr.StartDate, datekey) > 364 then 4
                                else CEILING(1 + ((1 + datediff(dd,fscYr.StartDate, datekey)) - 1) / 91) end
    , fsc_week_of_quarter = (CEILING(datediff(dd,fscYr.StartDate, datekey)  / 7) + 1) - (13 * ((CASE   when 1 + datediff(dd,fscYr.StartDate, datekey) > 364 then 4
                                else CEILING(1 + ((1 + datediff(dd,fscYr.StartDate, datekey)) - 1) / 91) end) - 1))
from InfiniteRows fscYr
inner join hifical.cal_actual cal
on cal.datekey between fscYr.StartDate and fscYr.EndDate
where fscYr.Year between @startYear and @maxYear
;

update cal set
fsc_month_of_quarter                = 1 + (CASE when fsc_week_of_quarter > 12 then 12 else fsc_week_of_quarter end - 1) / 4
, fsc_month                       = ((fsc_quarter_num - 1) * 3) + (1 + (CASE when fsc_week_of_quarter > 12 then 12 else fsc_week_of_quarter end - 1) / 4)
, fsc_week_of_year_label             = convert(char(4), fsc_year) + ' Wk ' + convert(char(2), fsc_week_of_year)
, fsc_yyyyww                    = fsc_year * 100 + fsc_week_of_year
from hifical.cal_fiscal_445 cal
where fsc_year is not null
;

/* set first last days of fiscal weeks */
UPDATE tgt
   SET 
       fsc_week_start_date = tUpd.fsc_week_start_date
       , fsc_week_end_date  = tUpd.fsc_week_end_date 
FROM hifical.cal_fiscal_445 tgt
inner join (
        select 
            fsc_year
            , fsc_week_of_year
            , min(fsc_datekey) fsc_week_start_date
            , max(fsc_datekey) fsc_week_end_date 
        from hifical.cal_fiscal_445
        group by 
            fsc_year
            ,fsc_week_of_year
        ) tUpd
     on tgt.fsc_year = tUpd.fsc_year
    and tgt.fsc_week_of_year = tUpd.fsc_week_of_year;

IF OBJECT_ID('tempdb..#fscMo', 'U') IS NOT NULL
  DROP TABLE #fscMo

GO

select
    fsc_year
    , fsc_month
    , MIN(fsc_datekey) as fsc_month_start_dateActual
    , MAX(fsc_datekey) as fsc_month_end_dateActual
into #fscMo
from hifical.cal_fiscal_445
group by fsc_year, fsc_month
;

update fsc set
fsc.fsc_month_name_short            = cal.cal_month_name_short
, fsc.fsc_month_name_long           = cal.cal_month_name_long
, fsc.fsc_month_start_date          = fscMo.fsc_month_start_dateActual
, fsc.fsc_month_end_date            = fscMo.fsc_month_end_dateActual
, fsc.fsc_yyyymm               = fscMo.fsc_year * 100 + fscMo.fsc_month

from hifical.cal_fiscal_445 fsc
inner join hifical.cal_actual cal 
on cal.cal_year = fsc.fsc_year
inner join #fscMo fscMo
on fsc.fsc_year = fscMo.fsc_year
and fsc.fsc_month = fscMo.fsc_month
and cal.cal_month = fsc.fsc_month
and cal.cal_day = 1 --one row per month
;

update tgt
  set fsc_day_of_month_ordinal = 1 + datediff(day, fsc_month_start_date, fsc_datekey)
from hifical.cal_fiscal_445 tgt