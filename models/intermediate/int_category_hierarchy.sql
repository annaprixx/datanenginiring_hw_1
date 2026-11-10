-- Дерево категорий развёрнуто в плоскую строку: одна строка — одна категория.
-- Рекурсивный CTE идёт от категорий верхнего уровня вниз, поэтому лишний уровень
-- в источнике ничего не сломает: category_level просто станет больше.
with recursive categories as (
    select * from {{ ref('stg_shop__product_categories') }}
),

tree as (
    -- Верхний уровень: родителя нет, корень — сама категория.
    select
        category_id,
        category_name,
        parent_category_id,
        null::text          as parent_category_name,
        category_name       as root_category_name,
        1                   as category_level,
        category_name       as category_path
    from categories
    where parent_category_id is null

    union all

    -- Спуск на уровень ниже: корень наследуется от родителя.
    select
        child.category_id,
        child.category_name,
        child.parent_category_id,
        parent.category_name,
        parent.root_category_name,
        parent.category_level + 1,
        parent.category_path || ' > ' || child.category_name
    from categories as child
    join tree as parent
        on parent.category_id = child.parent_category_id
)

select
    category_id,
    category_name,
    parent_category_id,
    parent_category_name,
    root_category_name,
    category_level,
    category_path
from tree
