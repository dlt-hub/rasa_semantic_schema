{{
    config(
        materialized='incremental',
        schema='views',
        unique_key='session_id',
        on_schema_change='fail',
        dist='sender_id',
        sort=['session_initiation_timestamp', 'session_start_timestamp', 'session_end_timestamp'],
        sort_type='interleaved',
        cluster_by=['user_id', 'sender_id'],
        partition_by={
          "field": "session_initiation_timestamp",
          "data_type": "timestamp",
          "granularity": "day"
        }
    )
}}
-- Interleaved sort key data structure
-- https://chartio.com/blog/understanding-interleaved-sort-keys-in-amazon-redshift-part-1/

-- depends_on: {{ ref('stg_senders') }}
SELECT * FROM {{ ref('stg_sessions') }}