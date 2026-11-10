{#
    Greenplum: как хранить таблицу, которую создаёт dbt.

    dbt-postgres ничего не знает о Greenplum и создаёт таблицы обычным
    create table ... as. Этот макрос подменяет встроенный postgres__create_table_as
    (dbt сначала ищет макрос в нашем проекте) и добавляет настройки Greenplum.
    Их задают в config() модели:

        {{ config(distributed_by='order_id') }}           -- distributed by (order_id)
        {{ config(distributed_replicated=true) }}         -- копия на каждом сегменте
        {{ config(orientation='column') }}                -- колоночное хранение (append-optimized)

    Ничего не задано — distributed randomly: строки раскладываются по сегментам случайно.
#}
{% macro postgres__create_table_as(temporary, relation, sql) -%}
    {%- set distributed_by = config.get('distributed_by') -%}
    {%- set distributed_replicated = config.get('distributed_replicated', false) -%}
    {%- set orientation = config.get('orientation') -%}

    create {% if temporary %}temporary {% endif %}table {{ relation }}
    {%- if orientation %}
    with (appendoptimized = true, orientation = {{ orientation }})
    {%- endif %}
    as (
        {{ sql }}
    )
    {% if distributed_replicated and not temporary -%}
    distributed replicated
    {%- elif distributed_by -%}
    distributed by ({{ distributed_by }})
    {%- else -%}
    distributed randomly
    {%- endif %};
{%- endmacro %}
