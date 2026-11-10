-- Единая инициализация PostgreSQL для лекции и практики 2.
-- Выполняется один раз при создании базы на пустом томе.

-- Схема
CREATE TABLE product_categories (
    category_id integer PRIMARY KEY,
    parent_category_id integer REFERENCES product_categories(category_id),
    category_name text NOT NULL UNIQUE
);

CREATE TABLE customers (
    customer_id integer PRIMARY KEY,
    registered_at timestamp NOT NULL,
    city text NOT NULL,
    acquisition_channel text NOT NULL
);

CREATE TABLE products (
    product_id integer PRIMARY KEY,
    category text NOT NULL REFERENCES product_categories(category_name),
    brand text NOT NULL,
    product_name text NOT NULL
);

CREATE TABLE orders (
    order_id integer PRIMARY KEY,
    customer_id integer NOT NULL REFERENCES customers(customer_id),
    order_created_at timestamp NOT NULL,
    status text NOT NULL CHECK (status IN ('paid', 'pending', 'returned', 'cancelled', 'test')),
    total_amount numeric(12, 2) NOT NULL CHECK (total_amount >= 0)
);

CREATE TABLE order_items (
    order_id integer NOT NULL REFERENCES orders(order_id),
    product_id integer NOT NULL REFERENCES products(product_id),
    quantity integer NOT NULL CHECK (quantity > 0),
    unit_price numeric(12, 2) NOT NULL CHECK (unit_price >= 0),
    discount_amount numeric(12, 2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    PRIMARY KEY (order_id, product_id),
    CHECK (discount_amount <= quantity * unit_price)
);

CREATE TABLE payments (
    payment_id integer PRIMARY KEY,
    order_id integer NOT NULL REFERENCES orders(order_id),
    paid_at timestamp,
    payment_status text NOT NULL CHECK (payment_status IN ('success', 'failed', 'pending')),
    amount numeric(12, 2) NOT NULL,
    CHECK (payment_status <> 'success' OR paid_at IS NOT NULL)
);

CREATE TABLE events (
    event_id integer PRIMARY KEY,
    customer_id integer REFERENCES customers(customer_id),
    event_time timestamp NOT NULL,
    event_type text NOT NULL,
    product_id integer REFERENCES products(product_id),
    session_id text
);

-- Сырой слой для примера дедупликации. В отличие от events, event_id не уникален.
CREATE TABLE raw_events (
    raw_event_row_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_id integer NOT NULL,
    customer_id integer REFERENCES customers(customer_id),
    event_time timestamp NOT NULL,
    event_type text NOT NULL,
    product_id integer REFERENCES products(product_id),
    session_id text,
    loaded_at timestamp NOT NULL
);

-- Базовые учебные данные
INSERT INTO product_categories (category_id, parent_category_id, category_name) VALUES
    (1, NULL, 'Electronics'),
    (2, 1, 'Smartphones'),
    (3, 1, 'Laptops'),
    (4, 1, 'Audio'),
    (5, 1, 'Accessories'),
    (6, NULL, 'Home'),
    (7, 6, 'Appliances');

INSERT INTO customers (customer_id, registered_at, city, acquisition_channel) VALUES
    (1, '2026-02-15 10:00', 'Moscow', 'search'),
    (2, '2026-02-16 11:00', 'Kazan', 'email'),
    (3, '2026-02-17 12:00', 'Moscow', 'organic'),
    (4, '2026-02-18 13:00', 'Perm', 'search'),
    (5, '2026-02-19 14:00', 'Kazan', 'email'),
    (6, '2026-02-20 15:00', 'Moscow', 'organic'),
    (7, '2026-02-21 16:00', 'Perm', 'search'),
    (8, '2026-02-22 17:00', 'Kazan', 'email'),
    (9, '2026-02-23 18:00', 'Moscow', 'organic'),
    (10, '2026-02-24 19:00', 'Perm', 'search'),
    (11, '2026-02-25 20:00', 'Moscow', 'email');

INSERT INTO products (product_id, category, brand, product_name) VALUES
    (1, 'Smartphones', 'North', 'Phone A'),
    (2, 'Smartphones', 'South', 'Phone B'),
    (3, 'Laptops', 'North', 'Laptop A'),
    (4, 'Audio', 'East', 'Headphones A'),
    (5, 'Accessories', 'West', 'Cable A'),
    (6, 'Accessories', 'West', 'Case A'),
    (7, 'Appliances', 'East', 'Kettle A'),
    (8, 'Accessories', 'South', 'Mouse A');

INSERT INTO orders (order_id, customer_id, order_created_at, status, total_amount) VALUES
    (101, 1, '2026-03-01 10:00', 'paid', 1000),
    (102, 1, '2026-03-01 10:00', 'paid', 900),
    (103, 1, '2026-03-03 11:00', 'paid', 900),
    (104, 2, '2026-03-01 11:00', 'paid', 1000),
    (105, 2, '2026-03-02 12:00', 'paid', 900),
    (106, 3, '2026-03-03 13:00', 'paid', 900),
    (107, 3, '2026-03-04 14:00', 'returned', 700),
    (108, 4, '2026-03-04 15:00', 'pending', 100),
    (109, 4, '2026-03-05 16:00', 'cancelled', 200),
    (110, 5, '2026-03-05 17:00', 'paid', 700),
    (111, 6, '2026-03-06 18:00', 'paid', 100),
    (112, 6, '2026-03-08 19:00', 'paid', 100),
    (113, 7, '2026-03-08 20:00', 'paid', 200),
    (114, 7, '2026-03-08 20:00', 'paid', 1000),
    (115, 8, '2026-03-09 10:00', 'test', 100),
    (116, 8, '2026-03-10 11:00', 'paid', 1900),
    (117, 9, '2026-03-10 12:00', 'paid', 800),
    (118, 9, '2026-03-11 13:00', 'pending', 200),
    (119, 10, '2026-03-12 14:00', 'paid', 1000),
    (120, 10, '2026-03-12 15:00', 'paid', 900);

INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount_amount) VALUES
    (101, 1, 1, 1000, 0),
    (102, 3, 1, 900, 0),
    (103, 4, 1, 900, 0),
    (104, 2, 1, 1000, 0),
    (105, 3, 1, 900, 0),
    (106, 4, 1, 900, 0),
    (107, 7, 1, 700, 0),
    (108, 5, 1, 100, 0),
    (109, 8, 1, 200, 0),
    (110, 7, 1, 700, 0),
    (111, 5, 1, 100, 0),
    (112, 6, 1, 100, 0),
    (113, 8, 1, 200, 0),
    (114, 1, 1, 1000, 0),
    (115, 5, 1, 100, 0),
    (116, 3, 1, 900, 0),
    (116, 1, 1, 1000, 0),
    (117, 7, 1, 700, 0),
    (117, 5, 2, 100, 100),
    (118, 8, 1, 200, 0),
    (119, 2, 1, 1000, 0),
    (120, 4, 1, 900, 0);

