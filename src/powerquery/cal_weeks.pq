let
    Source = cal_base,
    pvt_row = Table.SingleRow(Table.SelectRows(Source, each [topn_days] = 0)),
    #"Removed Other Columns" = Table.SelectColumns(Source,{"cal_year", "cal_week_of_year", "cal_yyyyww"}),
    #"Removed Duplicates" = Table.Distinct(#"Removed Other Columns", {"cal_yyyyww"}),

    /* topn_weeks */
    add_tnw_yoy = Table.AddColumn(#"Removed Duplicates", "topn_weeks_yoy", each Record.Field(pvt_row, "cal_week_of_year") - [cal_week_of_year], Int64.Type),
    #"Sorted Rows" = Table.Sort(add_tnw_yoy,{{"cal_yyyyww", Order.Descending}}),
    #"Added Index" = Table.AddIndexColumn(#"Sorted Rows", "Index", 0, 1, Int64.Type),

    //get a pivot row with the newly-added index
    pvt_wk_row =Table.SingleRow(Table.SelectRows(#"Added Index", each [cal_yyyyww] = Record.Field(pvt_row, "cal_yyyyww"))),
    add_tnw = Table.AddColumn(#"Added Index", "topn_weeks", each [Index] - Record.Field(pvt_wk_row, "Index"), Int64.Type)
in
    add_tnw