let
    start_date = #"Start Date",
    end_date = #"End Date",
    pivot_date = #"Pivot Date",
    Source = List.Dates(start_date, Duration.Days(end_date - start_date) + 1, #duration(1,0,0,0)),
    #"Converted to Table" = Table.FromList(Source, Splitter.SplitByNothing(), {"datekey"}, null, ExtraValues.Error),
    #"Changed Type" = Table.TransformColumnTypes(#"Converted to Table",{{"datekey", type date}}),
    add_yr = Table.AddColumn(#"Changed Type", "cal_year", each Date.Year([datekey]), Int64.Type),
    add_mo = Table.AddColumn(add_yr, "cal_month", each Date.Month([datekey]), Int64.Type),
    add_dy = Table.AddColumn(add_mo, "cal_day", each Date.Day([datekey]), Int64.Type),
    add_qt = Table.AddColumn(add_dy, "cal_qtr", each Date.QuarterOfYear([datekey]), Int64.Type),
    add_wk = Table.AddColumn(add_qt, "cal_week_of_year", each Date.WeekOfYear([datekey]), Int64.Type),
    add_moq = Table.AddColumn(add_wk, "cal_month_of_quarter", each Number.Mod([cal_month] - 1, 3) + 1, Int64.Type),
    add_mnl = Table.AddColumn(add_moq, "cal_month_name_long", each Date.MonthName([datekey]), type text),
    add_mns = Table.AddColumn(add_mnl, "cal_month_name_short", each Text.Start([cal_month_name_long],3), type text),
    add_doy = Table.AddColumn(add_mns, "cal_day_of_year", each Date.DayOfYear([datekey]), Int64.Type),
    add_dow = Table.AddColumn(add_doy, "cal_day_of_week", each Date.DayOfWeek([datekey]), Int64.Type),
    add_dnl = Table.AddColumn(add_dow, "cal_day_name_long", each Date.DayOfWeekName([datekey]), type text),
    add_dns = Table.AddColumn(add_dnl, "cal_day_name_short", each Text.Start([cal_day_name_long],3), type text),
    add_date_int = Table.AddColumn(add_dns, "cal_date_int", each Number.FromText(Date.ToText([datekey], "yyyyMMdd")), Int64.Type),
    add_yyyyq = Table.AddColumn(add_date_int, "cal_yyyyq", each [cal_year] * 10 + [cal_qtr], Int64.Type),
    add_yyyymm = Table.AddColumn(add_yyyyq, "cal_yyyymm", each [cal_year] * 100 + [cal_month], Int64.Type),
    add_yyyyww = Table.AddColumn(add_yyyymm, "cal_yyyyww", each [cal_year] * 100 + [cal_week_of_year], Int64.Type),
    add_mo_start = Table.AddColumn(add_yyyyww, "cal_month_begin_date", each Date.StartOfMonth([datekey]), Date.Type),
    add_mo_end = Table.AddColumn(add_mo_start, "cal_month_end_date", each Date.EndOfMonth([datekey]), Date.Type),
    add_week_start = Table.AddColumn(add_mo_end, "cal_week_begin_date", each Date.StartOfWeek([datekey]), Date.Type),
    add_week_end = Table.AddColumn(add_week_start, "cal_week_end_date", each Date.EndOfWeek([datekey]), Date.Type),
    
    /* pivot date record */
    pvt = Table.SingleRow(Table.SelectRows(add_week_end, each ([datekey] = pivot_date))), 

    /* Begin adding pivot columns which are calculated relative to the pivot date */
    add_tnd = Table.AddColumn(add_week_end, "topn_days", each Duration.Days(Record.Field(pvt, "datekey") - [datekey]), Int64.Type),
    add_tndy = Table.AddColumn(add_tnd, "topn_days_yoy", each Duration.Days(Date.AddYears(Record.Field(pvt, "datekey"), Record.Field(pvt, "cal_year") - [cal_year]) - [datekey]), Int64.Type), 
    add_tny = Table.AddColumn(add_tndy, "topn_years", each Record.Field(pvt, "cal_year") - [cal_year], Int64.Type),
    add_tnq = Table.AddColumn(add_tny, "topn_quarters", each Record.Field(pvt, "cal_qtr") - [cal_qtr] + 4 * [topn_years], Int64.Type),
    add_tnqy = Table.AddColumn(add_tnq, "topn_quarters_yoy", each Record.Field(pvt, "cal_qtr") - [cal_qtr], Int64.Type),
    add_tnm = Table.AddColumn(add_tnqy, "topn_months", each Record.Field(pvt, "cal_month") - [cal_month] + 12 * [topn_years], Int64.Type),    
    add_tnmy = Table.AddColumn(add_tnm, "topn_months_yoy", each Record.Field(pvt, "cal_month") - [cal_month], Int64.Type),    
    add_ytd = Table.AddColumn(add_tnmy, "is_ytd", each if [datekey] + #duration(365 * [topn_years],0,0,0) <= Record.Field(pvt, "datekey") then 1 else 0, Int64.Type),
    add_qtd = Table.AddColumn(add_ytd, "is_qtd", each 
        if [cal_month_of_quarter] < Record.Field(pvt, "cal_month_of_quarter") then 1
            else if [cal_month_of_quarter] > Record.Field(pvt, "cal_month_of_quarter") then 0
            else if [cal_day] > Record.Field(pvt, "cal_day") then 0
            else 1       
        , Int64.Type),
    add_mtd = Table.AddColumn(add_qtd, "is_mtd", each if [cal_day] <= Record.Field(pvt, "cal_day") then 1 else 0, Int64.Type),
    add_wtd = Table.AddColumn(add_mtd, "is_wtd", each if [cal_day_of_week] <= Record.Field(pvt, "cal_day_of_week") then 1 else 0, Int64.Type)
in
    add_wtd