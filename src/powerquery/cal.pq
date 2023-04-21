let
    Source = Table.NestedJoin(cal_base, {"cal_yyyyww"}, cal_weeks, {"cal_yyyyww"}, "pq_cal_weeks", JoinKind.LeftOuter),
    #"Expanded pq_cal_weeks" = Table.ExpandTableColumn(Source, "pq_cal_weeks", {"topn_weeks_yoy", "topn_weeks"}, {"topn_weeks_yoy", "topn_weeks"}),
    #"Added Custom" = Table.AddColumn(#"Expanded pq_cal_weeks", "Report Month Filter", each if [topn_months] = 0 then "Current Month"
else if [topn_months] = 1 then "Prior Month"
else Date.ToText([datekey], "MMMM yyyy"), type text),
    #"Added Custom1" = Table.AddColumn(#"Added Custom", "Report Year Filter", each if [topn_years] = 0
then "Current Year"
else if [topn_years] = 1
then "Prior Year"
else Text.From([cal_year]), type text),
    #"Added Custom2" = Table.AddColumn(#"Added Custom1", "Report Week Filter", each if [topn_weeks] = 0 then "Current Week" else if [topn_weeks] = 1 then "Prior Week" else Text.From([cal_year]) & " Wk " & Text.From([cal_week_of_year]), type text),
    #"Added Custom3" = Table.AddColumn(#"Added Custom2", "Report Quarter Filter", each if [topn_quarters] = 0 then "Current Quarter"
else if [topn_quarters] = 1 then "Prior Quarter" else Text.From([cal_year]) & " Q" & Text.From([cal_qtr]), type text)
in
    #"Added Custom3"