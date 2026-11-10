-- Загрузка (EL): копируем сырые таблицы OLTP-базы в схему raw хранилища Greenplum.
-- Это не dbt: dbt работает внутри одной базы и только преобразует (T) то, что уже загружено.
-- Позже в курсе эту загрузку будет запускать Airflow. Повторный запуск перезаливает данные.

-- 1. Доступ к PostgreSQL магазина: его таблицы видны в Greenplum как внешние (foreign).
create extension if not exists postgres_fdw;
create server if not exists oltp_shop
    foreign data wrapper postgres_fdw
    options (host 'postgres', port '5432', dbname 'shop');
create user mapping if not exists for current_user
    server oltp_shop
    options (user 'student', password 'studentpass');

drop schema if exists oltp_fdw cascade;   -- тут только ссылки на таблицы, данных нет
create schema oltp_fdw;
import foreign schema public
    limit to (customers, products, product_categories, orders, order_items, payments)
    from server oltp_shop into oltp_fdw;

-- 2. Сырой слой. Ограничений (PK, FK, CHECK) нет: в Greenplum первичный ключ обязан включать
-- ключ распределения, а внешние ключи не проверяются. Качество данных проверяют тесты dbt.
create schema if not exists raw;

create table if not exists raw.customers (
    customer_id integer,
    registered_at timestamp,
    city text,
    acquisition_channel text
) distributed by (customer_id);

create table if not exists raw.products (
    product_id integer,
    category text,
    brand text,
    product_name text
) distributed by (product_id);

-- Маленький справочник: копия на каждом сегменте, JOIN с ним без пересылки строк.
create table if not exists raw.product_categories (
    category_id integer,
    parent_category_id integer,
    category_name text
) distributed replicated;

create table if not exists raw.orders (
    order_id integer,
    customer_id integer,
    order_created_at timestamp,
    status text,
    total_amount numeric(12, 2)
) distributed by (order_id);

-- Позиции и платежи распределены по order_id, как и заказы: JOIN по order_id идёт локально.
create table if not exists raw.order_items (
    order_id integer,
    product_id integer,
    quantity integer,
    unit_price numeric(12, 2),
    discount_amount numeric(12, 2)
) distributed by (order_id);

create table if not exists raw.payments (
    payment_id integer,
    order_id integer,
    paid_at timestamp,
    payment_status text,
    amount numeric(12, 2)
) distributed by (order_id);

-- 3. Полная перезаливка в одной транзакции.
begin;
truncate raw.customers, raw.products, raw.product_categories,
         raw.orders, raw.order_items, raw.payments;

insert into raw.customers (customer_id, registered_at, city, acquisition_channel)
select customer_id, registered_at, city, acquisition_channel from oltp_fdw.customers;

insert into raw.products (product_id, category, brand, product_name)
select product_id, category, brand, product_name from oltp_fdw.products;

insert into raw.product_categories (category_id, parent_category_id, category_name)
select category_id, parent_category_id, category_name from oltp_fdw.product_categories;

insert into raw.orders (order_id, customer_id, order_created_at, status, total_amount)
select order_id, customer_id, order_created_at, status, total_amount from oltp_fdw.orders;

insert into raw.order_items (order_id, product_id, quantity, unit_price, discount_amount)
select order_id, product_id, quantity, unit_price, discount_amount from oltp_fdw.order_items;

insert into raw.payments (payment_id, order_id, paid_at, payment_status, amount)
select payment_id, order_id, paid_at, payment_status, amount from oltp_fdw.payments;
commit;

analyze raw.customers;
analyze raw.products;
analyze raw.product_categories;
analyze raw.orders;
analyze raw.order_items;
analyze raw.payments;
