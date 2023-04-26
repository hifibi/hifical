-- call generate_cal_actual(10,30,current_date);
drop procedure if exists generate_cal_actual(int, int, date);
CREATE OR REPLACE PROCEDURE generate_cal_actual(prior_years INT, future_years INT, pivot_date DATE)
LANGUAGE plpgsql
AS $$
DECLARE 
    start_year INT := EXTRACT(YEAR FROM pivot_date) - (1 + prior_years);
    end_year INT := EXTRACT(YEAR FROM pivot_date) + 1 + future_years;
    start_date DATE := DATE_TRUNC('year', MAKE_DATE(start_year, 1, 1));
    qty_rows INT := (DATE_PART('day', MAKE_DATE(end_year, 12, 31)::TIMESTAMP - start_date::TIMESTAMP) + 1)::INT;
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'cal_actual') THEN
        TRUNCATE TABLE public.cal_actual;
    END IF;

    CREATE TEMP TABLE date_rows (
        datekey DATE
    );

    INSERT INTO date_rows (datekey)
    SELECT start_date + (n-1) AS datekey
    FROM GENERATE_SERIES(1, qty_rows) n;

    INSERT INTO cal_actual (
        datekey,
        datekey_int,
        cal_day,
        cal_day_name_long,
        cal_day_name_short,
        cal_day_of_year,
        cal_month,
        cal_month_end_date,
        cal_month_name_long,
        cal_month_name_short,
        cal_month_begin_date,
        cal_quarter_num,
        cal_weekday_num,
        cal_weekday_month_instance,
        cal_week_of_year,
        cal_is_holiday,
        cal_is_workday,
        cal_year,
        cal_yyyymm,
        cal_yyyyww
    )
    SELECT
        datekey,
        (EXTRACT(YEAR FROM datekey) * 100 + EXTRACT(MONTH FROM datekey)) * 100 + EXTRACT(DAY FROM datekey) AS datekey_int,
        EXTRACT(DAY FROM datekey) AS cal_day,
        TO_CHAR(datekey, 'Day') AS cal_day_name_long,
        TO_CHAR(datekey, 'Dy') AS cal_day_name_short,
        DATE_PART('doy', datekey) AS cal_day_of_year,
        EXTRACT(MONTH FROM datekey) AS cal_month,
        DATE_TRUNC('month', datekey) + INTERVAL '1 month - 1 day' AS cal_month_end_date,
        TO_CHAR(datekey, 'Month') AS cal_month_name_long,
        TO_CHAR(datekey, 'Mon') AS cal_month_name_short,
        DATE_TRUNC('month', datekey) AS cal_month_begin_date,
        DATE_PART('quarter', datekey) AS cal_quarter_num,
        DATE_PART('dow', datekey) AS cal_weekday_num,
        ROW_NUMBER() over (PARTITION BY EXTRACT(YEAR FROM datekey), EXTRACT(MONTH FROM datekey), DATE_PART('dow', datekey) ORDER BY datekey) AS cal_weekday_month_instance,
        DATE_PART('week', datekey) AS cal_week_of_year,
        0 AS cal_is_holiday,
        CASE WHEN DATE_PART('dow', datekey) BETWEEN 2 AND 6 THEN 1 ELSE 0 END AS cal_is_workday,
        EXTRACT(YEAR FROM datekey) AS cal_year,
        EXTRACT(YEAR FROM datekey) * 100 + EXTRACT(MONTH FROM datekey) AS cal_yyyymm,
        EXTRACT(YEAR FROM datekey) * 100 + DATE_PART('week', datekey) AS cal_yyyyww
    FROM date_rows;
    
    DROP TABLE IF EXISTS date_rows;
END $$;
