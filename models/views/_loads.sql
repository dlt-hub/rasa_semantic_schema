-- never do a full refresh or you drop the original loads info
{{
    config(
        materialized='incremental',
        schema="event",
        full_refresh = false
    )
}}
-- depends_on: {{ ref('actions') }}
-- depends_on: {{ ref('bot_actions') }}
-- depends_on: {{ ref('slots') }}
-- depends_on: {{ ref('users') }}
-- depends_on: {{ ref('user_messages') }}
select load_id, 1 as status, {{ current_timestamp() }} as inserted_at from {{ ref('load_ids') }}
    WHERE load_id NOT IN (
        SELECT load_id FROM {{ source('events', '_loads') }} WHERE status = 1)
