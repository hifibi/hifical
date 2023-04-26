create table public.timezone_seasons (
    start_date date PRIMARY KEY
    , end_date date
    , season varchar(10)
)
;

insert into public.timezone_seasons
with dtl as (
    select
    datekey
    , datekey::timestamp at time zone 'America/Chicago'
    , extract('hour' from datekey::timestamp at time zone 'America/Chicago') as tzoffset
    , extract('hour' from (datekey-1)::timestamp at time zone 'America/Chicago') as tzoffset_yday
    from cal_actual
)
SELECT
    datekey as start_date
    , lead(datekey) over (order by datekey) as end_date
    , case when tzoffset - tzoffset_yday = 1 then 'Winter' else 'Summer' end as season
from dtl
where tzoffset <> tzoffset_yday
;