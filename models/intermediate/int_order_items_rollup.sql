-- Позиции, свёрнутые до заказа: одна строка — один заказ.
-- Нужно, чтобы в fct_orders попало число товаров без JOIN и агрегаций в слое marts.
with order_items as (
    select * from {{ ref('stg_shop__order_items') }}
)

select
    order_id,
    count(distinct product_id)      as items_count,     -- число разных товаров в заказе
    sum(quantity)                   as units_count,     -- сколько единиц товара всего
    sum(line_amount)                as items_amount     -- сумма позиций после скидок
from order_items
group by order_id
