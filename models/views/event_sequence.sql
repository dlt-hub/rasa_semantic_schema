{{
    config(
        materialized='incremental',
        schema='views',
        unique_key='_record_hash',
        dist='sender_id',
        sort=['timestamp'],
        cluster_by=['user_id', 'sender_id', 'session_id', 'interaction_id'],
        partition_by={
          "field": "timestamp",
          "data_type": "timestamp",
          "granularity": "day"
        }
    )
}}

-- depends_on: {{ ref('stg_senders') }}
SELECT * FROM {{ ref('stg_event_sequence') }}