{{
    config(
        materialized='incremental',
        schema='views',
        unique_key='interaction_id',
        on_schema_change='fail',
        dist='conversation_id',
        sort=['interaction_initiation_timestamp']
    )
}}

-- depends_on: {{ ref('stg_conversations') }}
SELECT * FROM {{ ref('stg_interactions') }} ORDER BY interaction_initiation_timestamp