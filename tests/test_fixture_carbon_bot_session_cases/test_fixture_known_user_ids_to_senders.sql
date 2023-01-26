{{
    config(tags=["test_fixture_carbon_bot_session_cases", "full", "incremental", "unit"])
}}

{%- if var("source_dataset_name") == "test_fixture_carbon_bot_session_cases" -%}

SELECT * FROM (

{{ test_expect_distinct_values(
    get_where_subquery_explicit(ref('stg_event_sequence'), where="user_id = 'third_external_user'"),
    "sender_id",
    values=['e040fe0d-ad49-4388-af2a-379e1d6e24f7', '3bb78215-4a2b-475e-96a8-acf83eb037a8', '2459448537496790'])
}}

)
UNION ALL SELECT * FROM (

{{ test_expect_distinct_values(
    get_where_subquery_explicit(ref('stg_event_sequence'), where="user_id = 'second_external_user'"),
    "sender_id",
    values=['16bc6379-0fc7-41ee-b1b9-b8054f59f20a', '2627334840657340'])
}}
)

{%- else -%}

SELECT NULL LIMIT 0

{%- endif -%}