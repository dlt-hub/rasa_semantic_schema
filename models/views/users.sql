{{
    config(
        materialized='incremental',
        schema='views',
        unique_key='user_id',
        dist='user_id',
        on_schema_change='fail'
    )
}}

-- depends_on: {{ ref('stg_conversations') }}
SELECT
    s.user_id, -- primary key
    min(s.session_start_timestamp) OVER (PARTITION BY s.user_id) as first_seen_timestamp,
    max(s.session_end_timestamp) OVER (PARTITION BY s.user_id) as last_seen_timestamp,
    count(s.session_id) OVER (PARTITION BY s.user_id) as sessions_count,
    -- count(DISTINCT s.conversation_id) OVER (PARTITION BY s.user_id) as conversations_count,
    FIRST_VALUE(s.session_id) OVER (PARTITION BY s.user_id ORDER BY session_initiation_timestamp ASC 
        rows between unbounded preceding and unbounded following) as first_session_id,
    FIRST_VALUE(s.session_id) OVER (PARTITION BY s.user_id ORDER BY session_initiation_timestamp DESC 
        rows between unbounded preceding and unbounded following) as last_session_id,
    FIRST_VALUE(s.conversation_id) OVER (PARTITION BY s.user_id ORDER BY session_initiation_timestamp ASC 
        rows between unbounded preceding and unbounded following) as first_conversation_id,
    FIRST_VALUE(s.conversation_id) OVER (PARTITION BY s.user_id ORDER BY session_initiation_timestamp DESC 
        rows between unbounded preceding and unbounded following) as last_conversation_id

FROM {{ ref('sessions') }} AS s WHERE s.user_id IN 
    -- we must get all session for all the user_ids in the incremental load
    (SELECT DISTINCT user_id FROM {{ ref('stg_sessions') }})
