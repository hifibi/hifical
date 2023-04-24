

DROP TABLE if exists public.cal_fiscal_445
;

CREATE TABLE public.cal_fiscal_445 (
    fsc_datekey date PRIMARY KEY,
    fsc_day_of_month_ordinal smallint NULL, --not the same as cal_day.
    fsc_day_of_year smallint NULL,
    fsc_weekday_ordinal smallint NULL, --only meaningful if fiscal week starts other than sunday
    fsc_holiday_name varchar(30) NULL,
    fsc_is_holiday smallint NULL,
    fsc_is_workday smallint NULL,
    fsc_workday_mtd smallint NULL,
    fsc_month_number smallint NULL,
    fsc_month_of_quarter smallint NULL,
    fsc_month_begin_date date NULL,
    fsc_month_end_date date NULL,
    fsc_report_month_number smallint Null,
    fsc_report_month_name_long varchar(9) NULL,
    fsc_report_month_name_short varchar(3) NULL,
    fsc_quarter_num smallint NULL,
    fsc_week_of_quarter smallint NULL,
    fsc_week_begin_date date NULL,
    fsc_week_end_date date NULL,
    fsc_week_of_year smallint NULL,
    fsc_year smallint NULL,
    fsc_year_begin_date date null,
    fsc_year_end_date date null,
    fsc_yyyymm int NULL,
    fsc_yyyyww int NULL
)