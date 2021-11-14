{{
    config(
        materialized='incremental',
        schema='views',
        unique_key='conversation_id',
        on_schema_change='fail',
        dist='conversation_id',
        sort=['conversation_initiation_timestamp', 'conversation_start_timestamp', 'conversation_end_timestamp'],
        sort_type='interleaved'
    )
}}

SELECT * FROM {{ ref('stg_conversations') }}