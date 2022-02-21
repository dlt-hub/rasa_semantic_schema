-- slot with name `` must be in the same session as next event

with next_event as (
    select
        _record_hash, 
        lead(_record_hash, 1) over (partition by sender_id order by seq.timestamp) as _next_record_hash
    from {{ ref('stg_event_sequence') }} as seq
)
select s.user_id, s.sender_id, ne.event, ne.value, s.session_nr, ne.session_nr from {{ ref('stg_event_sequence') }} as s
    inner join next_event as l ON l._record_hash = s._record_hash
    inner join {{ ref('stg_event_sequence') }} as ne on l._next_record_hash = ne._record_hash
    -- inner join {{ ref('stg_slots') }} as slots on slots.slot_record_hash = s._record_hash
    where s.value = 'session_started_metadata' 
        -- TODO: actually does not work, slots.value is always null because slot has json object as value and gets unpacked
        -- and slots.value is not null 
        and (
            ne.session_nr <> s.session_nr
            -- or ne.value <> 'action_session_start'
        )
