{{
    config(
        materialized='table',
        schema='staging',
        dist='sender_id',
        cluster_by='sender_id'
    )
}}
-- Interleaved sort key data structure
-- https://chartio.com/blog/understanding-interleaved-sort-keys-in-amazon-redshift-part-1/

WITH
window_functions as (
    select i.*,
    --story
      first_value(story_intent ignore nulls) over
        (partition by session_id
         order by interaction_initiation_timestamp
         ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
         ) as first_story_intent,
         -- model
           first_value(interaction_model_id ignore nulls) over
        (partition by session_id
         order by interaction_initiation_timestamp
         ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
         ) as first_bot_model,
         -- env
           first_value(environment ignore nulls) over
        (partition by session_id
         order by interaction_initiation_timestamp
         ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
         ) as first_environment
      FROM {{ ref('stg_interactions') }} AS i
)
,agg_to_session AS
(
  SELECT
    i.session_id, -- primary key
    i.sender_id,
    i.session_nr,
    max(i.first_environment) as environment,
    max(i.first_bot_model) as first_bot_model,
    max(i.first_story_intent) as first_story_intent,
    min(i.interaction_initiation_timestamp) as session_initiation_timestamp,
    min(i.interaction_start_timestamp)  as session_start_timestamp,
    max(i.interaction_end_timestamp) as session_end_timestamp,
    {{ dbt_utils.datediff( 'cast(min(i.interaction_initiation_timestamp) as timestamp)', 'cast(max(i.interaction_end_timestamp) as timestamp)', 'second') }} as session_duration_seconds,
    max(i.interaction_nr) as interactions_count,
    count(DISTINCT i.interaction_active_form) as distinct_forms_activated,
    -- one session has one user and one external session id
    max(i.user_id) as user_id,
    max(i.external_session_id) as external_session_id,
    -- bot quality metrics
    {{ generate_sessions_count_metrics('i') }}
    count(DISTINCT i.story_intent) as distinct_story_intent_count
  FROM window_functions AS i
  GROUP BY i.session_id, i.sender_id, i.session_nr
  )
SELECT
  s.*,
  -- business specific interactions
  case when interactions_count = 0 then true else false end as is_bounced,
  case when interactions_count = 0 then session_id end as bounced_session_id,
  -- is aligned with the count produced by the count metrics macro, configurable in dbt_project yml.
  {{ generate_event_sesssion_ids_from_counts('s') }}
  -- this tags the session state at the time and does not rely on current user state
  case when session_nr = 1 then 'new' else 'returning' end as new_returning_session
FROM agg_to_session AS s