{{
    config(
        materialized='table',
        schema="staging",
        dist='sender_id'

    )
}}

SELECT events.*,
       senders.user_id
   FROM
    (SELECT sender_id, _record_hash, event, {{ adapter.quote('timestamp') }}, parse_data__intent__name as value, model_id, _load_id
        FROM {{ source('events', 'event_user') }} as u
    union all
      SELECT  sender_id, _record_hash, event, {{ adapter.quote('timestamp') }}, metadata__utter_action as value, model_id, _load_id
      FROM {{ source('events', 'event_bot') }} as b
    union all
      SELECT  sender_id, _record_hash, event, {{ adapter.quote('timestamp') }}, name as value, model_id, _load_id
      FROM {{ source('events', 'event_slot') }} as s
    union all
      SELECT  sender_id, _record_hash, event, {{ adapter.quote('timestamp') }}, name as value, model_id, _load_id
      FROM {{ source('events', 'event_action') }} as a
    union all
      SELECT  sender_id, _record_hash, event, {{ adapter.quote('timestamp') }}, name as value, model_id, _load_id
      FROM {{ source('events', 'event_active_loop') }} as l
    union all
      -- contains session metadata
      SELECT  sender_id, _record_hash, event, {{ adapter.quote('timestamp') }}, NULL as value, model_id, _load_id
      FROM {{ source('events', 'event_session_started') }} as ss
    ) AS events
INNER JOIN {{ ref('sender_ids') }} AS senders ON senders.sender_id = events.sender_id
