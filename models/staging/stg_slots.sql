{{
    config(schema='staging',
        materialized='table',
        dist='sender_id',
        sort=['timestamp'],
        cluster_by='sender_id'
    )
}}

with slots as (
    SELECT DISTINCT
        e._record_hash as slot_record_hash,
        e.sender_id,
        e.model_id,
        e.environment,
        e.session_id,
        e.session_nr,
        e.interaction_id,
        e.interaction_nr,
        e.timestamp,
        e.active_form,
        e.active_form_nr,
        s.name,
        s.value,
        case when s.name = 'requested_slot' then s.value else s.name end as slot_name_normalised,
        case when s.name = 'requested_slot' then 'requested_slot' else 'filled_slot' end as slot_action_normalised
    FROM {{ ref('stg_event_sequence') }} as e
    LEFT JOIN {{ source('events', 'event_slot') }} AS s ON s._record_hash = e._record_hash
    WHERE e.event in ('slot', 'active_loop')
    ),
filtered_slots as (
    SELECT * FROM slots WHERE name is NOT NULL ORDER BY timestamp
)
SELECT DISTINCT s.*,
    first_value(f.slot_record_hash) over 
        (
            partition by s.session_id, s.active_form, f.active_form_nr, s.slot_name_normalised order by f.timestamp
            rows between unbounded preceding and unbounded following
        )  as next_slot_fill_attempt_record_hash,
    first_value(
        case when f.value is not null then f.slot_record_hash else null end ignore nulls
        ) over (
            partition by s.session_id, s.active_form, f.active_form_nr, s.slot_name_normalised order by f.timestamp
            rows between unbounded preceding and unbounded following
        )  as next_slot_fill_record_hash
FROM filtered_slots AS s
LEFT JOIN filtered_slots as f --fills
    ON (
        s.slot_action_normalised = 'requested_slot' AND f.slot_action_normalised = 'filled_slot') AND
        f.sender_id = s.sender_id AND -- use dist key
        f.session_id = s.session_id AND -- must be same session
        f.active_form = s.active_form AND -- must be same form
        f.active_form_nr = s.active_form_nr AND -- must be the same form instance
        s.slot_name_normalised = f.slot_name_normalised AND
        s.timestamp <= f.timestamp
