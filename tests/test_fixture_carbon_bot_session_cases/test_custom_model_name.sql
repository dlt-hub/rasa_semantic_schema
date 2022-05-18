{{
    config(tags=["test_fixture_carbon_bot_session_cases", "full", "incremental", "unit"])
}}

{%- if var("source_schema_prefix") == "test_fixture_carbon_bot_session_cases" -%}

select * from (

{{ test_expect_distinct_values(
    ref("models"),
    "model_name_custom",
    values=['20211207-153335_2.8.12', '20211122-132605_2.8.12', '20211119-094708_2.8.12', '20210601-085248_2.6.1', '20210528-162428_2.6.1', '20210528-105643_2.6.1'])
}}

)

{%- else -%}

select null limit 0

{%- endif -%}
