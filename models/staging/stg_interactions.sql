{{
    config(
        materialized='table',
        schema='staging',
        dist='sender_id'
    )
}}

SELECT
  e.interaction_id, --primary key
  -- 
  e.interaction_nr,
  e.reverse_interaction_nr,
  e.sender_id,
  e.session_id,
  e.session_nr,
  e.user_id,
  min(e.timestamp) as interaction_initiation_timestamp,
  min(case when e.event = 'user' then e.timestamp else null end) as interaction_start_timestamp,
  max(e.timestamp) as interaction_end_timestamp,
  max(active_form) as interaction_active_form,
  max(e.model_id) as interaction_model_id,
  -- user id comes in session_started or user events metadata. one of those events must be present in each
  -- interaction, otherwise user id in interaction is unknown
  -- external session id is passed in the same way as user id
  max(COALESCE(u.{{ var('external_session_id') }}, ss.{{ var('external_session_id') }})) as external_session_id,
  max(si.intent_name) as story_intent,
  -- bot quality metrics
  {{ generate_interactions_count_metrics('e') }}
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
LEFT JOIN {{ ref('story_intents') }} AS si
 ON si.intent_name = u.parse_data__intent__name
GROUP BY 1,2,3,4,5,6,7
ORDER BY interaction_initiation_timestamp
