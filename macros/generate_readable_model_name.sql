{% macro generate_readable_model_name() -%}
   {{ dbt_utils.concat(['m.name', "'_'", 'm.sdk_version']) }}
{%- endmacro %}