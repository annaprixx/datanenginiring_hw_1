-- Итоги по подтверждённым покупкам клиента: одна строка — один клиент, у которого есть покупки.
-- Клиенты без покупок сюда не попадают, их добавляет dim_customers через left join.
with confirmed_orders as (
    select *
    from {{ ref('int_orders_with_payments') }}
    where is_confirmed
      and not is_test_order
),

first_order as (
    select
        customer_id,
        order_id,
        ordered_at,
        -- При одинаковом времени первым считаем заказ с меньшим номером.
        row_number() over (
            partition by customer_id
            order by ordered_at, order_id
        ) as order_number
    from confirmed_orders
),

totals as (
    select
        customer_id,
        count(*)                as confirmed_orders_count,
        sum(order_amount)       as confirmed_revenue,
        sum(net_paid_amount)    as net_paid_amount
    from confirmed_orders
    group by customer_id
)

select
    t.customer_id,
    t.confirmed_orders_count,
    t.confirmed_revenue,
    t.net_paid_amount,
    f.order_id              as first_confirmed_order_id,
    f.ordered_at            as first_confirmed_at
from totals as t
join first_order as f
    on f.customer_id = t.customer_id
   and f.order_number = 1
