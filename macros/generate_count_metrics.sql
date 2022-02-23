{% macro generate_interactions_count_metrics(event_table) -%}
  {%- for metric in var('count_metrics')  -%}
    {%- for metric_name, element_list in metric.items() -%}
        {%- if metric_name.startswith('action') -%}
          sum(case when {{event_table}}.event = 'action' and value IN ({{ "\'" + element_list|join("\', \'") + "\'" }}) then 1 else 0 end) as {{ metric_name }}_count,
        {%- elif metric_name.startswith('intent') -%}
          sum(case when {{event_table}}.event = 'user' and value IN ({{ "\'" + element_list|join("\', \'") + "\'" }}) then 1 else 0 end) as {{ metric_name }}_count,
        {%- else -%}
        {%- endif -%}
    {% endfor %}
  {% endfor %}
{%- endmacro %}


{% macro generate_sessions_count_metrics(interactions_table) -%}
  {%- for metric in var('count_metrics')  -%}
    {%- for metric_name, element_list in metric.items() -%}
        sum({{ interactions_table }}.{{ metric_name }}_count) as {{ metric_name }}_count,
    {% endfor %}
  {% endfor %}
{%- endmacro %}


{% macro generate_event_sesssion_ids_from_counts(counts_table) -%}
  {%- for metric in var('count_metrics')  -%}
    {%- for metric_name, element_list in metric.items() -%}
        case when {{counts_table}}.{{ metric_name }}_count > 0 then session_id else null end as {{ metric_name }}_session_id,
    {% endfor %}
  {% endfor %}
{%- endmacro %}