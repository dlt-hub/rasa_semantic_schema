{{
    config(
        materialized='table',
        schema="staging",
        dist='sender_id',
        sort=['timestamp']
    )
}}

WITH events AS
  (
    SELECT * FROM {{ ref('events') }}
  ),
prev_actions as
  (select
    *,
    lag("timestamp") over (partition by sender_id order by "timestamp") as previous_ts
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
            DATEDIFF('min', prev_actions.previous_ts::timestamp, prev_actions.timestamp::timestamp) > {{ var('compat_old_session_gap_minutes') }} or
            (event='action' and value IN ('action_session_start', 'action_restart'))
          )
          then 1 else 0 end
        )
        over (partition by sender_id order by "timestamp" rows between unbounded preceding and current row),
      1::bigint) as session_nr
    from prev_actions
  ),
turnify as
  (select
    *,
    sum(case when event = 'user' then 1 else 0 end)
      over (
        partition by sender_id, session_nr order by "timestamp" rows between unbounded preceding and current row
      ) as interaction_nr,
    -- previous actor in the same session
    lag(event) over (partition by sender_id order by "timestamp") as previous_actor,
    -- active form in session
    NULLIF(last_value(case when event ='active_loop' then coalesce(value, '---unset') else null end ignore nulls)
      over (partition by sender_id, session_nr order by "timestamp" rows between unbounded preceding and current row),
      '---unset') as active_form,
    -- active form numer in session
    sum(
        case when event = 'active_loop' and value IS NOT NULL then 1 else 0 END
    ) OVER (PARTITION BY sender_id, session_nr ORDER BY timestamp rows between unbounded preceding and current row) as active_form_nr
    --  todo: slot fill step - could tag the slot fill that is in progress
    from sessionify
  )
select *,
 max(interaction_nr) over (partition by sender_id) - interaction_nr as reverse_interaction_nr,
 (sender_id ||  '/' ||  session_nr ||  '/'||  interaction_nr) as interaction_id,
 (sender_id ||  '/' ||  session_nr ) as session_id
from turnify
order by timestamp asc
