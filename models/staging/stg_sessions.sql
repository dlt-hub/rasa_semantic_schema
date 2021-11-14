{{
    config(
        materialized='table',
        schema='staging',
        dist='conversation_id'
    )
}}
-- Interleaved sort key data structure
-- https://chartio.com/blog/understanding-interleaved-sort-keys-in-amazon-redshift-part-1/

WITH sessions_window_functions AS
(
  SELECT
    i.session_id, -- primary key
    i.conversation_id,
    i.session_nr,
    min(i.interaction_initiation_timestamp) as session_initiation_timestamp,
    min(i.interaction_start_timestamp)  as session_start_timestamp, 
    max(i.interaction_end_timestamp) as session_end_timestamp,
    DATEDIFF('second', min(i.interaction_initiation_timestamp)::timestamp, max(i.interaction_end_timestamp)::timestamp) as session_duration_seconds,
    max(i.interaction_nr) as interactions_count,
    count(DISTINCT i.interaction_active_form) as distinct_forms_activated,
    -- one session has one user and one external session id
    max(i.user_id) as user_id,
    max(i.external_session_id) as external_session_id,
    -- bot quality metrics
    sum(i.out_of_scope_count) as out_of_scope_count,
    sum(i.nlu_fallbak_count) as nlu_fallbak_count,
    sum(i.default_fallback_count) as default_fallback_count,
    sum(i.unlikely_intent_count) as unlikely_intent_count,
    -- JM specific interactions
    -- first_value(i.story_intent) 
    --   OVER(
    --     PARTITION BY i.session_id ORDER BY i.interaction_initiation_timestamp
    --     rows between unbounded preceding and unbounded following) as first_story_intent,
    count(DISTINCT i.story_intent) as distinct_story_intent_count,
    sum(i.agent_handoff_count) as agent_handoff_count,
    sum(i.raise_dispute_count) as raise_dispute_count,
    sum(i.react_frustrated_count) as react_frustrated_count,
    sum(i.react_happy_count) as react_happy_count
    
  FROM {{ ref('stg_interactions') }} AS i
  GROUP BY i.session_id, i.conversation_id, i.session_nr
)
SELECT 
  s.*,
  -- JM specific interactions
  ( -- this thing seems to cost a lot, any better ideas?
      SELECT ii.story_intent FROM {{ ref('stg_interactions') }} AS ii
        WHERE ii.session_id = s.session_id ORDER BY ii.interaction_initiation_timestamp LIMIT 1
    ) as first_story_intent,
  case when interactions_count = 0 then true else false end as is_bounced,
  case when interactions_count = 0 then session_id end as bounced_session_id,
  -- this could be easy done with the users table
  -- case when interactions = 0 then 'new' else 'returning' end as new_returning_session, --looks wrong
  case when agent_handoff_count > 0 then session_id else null end as handover_session_id
FROM sessions_window_functions AS s
