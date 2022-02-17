{% test expect_column_distinct_partitioned_values_to_contain_set(model,
                                                            column_name,
                                                            value_set,
                                                            partition_column,
                                                            quote_values=True
                                                            ) %}

{%- if quote_values -%}
{%-    set in_set = "\'" + value_set|join("\', \'") + "\'" -%}
{%- else -%}
{%-    set in_set = value_set|join(", ") -%}
{%- endif -%}

with all_partitions as (

    select distinct
        {{ partition_column }} as partition_column
    from {{ model }}

),
all_partition_with_values as (
    
    select distinct
        {{ partition_column }} as partition_column
    from {{ model }}
    where {{ column_name }} IN ({{ in_set }})

),
validation_errors as (
    -- find all partitioned values that do not have value in set
    select distinct
        all_values.partition_column
    from
        all_partitions as all_values
        left join all_partition_with_values as w_values on all_values.partition_column = w_values.partition_column
    where w_values.partition_column is null
    

)

select *
from validation_errors

{% endtest %}