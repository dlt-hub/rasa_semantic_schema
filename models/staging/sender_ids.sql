{{
    config(
        materialized='table',
        schema="staging",
        dist="sender_id"

    )
}}

SELECT DISTINCT sender_id FROM {{ source('events', 'event') }} AS e
JOIN {{ ref('load_ids') }} AS l ON e._load_id = l.load_id
