{% test expect_column_values_to_be_progressing_in_partition(model, column_name,
                                                   partition_column,
                                                   sort_column=None,
                                                   min_diff=0,
                                                   max_diff=1) %}

{%- set sort_column = column_name if not sort_column else sort_column -%}
with all_values as (

    select
        {{ partition_column }} as partition_column,
        {{ sort_column }} as sort_column,
        {{ column_name }} as value_field

    from {{ model }}
    {% if row_condition %}
    where {{ row_condition }}
    {% endif %}

),
add_lag_values as (

    select
        partition_column,
        sort_column,
        value_field,
        lag(value_field) over(partition by partition_column order by sort_column) as value_field_lag
    from
        all_values

),
validation_errors as (

    select
        *
    from
        add_lag_values
    where
        value_field_lag is not null
        and
        not ((value_field - value_field_lag) between {{ min_diff }} and {{ max_diff }})

)
select *
from validation_errors
{% endtest %}