INSERT INTO payments (payment_id, order_id, paid_at, payment_status, amount) VALUES
    (1001, 101, '2026-03-01 10:05', 'success', 1000),
    (1002, 102, '2026-03-01 10:10', 'success', 900),
    (1003, 103, '2026-03-03 11:05', 'success', 900),
    (1004, 104, '2026-03-01 11:05', 'success', 1000),
    (1005, 105, '2026-03-02 12:05', 'success', 900),
    (1006, 106, '2026-03-03 13:05', 'success', 900),
    (1007, 107, '2026-03-04 14:05', 'success', 700),
    (1008, 107, '2026-03-05 09:00', 'success', -700),
    (1009, 108, NULL, 'pending', 100),
    (1010, 109, '2026-03-05 16:05', 'failed', 200),
    (1011, 110, '2026-03-05 17:05', 'success', 700),
    (1012, 111, '2026-03-06 18:02', 'failed', 100),
    (1013, 111, '2026-03-06 18:07', 'success', 100),
    (1014, 112, '2026-03-08 19:05', 'success', 100),
    (1015, 113, '2026-03-08 20:03', 'success', 200),
    (1016, 113, '2026-03-08 20:04', 'success', 200),
    (1017, 114, '2026-03-08 20:05', 'success', 1000),
    (1018, 115, '2026-03-09 10:05', 'success', 100),
    (1019, 116, '2026-03-10 11:05', 'success', 1000),
    (1020, 116, '2026-03-10 11:06', 'success', 900),
    (1021, 117, '2026-03-10 12:05', 'success', 800),
    (1022, 118, NULL, 'pending', 200),
    (1023, 120, '2026-03-12 15:05', 'success', 900);

