{% macro generate_readable_model_name() -%}
   {{ concat(['m.name', "'_'", 'm.sdk_version']) }}
{%- endmacro %}