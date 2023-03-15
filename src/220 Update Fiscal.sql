/* Fiscal Holidays */

--All actual holidays that fall on a normal work day (Mon - Sat)
UPDATE fsc
SET
  fsc_holiday_name = cal_holiday_name
, fsc_is_workday = 0
, fsc_is_holiday = 1
 from hifical.cal_actual cal
 inner join hifical.cal_fiscal_445 fsc
 on cal.datekey = fsc.fsc_datekey
 where fsc_year is not null
 and cal_is_holiday = 1
 and cal_weekday_num > 1 


--Christmas and Independence Days if they fall on a weekend will have observance holidays on the nearest workday

UPDATE fsc
SET
fsc.fsc_holiday_name = cal.cal_holiday_name + ' (Observed)'
, fsc.fsc_is_workday = 0
, fsc.fsc_is_holiday = 1
from hifical.cal_fiscal_445 fsc
inner join hifical.cal_actual cal
on fsc.fsc_datekey = dateadd(dd, CASE when cal.cal_weekday_num = 7 then -1 else 1 end, cal.datekey)
where fsc.fsc_year is not null
and cal.cal_holiday_name in ('Christmas Day','Independence Day')
and cal.cal_weekday_num in (7,1)


/* calculate the in-month workday sequence for workdays */
update fsc
set fsc_workday_mtd = upd_val
from hifical.cal_fiscal_445 fsc
inner join (
    select 
    fsc_datekey
    , ROW_NUMBER() over (Partition By fsc_yyyymm Order by fsc_datekey) as upd_val
    from hifical.cal_fiscal_445
    where
    fsc_is_workday = 1
) as t1 on fsc.fsc_datekey = t1.fsc_datekey;


/* set the workday number for weekends and holidays to that of the previous workday */
update fsc
set fsc_workday_mtd = case when fsc_is_workday = 0 then isnull(upd_fsc_workday_mtd,0) else fsc_workday_mtd end
from hifical.cal_fiscal_445 fsc
left join (
  select top 1 with ties 
  t1.fsc_datekey

  , t2.fsc_workday_mtd as upd_fsc_workday_mtd
  from hifical.cal_fiscal_445 t1
  inner join hifical.cal_fiscal_445 t2
    on t1.fsc_yyyymm = t2.fsc_yyyymm

    and t1.fsc_datekey > t2.fsc_datekey --previous workday
  where
  t1.fsc_is_workday = 0
  and t2.fsc_is_workday = 1
  order by ROW_NUMBER() over (partition by t1.fsc_datekey order by t1.fsc_datekey, t2.fsc_datekey desc) --previous workday
) as t_upd on fsc.fsc_datekey = t_upd.fsc_datekey

