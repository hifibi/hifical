--call public.generate_cal_fiscal445(4,6,0,20,true)

/* 
    Logic is done but needs properly implemented in SPROC
    - check resultant col names with those in the fsc-create table
    - need to squash some layers
    - probably have unused params
    - change all [period]_start_date cols to [period]_begin_date in fsc and actual cals
    - decide how to handle verbiage distinction between fiscal ordinal month and fiscal natural month.
        - the importance of this is not clear until you work with a 445 calendar with a non-January year start.
        - say the year starts in June (Month 6), you need to record that June is Month 1, but nobody
            is going to want reporting that says January when its June just because January is the first day of the actual calendar.
            However, you're also going to have dates in May or July that align to the fiscal month 1, which is June.
            IT WILL MAKE YOU CRAZY.
            What do people expect? They expect to be able to see all dates in fiscal 1st month of the year rolled up and labeled June.
            June is the "Natural Fiscal Month"
            1 is the "Ordinal Fiscal Month"    
            THIS IS ALL WORKED OUT IN THE SCRIPT. Just make sure things are named consistently and logically.
 */

CREATE OR REPLACE PROCEDURE generate_cal_fiscal445(
    week_starts_day_num int default 0
    , year_starts_month_num int default 1
    , start_year int default 0
    , total_years int default 20
    , front_load_extra_week boolean default true --when true, extra weeks go in Q1, M1; when false, extra weeks go in Q4, M4
)
LANGUAGE plpgsql
AS $$
DECLARE
    base_year int = (select min(cal_year) 
                    from public.cal_actual 
                    where cal_year >= start_year 
                    and cal_month = year_starts_month_num 
                    and cal_day = 1 
                    and cal_weekday_num = week_starts_day_num
                    );
    base_year_start_date date = (to_char(base_year, 'FM0000') || '-' || to_char(year_starts_month_num, 'FM00') || '-01')::date; 
    base_year_natural_end_date date = (base_year_start_date + interval '1 Year - 1 Day');
    max_year int = 0;
    max_date date = current_date;
    qty_rows int = 0;
