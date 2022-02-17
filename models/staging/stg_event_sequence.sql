{{
    config(
        materialized='table',
        schema="staging",
        dist='sender_id',
        sort=['timestamp'],
        cluster_by='sender_id'
    )
}}

WITH events AS
  (
    SELECT * FROM {{ ref('events') }}
  ),
prev_actions as
  (select
    *,
    lag({{ adapter.quote('timestamp') }}) over (partition by sender_id order by {{ adapter.quote('timestamp') }}) as previous_ts,
    lead(event) over (partition by sender_id order by {{ adapter.quote('timestamp') }}) as next_event,
    lead(value) over (partition by sender_id order by {{ adapter.quote('timestamp') }}) as next_value,
    lag(event) over (partition by sender_id order by {{ adapter.quote('timestamp') }}) as previous_event,
    lag(value) over (partition by sender_id order by {{ adapter.quote('timestamp') }}) as previous_value
  from events
  ),
sessionify as
  (select
    *,
    -- minimum session nr is 1 (for events that come before action_session_start ie. metadata slot)
    GREATEST(
      0 + sum(
        case when
          (
            -- break session when gap > N minutes for backward compatibility
            {{ dbt_utils.datediff( 'cast(prev_actions.previous_ts as timestamp)', 'cast(prev_actions.timestamp as timestamp)', 'minute') }} > {{ var('compat_old_session_gap_minutes') }}
            or (
            --start from session start event, but if there is a session_started_metadata before it, start from there.
                ((event='action' and value IN ('action_session_start', 'action_restart')) and not (previous_event = 'slot' and previous_value= 'session_started_metadata'))
                 OR
                ((event = 'slot' and value = 'session_started_metadata') and (next_event='action' and next_value IN ('action_session_start', 'action_restart')))
             )
          )
          then 1 else 0 end
        )
        over (partition by sender_id order by {{ adapter.quote('timestamp') }} rows between unbounded preceding and current row),
      cast(1 as bigint) ) as sender_session_nr
    from prev_actions
  ),
turnify as
  (select
    *,
    sum(case when event = 'user' then 1 else 0 end)
      over (
        partition by sender_id, sender_session_nr order by {{ adapter.quote('timestamp') }}rows between unbounded preceding and current row
      ) as interaction_nr,
    -- previous actor in the same session
    --lag(event) over (partition by sender_id order by {{ adapter.quote('timestamp') }}) as previous_actor,
    -- active form in session
    NULLIF(last_value(case when event ='active_loop' then coalesce(value, '---unset') else null end ignore nulls)
      over (partition by sender_id, sender_session_nr order by {{ adapter.quote('timestamp') }} rows between unbounded preceding and current row),
      '---unset') as active_form,
    -- active form numer in session
    sum(
        case when event = 'active_loop' and value IS NOT NULL then 1 else 0 END
    ) OVER (PARTITION BY sender_id, sender_session_nr ORDER BY timestamp rows between unbounded preceding and current row) as active_form_nr,
    --  todo: slot fill step - could tag the slot fill that is in progress
    -- first sender session time - used for sorting sessions within the user entity
     min({{ adapter.quote('timestamp') }}) over ( partition by sender_id, sender_session_nr) as sender_session_start
    from sessionify
  ),
session_numbers as (
    select
      *,
      --user session nr - we take the sender sessions and rank them by start time
      dense_rank() over (partition by user_id order by sender_session_start, sender_session_nr) as session_nr
    from turnify
)
select
    _record_hash,
    sender_id,
    user_id,
    interaction_nr,
    event,
    value,
    model_id,
    `timestamp`,
    active_form,
    active_form_nr,
    session_nr,
    sender_session_nr,
    max(interaction_nr) over (partition by sender_id, sender_session_nr) - interaction_nr as reverse_interaction_nr,
    user_id || '/' || session_nr || '/' || interaction_nr as interaction_id,
    user_id || '/' || session_nr as session_id
from session_numbers
--order by `timestamp` asc