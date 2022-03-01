{% macro has_active_loop() %}

    {# for bot models without forms, active loop table does not exist #}
    {%- set source_relation = adapter.get_relation(
        database=source('events', 'event_active_loop').database,
        schema=source('events', 'event_active_loop').schema,
        identifier=source('events', 'event_active_loop').name) -%}

    {{ return(source_relation is not none) }}
  
{% endmacro %}