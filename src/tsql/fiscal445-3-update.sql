/* Fiscal Holidays 

   Why bother with this when we have holidays and workdays in cal_actual?
   The point of holidays in cal_actual is to keep track of available holidays.
   In the Fiscal calendar, we track what is actually observed by the company.

   Configs
   - Which holidays will be fiscal holidays
   - Will federal observance days be holidays?
   - 

*/

/* 
  get a list of holiday names in cal_actual
  update the where clause in the fsc_holidays CTE to exclude holidays that are not recognized in the fiscal calendar
select distinct
    cal_holiday_name
from cal_actual
where cal_is_holiday = 1;
;
*/

with fsc_holidays as (
    select
        datekey
        , cal_holiday_name
    from public.cal_actual
    where 
      cal_is_holiday = 1
      and cal_holiday_name not in ('Martin Luther King Day')

)
update cal_fiscal_445 set
    fsc_is_holiday = 1
    , fsc_holiday_name = case when fsc_is_workday = 1 then cal_holiday_name end
    , fsc_is_workday = 0
from fsc_holidays
where fsc_datekey = datekey
;


/* Christmas and Independence Days if they fall on a weekend will have Federal observance holidays on the nearest workday */
UPDATE public.cal_fiscal_445
set
    fsc_holiday_name = fsc.fsc_holiday_name || ' (Observed)'
    , fsc_is_workday = 0
    , fsc_is_holiday = 1
from public.cal_fiscal_445 fsc
where
    fsc.fsc_holiday_name in ('Christmas Day','Independence Day')
    and date_part('dow',fsc.fsc_datekey) in (0,6) --Saturday, Sunday
    and cal_fiscal_445.fsc_datekey = fsc.fsc_datekey
        + case 
            when date_part('dow',fsc.fsc_datekey) = 0 then 1 --Sunday holiday will be observed Monday, +1 days
            else - 1 end --Saturday holiday will be observed Friday, -1 days
;    


--this is kinda slow--31 seconds for 20 years
with wd as (
    select
        fsc_datekey
        --pg default frame is all rows preceding to current row
        --meaning default sum + window w/o frame gives a running sum
        , sum(fsc_is_workday) over (partition by fsc_yyyymm order by fsc_datekey) as mtd_workdays
    from public.cal_fiscal_445
)
update public.cal_fiscal_445
    set fsc_workday_mtd = wd.mtd_workdays
from wd
where wd.fsc_datekey = cal_fiscal_445.fsc_datekey
;
