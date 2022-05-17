{% test expect_distinct_values(model,
                                column_name,
                                values,
                                quote_values=True
                                ) %}

{%- if quote_values -%}
{%-    set in_set = "\'" + values|join("\', \'") + "\'" -%}
{%- else -%}
{%-    set in_set = values|join(", ") -%}
{%- endif -%}

-- generate counts
with matching_count as (
    -- return count of distinct values on the list
    select count(distinct {{ column_name }}) as c from {{ model }}
    where {{ column_name }} IN ({{ in_set }})
    union all
    -- return count of all distinct values
    select count(distinct {{ column_name }}) as c from {{ model }}
),
validation_errors as (
    -- return row only when count does not match expected count so all distinct values are present, not less not more
    select * from matching_count where c <> {{ values|length }}
)

select *
from validation_errors

{% endtest %}