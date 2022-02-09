{{
    config(
        materialized='table',
        schema='staging',
        dist='sender_id'
    )
}}
-- Interleaved sort key data structure
-- https://chartio.com/blog/understanding-interleaved-sort-keys-in-amazon-redshift-part-1/

WITH
window_functions as (
    select i.*,
      first_value(story_intent ignore nulls) over
        (partition by session_id
         order by interaction_initiation_timestamp
         ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
         ) as first_story_intent,
           first_value(interaction_model_id ignore nulls) over
        (partition by session_id
         order by interaction_initiation_timestamp
         ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
         ) as first_bot_model
      FROM {{ ref('stg_interactions') }} AS i
)
,agg_to_session AS
(
  SELECT
    i.session_id, -- primary key
    i.sender_id,
    i.session_nr,
    max(i.first_bot_model) as first_bot_model,
    max(i.first_story_intent) as first_story_intent,
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
  FROM window_functions AS i
  GROUP BY i.session_id, i.sender_id, i.session_nr
  )
SELECT
  s.*,
  -- JM specific interactions
  case when interactions_count = 0 then true else false end as is_bounced,
  case when interactions_count = 0 then session_id end as bounced_session_id,
  -- this could be easy done with the users table
  case when session_nr = 0 then 'new' else 'returning' end as new_returning_session,
  case when agent_handoff_count > 0 then session_id else null end as handover_session_id
FROM agg_to_session AS s