-- Staging товаров: одна строка — один товар.
-- Категория в источнике хранится текстом — названием из product_categories.
with source as (
    select * from {{ source('shop', 'products') }}
)

select
    product_id,
    product_name,
    brand,
    category                        as category_name
from source
