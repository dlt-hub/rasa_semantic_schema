{{
    config(
        materialized='table',
        schema='views',
        unique_key='_record_hash',
        on_schema_change='fail',
        dist='all',
        sort=['timestamp'],
        cluster_by='model_id'
    )
}}

SELECT m.*,
-- use a simple nr as readable identifier, or create your custom names based on model id here.
'Bot Nr ' || cast(row_number() over (order by timestamp) as {{ dbt_utils.type_string()}}) as model_name_custom
from {{ source('models', 'model') }} as m
--ORDER BY {{ adapter.quote('timestamp') }}
