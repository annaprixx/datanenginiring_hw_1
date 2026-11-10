{{ config(distributed_replicated=true) }}
-- Измерение товаров: одна строка — один товар с развёрнутой иерархией категорий.
with products as (
    select * from {{ ref('stg_shop__products') }}
),

categories as (
    select * from {{ ref('int_category_hierarchy') }}
)

select
    p.product_id,
    p.product_name,
    p.brand,
    p.category_name,
    c.parent_category_name,
    c.root_category_name,
    c.category_level,
    c.category_path
from products as p
-- left join, чтобы товар не исчез из витрины, если его категории нет в справочнике.
left join categories as c
    on c.category_name = p.category_name
