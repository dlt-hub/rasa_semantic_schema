{{
    config(
        materialized='table',
        schema='staging',
        dist='sender_id'
    )
}}

select
    s.sender_id,
    max(s.user_id) as user_id,
    min(s.session_initiation_timestamp) as sender_conversation_initiation_timestamp, -- might be initiated without human interaction
    min(s.session_start_timestamp) as sender_conversation_start_timestamp, -- start with human interaction
    max(s.session_end_timestamp) as sender_conversation_end_timestamp,
    max(s.session_nr) as sessions_count,
    -- only relevant if sender is a conversation rather than user
    {{ dbt_utils.datediff( 'cast(min(s.session_initiation_timestamp) as timestamp)', 'cast(max(s.session_end_timestamp) as timestamp)', 'second') }} as sender_conversation_duration_seconds
from {{ ref('stg_sessions') }} as s
group by s.sender_id