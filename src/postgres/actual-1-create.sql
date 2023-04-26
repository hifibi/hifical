drop table if exists public.cal_actual;

CREATE TABLE public.cal_actual (
	datekey date PRIMARY KEY,
	datekey_int int NULL,
	cal_season varchar(10),
	cal_day int NULL,
	cal_day_name_long varchar(9) NULL,
	cal_day_name_short varchar(3) NULL,
    cal_day_of_year smallint NULL,
    cal_weekday_num int NULL,
	cal_weekday_month_instance int NULL,
	cal_holiday_name varchar(30) NULL,
    cal_is_holiday int NULL,
	cal_is_workday int NULL,
    cal_workday_mtd int NULL,
	cal_month int NULL,
	cal_month_of_quarter int NULL,
	cal_month_begin_date date NULL,
	cal_month_end_date date NULL,
	cal_month_name_long varchar(9) NULL,
	cal_month_name_short varchar(3) NULL,
	cal_quarter_num int NULL,
	cal_week_of_quarter int NULL,
	cal_week_begin_date date NULL,
	cal_week_end_date date NULL,
	cal_week_of_year int NULL,
	cal_year int NULL,
	cal_yyyymm int NULL,
	cal_yyyyww int NULL
)
;