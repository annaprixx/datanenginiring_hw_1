-- По возвращённому заказу деньги должны вернуться полностью: net_paid_amount = 0.
select
    order_id,
    order_status,
    paid_amount,
    refunded_amount,
    net_paid_amount
from {{ ref('fct_orders') }}
where order_status = 'returned'
  and net_paid_amount <> 0
