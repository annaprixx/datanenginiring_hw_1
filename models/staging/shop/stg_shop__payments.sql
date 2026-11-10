-- Staging платёжных операций: одна строка — одна операция.
-- Возврат записан в источнике успешной операцией с отрицательной суммой.
with source as (
    select * from {{ source('shop', 'payments') }}
)

select
    payment_id,
    order_id,
    paid_at,
    payment_status,
    amount,
    payment_status = 'success' and amount < 0 as is_refund   -- true для возврата
from source