INSERT INTO events (event_id, customer_id, event_time, event_type, product_id, session_id) VALUES
    (201, 1, '2026-03-01 09:55', 'product_view', 1, 's-1'),
    (202, 1, '2026-03-01 09:56', 'add_to_cart', 1, 's-1'),
    (203, 1, '2026-03-01 09:58', 'checkout', 1, 's-1'),
    (204, 1, '2026-03-01 10:05', 'purchase', 1, 's-1'),
    (205, 2, '2026-03-01 10:50', 'product_view', 2, 's-2'),
    (206, 2, '2026-03-01 10:52', 'add_to_cart', 2, 's-2'),
    (207, 2, '2026-03-01 11:00', 'checkout', 2, 's-2'),
    (208, 2, '2026-03-01 11:05', 'purchase', 2, 's-2'),
    (209, 3, '2026-03-03 12:45', 'product_view', 4, 's-3'),
    (210, 3, '2026-03-03 12:47', 'add_to_cart', 4, 's-3'),
    (211, 3, '2026-03-03 12:50', 'checkout', 4, 's-3'),
    (212, 3, '2026-03-03 13:05', 'purchase', 4, 's-3'),
    (213, 4, '2026-03-04 14:55', 'product_view', 5, 's-4'),
    (214, 4, '2026-03-04 15:00', 'add_to_cart', 5, 's-4'),
    (215, 5, '2026-03-05 16:50', 'product_view', 7, 's-5'),
    (216, 5, '2026-03-05 17:05', 'purchase', 7, 's-5'),
    (217, 6, '2026-03-06 17:55', 'product_view', 5, 's-6'),
    (218, 6, '2026-03-06 18:07', 'purchase', 5, 's-6'),
    (219, 7, '2026-03-08 19:55', 'product_view', 8, 's-7'),
    (220, 7, '2026-03-08 20:05', 'purchase', 8, 's-7'),
    (221, NULL, '2026-03-08 21:00', 'product_view', 1, NULL),
    (222, NULL, '2026-03-08 21:01', 'product_view', 3, NULL),
    (223, 8, '2026-03-10 10:55', 'product_view', 3, 's-8'),
    (224, 8, '2026-03-10 11:06', 'purchase', 3, 's-8');

INSERT INTO raw_events (event_id, customer_id, event_time, event_type, product_id, session_id, loaded_at)
SELECT event_id, customer_id, event_time, event_type, product_id, session_id,
       event_time + interval '1 minute'
FROM events;

-- Повторная доставка четырех событий: последняя версия должна выиграть.
INSERT INTO raw_events (event_id, customer_id, event_time, event_type, product_id, session_id, loaded_at) VALUES
    (201, 1, '2026-03-01 09:55', 'product_view', 1, 's-1', '2026-03-02 08:00'),
    (205, 2, '2026-03-01 10:50', 'product_view', 2, 's-2', '2026-03-02 08:01'),
    (213, 4, '2026-03-04 14:55', 'product_view', 5, 's-4', '2026-03-05 08:00'),
    (223, 8, '2026-03-10 10:55', 'product_view', 3, 's-8', '2026-03-11 08:00');

-- Расширенные учебные данные
-- Дополнительные детерминированные данные для лекционных примеров.
-- Полный набор позиций сразу создаётся при инициализации чистого тома.

insert into product_categories (category_id, parent_category_id, category_name) values
    (8, 6, 'Furniture'),
    (9, 6, 'Kitchen'),
    (10, 9, 'Cookware'),
    (11, 5, 'Cases'),
    (12, 5, 'Chargers')
on conflict do nothing;

insert into products (product_id, category, brand, product_name) values
    (9, 'Furniture', 'North', 'Chair A'),
    (10, 'Kitchen', 'East', 'Pan A'),
    (11, 'Cookware', 'East', 'Pot A'),
    (12, 'Cases', 'West', 'Case B'),
    (13, 'Chargers', 'South', 'Charger A')
on conflict do nothing;

insert into customers (customer_id, registered_at, city, acquisition_channel)
select customer_id,
       timestamp '2026-02-26 09:00' + (customer_id - 12) * interval '3 hours',
       (array['Moscow', 'Kazan', 'Perm', 'Saint Petersburg',
              'Novosibirsk', 'Yekaterinburg'])[1 + mod(customer_id, 6)],
       (array['search', 'email', 'organic', 'social', 'ads', 'partner'])[1 + mod(customer_id, 6)]
from generate_series(12, 40) as g(customer_id)
on conflict do nothing;

