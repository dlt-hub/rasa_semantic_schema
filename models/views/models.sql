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
  -- # model_name_custom is configurable from dbt-project.yaml variables
  {{ bot_model_id_name_map()}}
from {{ source('models', 'model') }} as m
--ORDER BY {{ adapter.quote('timestamp') }}
