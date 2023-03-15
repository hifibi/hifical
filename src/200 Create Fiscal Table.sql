IF OBJECT_ID('hifical.cal_fiscal_445', 'U') IS NOT NULL
  DROP TABLE hifical.cal_fiscal_445
;

CREATE TABLE hifical.cal_fiscal_445 (
    fsc_datekey            date PRIMARY KEY,
    fsc_day_of_year        smallint NULL,
    fsc_month              smallint NULL,
    fsc_month_name_long    varchar(9) NULL,
    fsc_month_name_short   varchar(3) NULL,
    fsc_month_of_quarter   smallint NULL,
    fsc_month_start_date   date NULL,
    fsc_month_end_date     date NULL,
    fsc_weekday_num        smallint NULL,
    fsc_day                smallint NULL,
    fsc_quarter_num        smallint NULL,
    fsc_week_of_quarter    smallint NULL,
    fsc_week_of_year       smallint NULL,
    fsc_week_start_date    date NULL,
    fsc_week_end_date      date NULL,
    fsc_week_of_year_label varchar(10) NULL,
    fsc_year               smallint NULL,
    fsc_yyyymm             int NULL,
    fsc_yyyyww             int NULL,
    fsc_is_holiday         tinyint NULL,
    fsc_holiday_name       varchar(30) NULL,
    fsc_is_workday         tinyint NULL,
    fsc_workday_mtd        smallint NULL
)

