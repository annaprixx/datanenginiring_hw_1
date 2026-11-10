{{ config(severity='warn') }}
-- Подтверждённому заказу не должны списать больше его суммы.
-- Тест находит реальную проблему источника (двойное списание), поэтому уровень warn:
-- данные не подгоняем, а показываем. Что нашли — описано в doc-блоке __overview__.
select
    order_id,
    order_amount,
    paid_amount,
    paid_amount - order_amount as overpaid_amount
from {{ ref('fct_orders') }}
where is_confirmed
  and paid_amount > order_amount
