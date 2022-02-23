{% macro bot_model_id_name_map() -%}
    case
  {% for k, v in var('bot_model_id_names').items()  -%}
         when model_id= '{{k}}'
            then '{{v}}'
  {% endfor %}
     else name end as model_name_custom
{%- endmacro %}