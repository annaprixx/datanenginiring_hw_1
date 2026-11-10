{{ config(distributed_replicated=true) }}
-- Календарь: одна строка — один день. Покрывает все даты заказов, включая дни без заказов.
with order_dates as (
    select
        min(order_date) as first_order_date,
        max(order_date) as last_order_date
    from {{ ref('stg_shop__orders') }}
),

-- Интервал заведомо шире данных: ниже календарь обрезается по датам заказов,
-- поэтому новые заказы 2026–2027 годов попадут в витрину без правок модели.
calendar as (
    select generated_day::date as date_day
    from generate_series(
        timestamp '2026-01-01',
        timestamp '2027-12-31',
        interval '1 day'
    ) as g(generated_day)
)

select
    c.date_day,
    extract(year from c.date_day)::int               as year_number,
    extract(quarter from c.date_day)::int            as quarter_number,
    extract(month from c.date_day)::int              as month_number,
    trim(to_char(c.date_day, 'Month'))               as month_name,
    to_char(c.date_day, 'YYYY-MM')                   as year_month,
    extract(day from c.date_day)::int                 as day_of_month,
    extract(isodow from c.date_day)::int              as day_of_week,   -- 1 — понедельник
    trim(to_char(c.date_day, 'Day'))                 as day_name,
    extract(isodow from c.date_day) in (6, 7)        as is_weekend
from calendar as c
cross join order_dates as d
where c.date_day between d.first_order_date and d.last_order_date
