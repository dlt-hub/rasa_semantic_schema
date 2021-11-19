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
concat(u.sender_id, '/', e.interaction_nr) as interaction_id,
concat(u.sender_id, '/', e.session_nr) as session_id,
concat(u.sender_id, '/', e.interaction_nr) as fk_interaction_id,
concat(u.sender_id, '/', e.interaction_nr +1) as fk_next_interaction_id,
FROM `chat-analytics-317513.carbon_bot_extract_dev_3.event_user` as u
left join staging.event_sequence e
    on u._record_hash = e._record_hash