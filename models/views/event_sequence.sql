{{
    config(
        materialized='incremental',
        schema='views',
        unique_key='_record_hash',
        dist='sender_id',
        sort=['timestamp']
    )
}}

-- depends_on: {{ ref('stg_senders') }}
SELECT * FROM {{ ref('stg_event_sequence') }}