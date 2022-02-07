{{
    config(
        materialized='table',
        schema='staging',
        dist='conversation_id'
    )
}}

select
    s.conversation_id,
    max(s.user_id) as user_id,
    min(s.session_initiation_timestamp) as conversation_initiation_timestamp, -- might be initiated without human interaction
    min(s.session_start_timestamp) as conversation_start_timestamp, -- start with human interaction
    max(s.session_end_timestamp) as conversation_end_timestamp,
    max(s.session_nr) as sessions_count,
    DATEDIFF('second', min(s.session_initiation_timestamp)::timestamp, max(s.session_end_timestamp)::timestamp) as conversation_duration_seconds
from {{ ref('stg_sessions') }} as s
group by s.conversation_id