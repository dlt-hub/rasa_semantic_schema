{{
    config(
        materialized='incremental',
        schema='views',
        unique_key='interaction_id',
        on_schema_change='fail',
        dist='sender_id',
        sort=['interaction_initiation_timestamp'],
        cluster_by=['user_id', 'sender_id', 'session_id', 'interaction_id'],
        partition_by={
          "field": "interaction_initiation_timestamp",
          "data_type": "timestamp",
          "granularity": "day"
        }
    )
}}

-- depends_on: {{ ref('stg_senders') }}
SELECT * FROM {{ ref('stg_interactions') }}
--ORDER BY interaction_initiation_timestamp