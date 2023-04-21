--update actual

/* set first last days of fiscal weeks */
UPDATE public.cal_actual tgt
SET 
    cal_week_start_date = tUpd.cal_week_start_date,
    cal_week_end_date = tUpd.cal_week_end_date
FROM (
    SELECT 
        cal_year,
        cal_week_of_year,
        min(datekey) AS cal_week_start_date,
        max(datekey) AS cal_week_end_date 
    FROM public.cal_actual
    GROUP BY 
        cal_year,
        cal_week_of_year
    ) tUpd
WHERE tgt.cal_year = tUpd.cal_year
AND tgt.cal_week_of_year = tUpd.cal_week_of_year
;



/* Add Holidays */

--===== New Years Day (Specific Day)
 UPDATE public.cal_actual
    SET 
        cal_holiday_name              = 'New Year''s Day',
        cal_is_workday                = 0,
        cal_is_holiday                = 1
  WHERE cal_month                     = 1 
    AND cal_day                       = 1
;
--===== Thanksgiving (4th Thursday in November)
 UPDATE public.cal_actual
    SET 
        cal_holiday_name               = 'Thanksgiving Day',
        cal_is_workday                 = 0,
        cal_is_holiday                 = 1
  WHERE cal_month                     = 11
    AND cal_weekday_num                   = 5
    AND cal_weekday_month_instance      = 4
;
--===== Thanksgiving Friday (label, but not Holiday)
 UPDATE public.cal_actual
    SET 
        cal_holiday_name               = 'Thanksgiving Friday',
        cal_is_workday                 = 0,
        cal_is_holiday                 = 0
  WHERE datekey IN
            (--==== Finds ThanksGiving and adds a day
             SELECT datekey + 1
               FROM public.cal_actual
              WHERE cal_month         = 11
                AND cal_weekday_num       = 5
                AND cal_weekday_month_instance    = 4
            )
;
--===== Christmas (Specific Day)
 UPDATE public.cal_actual
    SET 
        cal_holiday_name   = 'Christmas Day',
        cal_is_workday     = 0,
        cal_is_holiday     = 1
  WHERE cal_month         = 12 
    AND cal_day           = 25
;
--===== Christmas Eve (Specific Day, label, but not holiday)
 UPDATE public.cal_actual
    SET 
        cal_holiday_name   = 'Christmas Eve',
        cal_is_workday     = 0,
        cal_is_holiday     = 0
  WHERE cal_month         = 12 
    AND cal_day           = 24
;
--===== American Independence Day (Specific Day)
 UPDATE public.cal_actual
    SET 
        cal_holiday_name   = 'Independence Day',
        cal_is_workday     = 0,
        cal_is_holiday     = 1
  WHERE cal_month         = 7 
    AND cal_day           = 4
;
--===== Martin Luther King, Jr. (Specific Day)
 UPDATE public.cal_actual
    SET 
        cal_holiday_name   = 'Martin Luther King Day',
        cal_is_workday     = 0,
        cal_is_holiday     = 1
  WHERE cal_month         = 1 
    AND cal_day           = 18
;

--===== Memorial Day (Last Monday of May) could be 4th or 5th Monday of the month.
 UPDATE public.cal_actual
    SET 
        cal_holiday_name           = 'Memorial Day',
        cal_is_workday     = 0,
        cal_is_holiday     = 1
  WHERE datekey IN 
            (--=== Finds first Monday of June and subtracts a week
             SELECT datekey - 7
               FROM public.cal_actual
              WHERE cal_month                = 6
                AND cal_weekday_num              = 2
                AND cal_weekday_month_instance = 1
            )
;
--===== Labor Day (First Monday in September)
 UPDATE public.cal_actual
    SET 
        cal_holiday_name   = 'Labor Day',
        cal_is_workday   = 0,
        cal_is_holiday   = 1
  WHERE cal_month    = 9
    AND cal_weekday_num  = 2
    AND cal_weekday_month_instance     = 1
;

/* calculate the in-month workday sequence for workdays */
UPDATE public.cal_actual
SET 
    cal_workday_mtd = upd_val
FROM (
    SELECT 
        datekey, 
        ROW_NUMBER() OVER (PARTITION BY cal_yyyymm ORDER BY datekey) AS upd_val
    FROM public.cal_actual
    WHERE cal_is_workday = 1
) AS t1
WHERE public.cal_actual.datekey = t1.datekey
;


/* set the workday number for weekends and holidays to that of the previous workday */
UPDATE public.cal_actual AS t1
SET cal_workday_mtd = COALESCE(t2.cal_workday_mtd, 0)
FROM (
  SELECT datekey, 
         cal_workday_mtd, 
         COALESCE(LAG(cal_workday_mtd) OVER (ORDER BY datekey), 0) AS prev_workday_mtd
  FROM public.cal_actual
  WHERE cal_is_workday = 1
) AS t2
WHERE t1.datekey = t2.datekey
OR (t1.datekey < t2.datekey AND t1.cal_is_workday = 0 AND t2.prev_workday_mtd IS NOT NULL)

;


/* clean up extra years generated to support calculations */

WITH years AS (
  SELECT MIN(cal_year) AS minYr, MAX(cal_year) AS maxYr 
  FROM public.cal_actual
)
DELETE FROM public.cal_actual 
USING years
WHERE cal_year = years.minYr OR cal_year = years.maxYr
;