create temporary table seed_extra_orders as
select order_id,
       case when order_id <= 180
            then 1 + mod(order_id - 121, 10)
            else 12 + mod(order_id - 181, 20)
       end as customer_id,
       timestamp '2026-03-13 10:00'
           + ((order_id - 121) / 2) * interval '2 days'
           + mod(order_id, 2) * interval '2 hours' as order_created_at,
       case when mod(order_id, 20) = 0 then 'returned'
            when mod(order_id, 13) = 0 then 'cancelled'
            when mod(order_id, 11) = 0 then 'pending'
            when mod(order_id, 17) = 0 then 'test'
            else 'paid'
       end as status
from generate_series(121, 240) as g(order_id);

-- Сохраняем прежние суммы заказов, от которых зависят примеры практики.
create temporary table seed_extra_totals as
select order_id,
       sum(quantity * unit_price - discount_amount)::numeric(12, 2) as total_amount
from (
    select order_id,
           1 + case when mod(order_id, 4) = 0 then 1 else 0 end as quantity,
           case mod(order_id, 5)
               when 0 then 1000 when 1 then 700 when 2 then 600
               when 3 then 350 else 450 end::numeric(12, 2) as unit_price,
           case when mod(order_id, 7) = 0 then 50 else 0 end::numeric(12, 2) as discount_amount
    from seed_extra_orders
    union all
    select order_id,
           1 + case when mod(order_id, 6) = 0 then 1 else 0 end,
           case mod(order_id, 5)
               when 0 then 100 when 1 then 100 when 2 then 200
               when 3 then 150 else 250 end::numeric(12, 2),
           case when mod(order_id, 9) = 0 then 20 else 0 end::numeric(12, 2)
    from seed_extra_orders
) as source_items
group by order_id;

-- От 1 до 6 разных товаров на заказ. Деление в копейках сохраняет сумму точно.
create temporary table seed_extra_items as
with weighted_items as (
    select t.order_id, t.total_amount, item_no,
           1 + mod(t.order_id + item_no, 4) as item_weight
    from seed_extra_totals as t
    cross join lateral generate_series(1, 1 + mod(t.order_id, 6)) as positions(item_no)
),
allocated_items as (
    select *,
           sum(item_weight) over (partition by order_id) as total_weight,
           sum(item_weight) over (
               partition by order_id
               order by item_no
               rows between unbounded preceding and current row
           ) as running_weight
    from weighted_items
)
select order_id,
       (array[1, 2, 5, 6, 7, 8, 9, 10, 11, 12, 13])[
           1 + mod(order_id + item_no * 3, 11)
       ] as product_id,
       1 as quantity,
       (
           (
               floor(total_amount * 100 * running_weight / total_weight)
               - floor(total_amount * 100 * (running_weight - item_weight) / total_weight)
           ) / 100
           + case when mod(order_id + item_no, 7) = 0 then 20 else 0 end
       )::numeric(12, 2) as unit_price,
       (case when mod(order_id + item_no, 7) = 0 then 20 else 0 end)::numeric(12, 2)
           as discount_amount
from allocated_items;

insert into orders (order_id, customer_id, order_created_at, status, total_amount)
select e.order_id, e.customer_id, e.order_created_at, e.status,
       sum(i.quantity * i.unit_price - i.discount_amount)
from seed_extra_orders as e
join seed_extra_items as i using (order_id)
group by e.order_id, e.customer_id, e.order_created_at, e.status
on conflict (order_id) do nothing;

insert into order_items (order_id, product_id, quantity, unit_price, discount_amount)
select order_id, product_id, quantity, unit_price, discount_amount
from seed_extra_items
on conflict (order_id, product_id) do nothing;

-- Первая попытка платежа: успешная, неуспешная или ожидающая по статусу заказа.
insert into payments (payment_id, order_id, paid_at, payment_status, amount)
select o.order_id * 10 + 1, o.order_id,
       case when e.status = 'pending' then null
            else e.order_created_at + interval '5 minutes' end,
       case when e.status = 'pending' then 'pending'
            when e.status = 'cancelled' then 'failed'
            else 'success' end,
       case when e.status = 'paid' and mod(o.order_id, 23) = 0
            then o.total_amount / 2 else o.total_amount end
from orders as o
join seed_extra_orders as e using (order_id)
on conflict (payment_id) do nothing;

