--create schema hifical;

IF OBJECT_ID('hifical.cal_actual', 'U') IS NOT NULL
  DROP TABLE hifical.cal_actual
;

CREATE TABLE hifical.cal_actual (

	datekey date PRIMARY KEY,
	datekey_int int NULL,
	cal_day tinyint NULL,
	cal_day_name_long varchar(9) NULL,
	cal_day_name_short varchar(3) NULL,
    cal_day_of_year smallint NULL,
    cal_weekday_num tinyint NULL,
	cal_weekday_month_instance tinyint NULL,
	cal_holiday_name varchar(30) NULL,
    cal_is_holiday tinyint NULL,
	cal_is_workday tinyint NULL,
    cal_workday_mtd tinyint NULL,
	cal_month tinyint NULL,
	cal_month_of_quarter tinyint NULL,
	cal_month_begin_date date NULL,
	cal_month_end_date date NULL,
	cal_month_name_long varchar(9) NULL,
	cal_month_name_short varchar(3) NULL,
	cal_quarter_num tinyint NULL,
	cal_week_of_quarter tinyint NULL,
	cal_week_begin_date date NULL,
	cal_week_end_date date NULL,
	cal_week_of_year tinyint NULL,
	cal_year int NULL,
	cal_yyyymm int NULL,
	cal_yyyyww int NULL,
)

