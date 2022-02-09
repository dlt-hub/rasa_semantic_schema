{{
    config(
        materialized='incremental',
        schema='views',
        unique_key='sender_id',
        on_schema_change='fail',
        dist='sender_id',
        sort=['sender_conversation_initiation_timestamp', 'sender_conversation_start_timestamp', 'sender_conversation_end_timestamp'],
        sort_type='interleaved'
    )
}}

SELECT * FROM {{ ref('stg_senders') }}