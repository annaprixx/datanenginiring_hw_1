{{ config(distributed_replicated=true) }}
-- Измерение клиентов: одна строка — один клиент, включая тех, кто ничего не купил.
with customers as (
    select * from {{ ref('stg_shop__customers') }}
),

stats as (
    select * from {{ ref('int_customer_order_stats') }}
)

select
    c.customer_id,
    c.registered_at,
    c.registration_date,
    c.city,
    c.acquisition_channel,
    s.first_confirmed_order_id,
    s.first_confirmed_at,
    coalesce(s.confirmed_orders_count, 0)   as confirmed_orders_count,
    coalesce(s.confirmed_revenue, 0)        as confirmed_revenue,
    s.customer_id is not null               as is_buyer
from customers as c
left join stats as s
    on s.customer_id = c.customer_id
