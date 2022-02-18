{% macro get_where_subquery_explicit(relation, where=None) -%}
    {% do return(adapter.dispatch('get_where_subquery_explicit')(relation, where)) %}
{%- endmacro %}

{% macro default__get_where_subquery_explicit(relation, where) -%}
    {% if where %}
        {%- set filtered -%}
            (select * from {{ relation }} where {{ where }}) dbt_subquery
        {%- endset -%}
        {% do return(filtered) %}
    {%- else -%}
        {% do return(relation) %}
    {%- endif -%}
{%- endmacro %}
