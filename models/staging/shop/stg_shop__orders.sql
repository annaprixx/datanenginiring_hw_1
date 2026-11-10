-- Staging: одна строка — один заказ, как в источнике.
-- Только переименование, приведение типов и простые флаги, без JOIN и агрегаций.
with source as (
    select * from {{ source('shop', 'orders') }}
)

select
    order_id,
    customer_id,
    order_created_at                as ordered_at,
    order_created_at::date          as order_date,
    status                          as order_status,
    total_amount                    as order_amount,
    status = 'test'                 as is_test_order
from source
