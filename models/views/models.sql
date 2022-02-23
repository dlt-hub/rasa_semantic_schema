{{
    config(
        materialized='table',
        schema='views',
        unique_key='model_id',
        on_schema_change='fail',
        dist='all',
        sort=['timestamp'],
        cluster_by='model_id'
    )
}}

SELECT m.*,
  -- override macro to generate other model names
  {{ generate_readable_model_name()}} as model_name_custom
from {{ source('models', 'model') }} as m
