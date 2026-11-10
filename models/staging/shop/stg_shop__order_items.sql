-- Staging позиций заказа: одна строка — один товар в заказе.
with source as (
    select * from {{ source('shop', 'order_items') }}
)

select
    -- Своего ключа у позиции нет: склеиваем order_id и product_id через дефис, например '101-1'.
    order_id::text || '-' || product_id::text as order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    discount_amount,
    quantity * unit_price           as gross_amount,   -- сумма до скидки
    quantity * unit_price - discount_amount as line_amount     -- сумма после скидки
from source
