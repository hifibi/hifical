--update actual

/* set first last days of fiscal weeks */
UPDATE tgt
   SET 
       cal_week_start_date = tUpd.cal_week_start_date
       , cal_week_end_date  = tUpd.cal_week_end_date 
FROM hifical.cal_actual tgt
inner join (
        select 
            cal_year
            , cal_week_of_year
            , min(datekey) cal_week_start_date
            , max(datekey) cal_week_end_date 
        from hifical.cal_actual
        group by 
            cal_year
            , cal_week_of_year
        ) tUpd
    on tgt.cal_year = tUpd.cal_year
    and tgt.cal_week_of_year = tUpd.cal_week_of_year
;


/* Add Holidays */

--===== New Years Day (Specific Day)
 UPDATE hifical.cal_actual
    SET 
        cal_holiday_name               = 'New Year''s Day',
        cal_is_workday                 = 0,
        cal_is_holiday                 = 1
  WHERE cal_month                     = 1 
    AND cal_day                       = 1
;
--===== Thanksgiving (4th Thursday in November)
 UPDATE hifical.cal_actual
    SET 
        cal_holiday_name               = 'Thanksgiving Day',
        cal_is_workday                 = 0,
        cal_is_holiday                 = 1
  WHERE cal_month                     = 11
    AND cal_weekday_num                   = 5
    AND cal_weekday_month_instance      = 4
;
--===== Thanksgiving Friday (label, but not Holiday)
 UPDATE hifical.cal_actual
    SET 
        cal_holiday_name               = 'Thanksgiving Friday',
        cal_is_workday                 = 0,
        cal_is_holiday                 = 0
  WHERE datekey IN
            (--==== Finds ThanksGiving and adds a day
             SELECT dateadd(dd,1,datekey)

               FROM hifical.cal_actual
              WHERE cal_month         = 11
                AND cal_weekday_num       = 5
                AND cal_weekday_month_instance    = 4
            )
;
--===== Christmas (Specific Day)
 UPDATE hifical.cal_actual
    SET 
        cal_holiday_name   = 'Christmas Day',
        cal_is_workday     = 0,
        cal_is_holiday     = 1
  WHERE cal_month         = 12 
    AND cal_day           = 25
;
--===== Christmas Eve (Specific Day, label, but not holiday)
 UPDATE hifical.cal_actual
    SET 
        cal_holiday_name   = 'Christmas Eve',
        cal_is_workday     = 0,
        cal_is_holiday     = 0
  WHERE cal_month         = 12 
    AND cal_day           = 24
;
--===== American Independence Day (Specific Day)
 UPDATE hifical.cal_actual
    SET 
        cal_holiday_name   = 'Independence Day',
        cal_is_workday     = 0,
        cal_is_holiday     = 1
  WHERE cal_month         = 7 
    AND cal_day           = 4
;
--===== Martin Luther King, Jr. (Specific Day)
 UPDATE hifical.cal_actual
    SET 
        cal_holiday_name   = 'Martin Luther King Day',
        cal_is_workday     = 0,
        cal_is_holiday     = 1
  WHERE cal_month         = 1 
    AND cal_day           = 18
;

--===== Memorial Day (Last Monday of May) could be 4th or 5th Monday of the month.
 UPDATE hifical.cal_actual
    SET 
        cal_holiday_name           = 'Memorial Day',
        cal_is_workday     = 0,
        cal_is_holiday     = 1
   FROM hifical.cal_actual
  WHERE datekey IN 
            (--=== Finds first Monday of June and subtracts a week
             SELECT dateadd(wk,-1,datekey)

               FROM hifical.cal_actual
              WHERE cal_month                = 6
                AND cal_weekday_num              = 2
                AND cal_weekday_month_instance = 1
            )
;
--===== Labor Day (First Monday in September)
 UPDATE hifical.cal_actual
    SET 
        cal_holiday_name   = 'Labor Day',
        cal_is_workday   = 0,
        cal_is_holiday   = 1
  WHERE cal_month    = 9
    AND cal_weekday_num  = 2
    AND cal_weekday_month_instance     = 1
;

/* calculate the in-month workday sequence for workdays */
update hifical.cal_actual
set cal_workday_mtd = upd_val
from hifical.cal_actual
inner join (
    select 
    datekey
    , ROW_NUMBER() over (Partition By cal_yyyymm Order by datekey) as upd_val
    from hifical.cal_actual
    where
    cal_is_workday = 1
) as t1 on hifical.cal_actual.datekey = t1.datekey;


/* set the workday number for weekends and holidays to that of the previous workday */
update hifical.cal_actual
set cal_workday_mtd = case when cal_is_workday = 0 then isnull(upd_cal_workday_mtd,0) else cal_workday_mtd end
from hifical.cal_actual
left join (
  select top 1 with ties 
  t1.datekey

  , t2.cal_workday_mtd as upd_cal_workday_mtd
  from hifical.cal_actual t1
  inner join hifical.cal_actual t2
    on t1.cal_yyyymm = t2.cal_yyyymm
    and t1.datekey > t2.datekey --previous workday
  where
  t1.cal_is_workday = 0
  and t2.cal_is_workday = 1
  order by ROW_NUMBER() over (partition by t1.datekey order by t1.datekey, t2.datekey desc) --previous workday
) as t_upd on hifical.cal_actual.datekey = t_upd.datekey

/* clean up extra years generated to support calculations */

delete ca
from hifical.cal_actual ca
inner join (
  select min(cal_year) minYr, max(cal_year) maxYr from hifical.cal_actual
) yr
  on ca.cal_year = yr.minYr
  or ca.cal_year = yr.maxYr
