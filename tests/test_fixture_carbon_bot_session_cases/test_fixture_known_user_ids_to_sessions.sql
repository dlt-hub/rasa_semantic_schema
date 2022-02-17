{%- if var("source_schema_prefix") == "test_fixture_carbon_bot_session_cases" -%}

{{
    config(tags=["test_fixture_carbon_bot_session_cases", "full", "incremental"])
}}

SELECT * FROM (

{{ test_accepted_values(
    get_where_subquery_explicit(ref('stg_event_sequence'), where="user_id = 'third_external_user'"),
    "sender_id",
    values=['e040fe0d-ad49-4388-af2a-379e1d6e24f7', '3bb78215-4a2b-475e-96a8-acf83eb037a8', '2459448537496790'])
}}

)
UNION ALL SELECT * FROM (

--- user with overlapping sessions
{{ test_accepted_values(
    get_where_subquery_explicit(ref('stg_event_sequence'), where="user_id = 'second_external_user'"),
    "session_id",
    values=[
        "2627334840657340/1",
        "2627334840657340/2",
        "2627334840657340/3",
        "2627334840657340/5",
        "2627334840657340/6",
        "16bc6379-0fc7-41ee-b1b9-b8054f59f20a/8",
        "2627334840657340/11",
        "2627334840657340/12",
        "2627334840657340/13",
        "2627334840657340/4",
        "16bc6379-0fc7-41ee-b1b9-b8054f59f20a/7",
        "16bc6379-0fc7-41ee-b1b9-b8054f59f20a/9",
        "16bc6379-0fc7-41ee-b1b9-b8054f59f20a/10",
        "2627334840657340/14",
    ])
}}
)

{%- else -%}

SELECT NULL LIMIT 0

{%- endif -%}