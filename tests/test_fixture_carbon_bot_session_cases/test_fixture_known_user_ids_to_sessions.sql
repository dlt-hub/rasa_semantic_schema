{{
    config(tags=["test_fixture_carbon_bot_session_cases", "full", "incremental", "unit"])
}}

{%- if var("source_schema_prefix") == "test_fixture_carbon_bot_session_cases" -%}

SELECT * FROM (

--- user with overlapping sessions
{{ test_expect_distinct_values(
    get_where_subquery_explicit(ref('stg_event_sequence'), where="user_id = 'second_external_user'"),
    "session_id",
    values=[
        "second_external_user/1",
        "second_external_user/2",
        "second_external_user/3",
        "second_external_user/4",
        "second_external_user/5"
    ])
}}

)
UNION ALL SELECT * FROM (

--- user with overlapping sessions - verify interaction ids

{%- set interactions = [] -%}
{%- for i_nr in range(20) -%}
{%- set tmp = interactions.append("second_external_user/2/" + i_nr|string) -%}
{%- endfor -%}

{{ test_expect_distinct_values(
    get_where_subquery_explicit(ref('stg_event_sequence'), where="user_id = 'second_external_user' and session_nr = 2"),
    "interaction_id",
    values=interactions
    )
}}

)

{%- else -%}

SELECT NULL LIMIT 0

{%- endif -%}
