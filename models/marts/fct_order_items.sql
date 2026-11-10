{{ config(
    materialized='incremental',
    unique_key='order_item_id',
    distributed_by='order_id'
) }}
-- Факт позиций заказа: одна строка — один товар в заказе. Тестовые заказы исключены.
-- Распределение по order_id, как у fct_orders и сырых таблиц: JOIN по заказу идёт локально.
select
    order_item_id,
    order_id,
    product_id,
    customer_id,
    order_date,
    ordered_at,
    quantity,
    unit_price,
    discount_amount,
    gross_amount,
    line_amount,
    is_confirmed
from {{ ref('int_order_items_enriched') }}
where not is_test_order

{% if is_incremental() %}
  -- При повторном запуске берём только позиции заказов, оформленных позже последней загрузки.
  and ordered_at > (select max(ordered_at) from {{ this }})
{% endif %}
