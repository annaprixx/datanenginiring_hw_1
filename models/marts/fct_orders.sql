{{ config(
    distributed_by='order_id',
    orientation='column'
) }}
-- Факт заказов: одна строка — один заказ. Тестовые заказы в витрину не попадают.
-- Материализация — table (задана для папки marts в dbt_project.yml).
with orders as (
    select * from {{ ref('int_orders_with_payments') }}
),

items as (
    select * from {{ ref('int_order_items_rollup') }}
)

select
    o.order_id,
    o.customer_id,
    o.order_date,
    o.ordered_at,
    o.order_status,
    o.order_amount,
    o.paid_amount,
    o.refunded_amount,
    o.net_paid_amount,
    o.successful_payments_count,
    o.first_paid_at,
    coalesce(i.items_count, 0)      as items_count,
    o.is_confirmed
from orders as o
left join items as i
    on i.order_id = o.order_id
where not o.is_test_order
