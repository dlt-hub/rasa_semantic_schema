{{
    config(
        materialized='incremental',
        schema='views',
        unique_key='action_record_hash',
        on_schema_change='fail',
        dist='sender_id',
        sort=['timestamp']
    )
}}

SELECT
    e._record_hash as action_record_hash, -- primary key
    --
    a.confidence,
    --
    e.model_id,
    e.timestamp,
    e.value as action_name,
    e.sender_id,
    e.session_nr,
    e.interaction_nr,
    e.interaction_id,
    e.session_id,
    e.interaction_id as story_action_interaction_sk
    --
FROM {{ ref('stg_event_sequence') }} AS e
JOIN {{ source('events', 'event_action') }} AS a
    on a._record_hash = e._record_hash and e.sender_id = a.sender_id -- use dist key
ORDER BY "timestamp"
