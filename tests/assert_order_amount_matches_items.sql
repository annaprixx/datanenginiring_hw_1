-- Сумма заказа в fct_orders должна совпадать с суммой его позиций в fct_order_items.
-- Расхождение означает, что позиции потерялись или размножились при JOIN.
with items as (
    select
        order_id,
        sum(line_amount) as items_amount
    from {{ ref('fct_order_items') }}
    group by order_id
)

select
    o.order_id,
    o.order_amount,
    coalesce(i.items_amount, 0) as items_amount
from {{ ref('fct_orders') }} as o
left join items as i
    on i.order_id = o.order_id
where coalesce(i.items_amount, 0) <> o.order_amount
