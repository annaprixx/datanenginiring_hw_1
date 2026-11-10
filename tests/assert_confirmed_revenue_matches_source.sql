-- Сверка с источником: сумма подтверждённых покупок в витрине должна совпадать с суммой,
-- посчитанной прямо по сырым таблицам raw.orders и raw.payments.
with source_revenue as (
    select coalesce(sum(o.total_amount), 0) as revenue
    from {{ source('shop', 'orders') }} as o
    where o.status = 'paid'
      and exists (
          select 1
          from {{ source('shop', 'payments') }} as p
          where p.order_id = o.order_id
            and p.payment_status = 'success'
            and p.amount >= 0          -- возврат оплатой не считается
      )
),

mart_revenue as (
    select coalesce(sum(order_amount), 0) as revenue
    from {{ ref('fct_orders') }}
    where is_confirmed
)

select
    s.revenue as source_revenue,
    m.revenue as mart_revenue
from source_revenue as s
cross join mart_revenue as m
where s.revenue <> m.revenue
