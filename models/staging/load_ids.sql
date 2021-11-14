{{
    config(
        materialized='table',
        schema="staging"

    )
}}

{% if should_full_refresh() %}
    -- take all loads when full refresh
    SELECT load_id FROM {{ source('events', '_loads') }}
    WHERE status = 0
{% else %}
    -- take only loads with status = 0 and no other records
    SELECT load_id FROM {{ source('events', '_loads') }}
    GROUP BY 1
    HAVING SUM(status) = 0
{% endif %}