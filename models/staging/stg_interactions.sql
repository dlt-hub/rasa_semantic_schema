{{
    config(
        materialized='table',
        schema='staging',
        dist='conversation_id'
    )
}}

SELECT
  e.interaction_id, --primary key
  -- 
  e.interaction_nr,
  e.reverse_interaction_nr,
  e.sender_id AS conversation_id,
  e.session_id,
  e.session_nr,
  min(e.timestamp) as interaction_initiation_timestamp,
  min(case when e.event = 'user' then e.timestamp else null end) as interaction_start_timestamp,
  max(e.timestamp) as interaction_end_timestamp,
  max(active_form) as interaction_active_form,
  max(e.model_id) as interaction_model_id,
  -- assign user id, fallback to conversation id when user unknown
  -- user id comes in session_started or user events metadata. one of those events must be present in each
  -- interaction
  COALESCE(
    max(COALESCE(u.{{ var('user_id') }}, ss.{{ var('user_id') }})),
    conversation_id
   ) as user_id,
  -- external session id is passed in the same way as user id
  max(COALESCE(u.{{ var('external_session_id') }}, ss.{{ var('external_session_id') }})) as external_session_id,
  -- bot quality metrics
  sum(case when e.event = 'user' and value = 'out_of_scope' then 1 else 0 end) as out_of_scope_count,
  sum(case when e.event = 'user' and value = 'nlu_fallack' then 1 else 0 end) as nlu_fallbak_count,
  sum(case when e.event = 'action' and value = 'action_default_fallback' then 1 else 0 end) as default_fallback_count,
  sum(case when e.event = 'action' and value = 'action_unlikely_intent' then 1 else 0 end) as unlikely_intent_count,
  -- JM specific interactions
  max(si.intent_name) as story_intent,
  sum(case when e.event = 'action' and value IN ({{ var('actions_agent_handoff')|join(', ')}}) then 1 else 0 end) as agent_handoff_count,
  sum(case when e.event = 'user' and value IN ({{ var('intents_raise_dispute')|join(', ')}}) then 1 else 0 end) as raise_dispute_count,
  sum(case when e.event = 'user' and value IN ({{ var('intents_frustrated')|join(', ')}}) then 1 else 0 end) as react_frustrated_count,
  sum(case when e.event = 'user' and value IN ({{ var('intents_happy')|join(', ')}}) then 1 else 0 end) as react_happy_count,
  -- keys used for dimension join
  interaction_id AS interaction_slot_fk ,
  interaction_id AS interaction_user_fk,
  interaction_id AS interaction_bot_fk,
  interaction_id AS interaction_story_action_fk,
  lag(interaction_id) over (partition by e.sender_id, session_nr order by interaction_nr ) as previous_interaction_user_fk,
  lag(interaction_id) over (partition by e.sender_id, session_nr order by interaction_nr ) as previous_interaction_bot_fk,
  lag(interaction_id) over (partition by e.sender_id, session_nr order by interaction_nr ) as previous_interaction_action_fk,
  lag(interaction_id) over (partition by e.sender_id, session_nr order by interaction_nr ) as previous_interaction_slot_fk
FROM {{ ref('stg_event_sequence') }} AS e
LEFT JOIN {{ source('events', 'event_user') }} AS u
  ON e.event = 'user' AND e._record_hash = u._record_hash  and e.sender_id = u.sender_id -- use dist key
LEFT JOIN {{ source('events', 'event_session_started') }} AS ss
  ON e.event = 'session_started' AND e._record_hash = ss._record_hash  and e.sender_id = ss.sender_id -- use dist key
LEFT JOIN {{ ref('story_intents') }} AS si ON si.intent_name = u.parse_data__intent__name
GROUP BY interaction_id, interaction_nr, reverse_interaction_nr, conversation_id, session_id, session_nr--, u.{{ var('user_id') }}, u.{{ var('external_session_id') }}, ss.{{ var('user_id') }}, ss.{{ var('external_session_id') }}
ORDER BY interaction_initiation_timestamp