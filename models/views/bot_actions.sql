{{
    config(
        materialized='incremental',
        schema='views',
        unique_key='bot_record_hash',
        on_schema_change='fail',
        dist='sender_id',
        sort=['timestamp']
    )
}}

SELECT
    e._record_hash as bot_record_hash,
    e.model_id,
    -- we could customize text extraction if bot uses formatters, that may require joing with child tables
    b.text,
    senders.user_id,
    --
    e.timestamp,
    e.sender_id as sender_id,
    e.value as utter_action,
    e.session_nr,
    e.interaction_nr,
    e.interaction_id,
    e.session_id,
    e.interaction_id as bot_interaction_sk,
    e.interaction_id as user_interaction_fk,
    e.interaction_id as action_interaction_fk,
    e.sender_id || '/', e.session_nr || '/' || e.interaction_nr+1 as next_user_interaction_fk
FROM {{ ref('stg_event_sequence') }} as e
INNER JOIN {{ source('events', 'event_bot') }} AS b
    on b._record_hash = e._record_hash and e.sender_id = b.sender_id -- use dist key
LEFT JOIN {{ ref('sender_ids') }} AS senders
    ON senders.sender_id = e.sender_id
ORDER BY "timestamp"