BEGIN
    if start_year = 0 then
        start_year = base_year;
    END IF;
    max_year = start_year + total_years;
    max_date = base_year_natural_end_date + interval '1 year' * total_years;
    qty_rows = max_date - base_year_start_date;

    -- create temporary table _x on commit drop as
    truncate public.cal_fiscal_445;
    insert into public.cal_fiscal_445 (
        fsc_datekey, fsc_year,fsc_year_begin_date, fsc_year_end_date, 
        fsc_day_of_year, fsc_weekday_ordinal, fsc_week_of_year, fsc_quarter_num,
        fsc_is_holiday, fsc_is_workday
    )
        with RECURSIVE yrs (last_year, this_year, fyr_start_date, natural_ye, fyr_ye, has_extra_week) as (
            SELECT 
                base_year - 1 as last_year
                , base_year as this_year
                , base_year_start_date as fyr_start_date
                , base_year_natural_end_date as natural_ye
                , base_year_start_date + 363 as fyr_ye --not 364 because we're starting from first of year, not last of prior year
                , false as has_extra_week
            UNION ALL
            SELECT
                this_year as last_year
                , this_year + 1 as this_year
                , fyr_ye + 1 as fyr_start_date
                , (natural_ye + interval '1 Year')::date as natural_ye
                , fyr_ye 
                    + case when fyr_ye + 371 <= natural_ye + interval '1 Year'
                        then 371 else 364 end as fyr_ye
                , fyr_ye + 371 <= natural_ye + interval '1 Year' as has_extra_week
            from yrs
            WHERE this_year + 1 <= max_year
        )
        select 
            ac.datekey as fsc_datekey
            , yrs.this_year as fsc_year
            , yrs.fyr_start_date as fsc_year_begin_date
            , yrs.fyr_ye as fsc_year_end_date
            , ac.datekey - yrs.fyr_start_date + 1 as fsc_day_of_year
            , date_part('dow', datekey)
                + case when date_part('dow',datekey) - week_starts_day_num < 0 then 7 else 0 end
                - week_starts_day_num
                + 1 as fsc_weekday_ordinal
            , (ac.datekey - fyr_start_date) / 7 + 1 as fsc_week_of_year
            , CASE when front_load_extra_week then
                --exra weeks go in Q1
                CASE
                    when yrs.fyr_ye - 91 < ac.datekey then 4
                    when yrs.fyr_ye - 182 < ac.datekey then 3
                    when yrs.fyr_ye - 273 < ac.datekey then 2
                    else 1 end 
                --extra weeks go in Q4
                else LEAST(4,(ac.datekey - fyr_start_date) / 91 + 1)
            end as fsc_quarter_num
            , cal_is_holiday as fsc_is_holiday
            , 1 as fsc_is_workday--open 7 days
        from yrs
        inner join public.cal_actual ac on ac.datekey between yrs.fyr_start_date and yrs.fyr_ye
        ;

    with woq as (
        select
            fsc_datekey
            , dense_rank() over (partition by fsc_year,fsc_quarter_num order by fsc_year,fsc_quarter_num,fsc_week_of_year) as fsc_week_of_quarter
            , case 
                when max(fsc_week_of_year) over (partition by fsc_year,fsc_quarter_num) = 14
                and fsc_quarter_num = 1 then 1 else 0 end as q1_extra_week --rear load weeks work naturally
        from public.cal_fiscal_445
    )
    update public.cal_fiscal_445
        set 
            fsc_week_of_quarter = woq.fsc_week_of_quarter
            , fsc_month_of_quarter = 
                case when woq.fsc_week_of_quarter < 5 + q1_extra_week then 1
                    when woq.fsc_week_of_quarter < 9 + q1_extra_week then 2
                    else 3 end
            , fsc_month_number = 
                case when woq.fsc_week_of_quarter < 5 + q1_extra_week then 1
                    when woq.fsc_week_of_quarter < 9 + q1_extra_week then 2
                    else 3 end
          + (fsc_quarter_num - 1) * 3
    from woq 
    where woq.fsc_datekey = cal_fiscal_445.fsc_datekey
    ;

    with agg as (
        select 
            fsc_datekey
            , min(fsc_datekey) over(partition by fsc_year, fsc_week_of_year) as wk_min
            , max(fsc_datekey) over(partition by fsc_year, fsc_week_of_year) as wk_max
            , min(fsc_datekey) over(partition by fsc_year, fsc_month_number) as mo_min
            , max(fsc_datekey) over(partition by fsc_year, fsc_month_number) as mo_max
        from public.cal_fiscal_445
    )
    update public.cal_fiscal_445
    set fsc_report_month_number = fsc_month_number - 1 + year_starts_month_num
            - case when fsc_month_number - 1 + year_starts_month_num > 12 then 12 else 0 end
        , fsc_week_begin_date = wk_min
        , fsc_week_end_date = wk_max
        , fsc_month_begin_date = mo_min
        , fsc_month_end_date = mo_max
    from agg
    where agg.fsc_datekey = cal_fiscal_445.fsc_datekey
    ;

    update public.cal_fiscal_445
        set fsc_day_of_month_ordinal = (fsc_datekey - fsc_month_begin_date) + 1
        , fsc_report_month_name_long = to_char(to_char((fsc_year * 100 + fsc_report_month_number) * 100 + 1, 'FM9999-99-99')::date, 'Month')
        , fsc_report_month_name_short = to_char(to_char((fsc_year * 100 + fsc_report_month_number) * 100 + 1, 'FM9999-99-99')::date, 'Mon')
        , fsc_yyyymm = fsc_year * 100 + fsc_month_number
        , fsc_yyyyww = fsc_year * 100 + fsc_week_of_year
    ;

END $$;
