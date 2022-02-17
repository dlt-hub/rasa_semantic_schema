{{
    config(
        materialized='incremental',
        schema='views',
        unique_key='slot_record_hash',
        on_schema_change='fail',
        dist='sender_id',
        sort=['timestamp'],
        cluster_by='slots_interaction_sk',
        partition_by={
          "field": "timestamp",
          "data_type": "timestamp",
          "granularity": "day"
        }
    )
}}

SELECT
    s.slot_record_hash, -- primary key
    s.sender_id,
    s.name,
    s.value,
    s.slot_name_normalised,
    s.slot_action_normalised,
    s.timestamp,
    s.session_id,
    s.session_nr,
    s.interaction_id,
    s.interaction_nr,
    s.interaction_id as slots_interaction_sk,
    -- fill (happens in the same session)
    s.next_slot_fill_record_hash,
    f.interaction_id as fill_event_interaction_id,
    --attempted fill (happens in the same session)
    s.next_slot_fill_attempt_record_hash,
    a.interaction_id as fill_attempt_event_interaction_id
FROM {{ ref('stg_slots') }} AS s
LEFT JOIN {{ ref('stg_event_sequence') }} as f
    on s.next_slot_fill_record_hash = f._record_hash and f.sender_id = s.sender_id -- use dist key
LEFT JOIN {{ ref('stg_event_sequence') }} as a
    on s.next_slot_fill_attempt_record_hash = a._record_hash and a.sender_id = s.sender_id -- use dist key
--ORDER BY {{ adapter.quote('timestamp') }}
