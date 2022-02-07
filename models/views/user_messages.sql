{{
    config(
        materialized='incremental',
        schema='views',
        unique_key='user_message_record_hash',
        on_schema_change='fail',
        dist='conversation_id',
        sort=['timestamp']
    )
}}

SELECT
senders.user_id,
u.sender_id as conversation_id,
u._record_hash as user_message_record_hash,
u.message_id,
u.timestamp,
u.text,
u.parse_data__intent__name as intent_name,
u.parse_data__intent__confidence as intent_confidence,
u.input_channel,
e.session_nr,
e.interaction_nr,
e.interaction_id as interaction_id,
e.interaction_id as user_interaction_sk,
e.interaction_id as bot_interaction_fk,
e.interaction_id as slot_interaction_fk,
e.interaction_id as action_interaction_fk,
e.sender_id || '/' || e.session_nr || '/' || (e.interaction_nr -1) as previous_bot_interaction_fk
from {{ ref('stg_event_sequence') }} as e
INNER JOIN {{ source('events', 'event_user') }} AS u
    on u._record_hash = e._record_hash and e.sender_id = u.sender_id -- use dist key
LEFT JOIN {{ ref('sender_ids') }} AS senders
    ON senders.sender_id = e.sender_id
ORDER BY "timestamp"