-- Возврат обнуляет платежный итог; часть оплаченных заказов оплачена в два шага.
insert into payments (payment_id, order_id, paid_at, payment_status, amount)
select o.order_id * 10 + 2, o.order_id,
       case when e.status = 'returned'
            then e.order_created_at + interval '2 days'
            else e.order_created_at + interval '6 minutes' end,
       'success',
       case when e.status = 'returned' then -o.total_amount
            else o.total_amount / 2 end
from orders as o
join seed_extra_orders as e using (order_id)
where e.status = 'returned'
   or (e.status = 'paid' and mod(o.order_id, 23) = 0)
on conflict (payment_id) do nothing;

-- Неуспешная попытка перед удачной оплатой.
insert into payments (payment_id, order_id, paid_at, payment_status, amount)
select o.order_id * 10 + 3, o.order_id,
       e.order_created_at + interval '2 minutes', 'failed', o.total_amount
from orders as o
join seed_extra_orders as e using (order_id)
where e.status = 'paid' and mod(o.order_id, 19) = 0
on conflict (payment_id) do nothing;

create temporary table seed_extra_events as
select e.order_id * 10 + step.step_no as event_id,
       e.customer_id,
       e.order_created_at + step.minute_offset * interval '1 minute' as event_time,
       case when step.step_no = 1 then 'product_view'
            when step.step_no = 2 then 'add_to_cart'
            when e.status in ('paid', 'returned', 'test') then 'purchase'
            else 'checkout' end as event_type,
       first_item.product_id,
       's-extra-' || e.order_id as session_id
from seed_extra_orders as e
join (
    select order_id, min(product_id) as product_id
    from seed_extra_items
    group by order_id
) as first_item using (order_id)
cross join (values (1, -20), (2, -10), (3, 5)) as step(step_no, minute_offset);

insert into events (event_id, customer_id, event_time, event_type, product_id, session_id)
select event_id, customer_id, event_time, event_type, product_id, session_id
from seed_extra_events
on conflict (event_id) do nothing;

insert into raw_events
    (event_id, customer_id, event_time, event_type, product_id, session_id, loaded_at)
select e.event_id, e.customer_id, e.event_time, e.event_type, e.product_id,
       e.session_id, e.event_time + interval '1 minute'
from seed_extra_events as e
where not exists (
    select 1 from raw_events as r
    where r.event_id = e.event_id
      and r.loaded_at = e.event_time + interval '1 minute'
);

-- Повторная доставка одного события на каждые десять новых заказов.
insert into raw_events
    (event_id, customer_id, event_time, event_type, product_id, session_id, loaded_at)
select e.event_id, e.customer_id, e.event_time, e.event_type, e.product_id,
       e.session_id, e.event_time + interval '1 day'
from seed_extra_events as e
where mod(e.event_id, 10) = 1
  and mod(e.event_id / 10, 10) = 0
  and not exists (
      select 1 from raw_events as r
      where r.event_id = e.event_id
        and r.loaded_at = e.event_time + interval '1 day'
  );

-- Дополнительный заказ делает суммы оплаченных заказов клиентов 1 и 2 равными.
-- Поэтому dense_rank() в примере №19 показывает общую первую позицию.
insert into orders (order_id, customer_id, order_created_at, status, total_amount)
values (241, 1, '2026-07-11 10:00', 'paid', 550)
on conflict (order_id) do nothing;

insert into order_items (order_id, product_id, quantity, unit_price, discount_amount) values
    (241, 10, 1, 350, 0),
    (241, 8, 1, 200, 0)
on conflict (order_id, product_id) do nothing;

insert into payments (payment_id, order_id, paid_at, payment_status, amount)
values (2411, 241, '2026-07-11 10:05', 'success', 550)
on conflict (payment_id) do nothing;

insert into events (event_id, customer_id, event_time, event_type, product_id, session_id) values
    (2411, 1, '2026-07-11 09:40', 'product_view', 10, 's-extra-241'),
    (2412, 1, '2026-07-11 09:50', 'add_to_cart', 10, 's-extra-241'),
    (2413, 1, '2026-07-11 10:05', 'purchase', 10, 's-extra-241')
on conflict (event_id) do nothing;

insert into raw_events
    (event_id, customer_id, event_time, event_type, product_id, session_id, loaded_at)
select e.event_id, e.customer_id, e.event_time, e.event_type, e.product_id,
       e.session_id, e.event_time + interval '1 minute'
from events as e
where e.event_id in (2411, 2412, 2413)
  and not exists (
      select 1 from raw_events as r
      where r.event_id = e.event_id
        and r.loaded_at = e.event_time + interval '1 minute'
  );
