{{
    config(tags=["test_fixture_carbon_bot_session_cases", "full", "incremental", "unit"])
}}

{%- if var("source_dataset_name") == "test_fixture_carbon_bot_session_cases" -%}

SELECT * FROM (
{{ test_expect_distinct_values(
    get_where_subquery_explicit(ref('sessions'), where="environment != 'production'"),
    "session_id",
    values=['3d9a4658-a8fd-4e0a-976f-02b8f8abc52b/1', '3d9a4658-a8fd-4e0a-976f-02b8f8abc52b/2', '3d9a4658-a8fd-4e0a-976f-02b8f8abc52b/3', '3d9a4658-a8fd-4e0a-976f-02b8f8abc52b/4'])
}}
)
UNION ALL SELECT * FROM (
{{ test_expect_distinct_values(
    get_where_subquery_explicit(ref('sessions'), where="environment = 'development'"),
    "session_id",
    values=['3d9a4658-a8fd-4e0a-976f-02b8f8abc52b/1', '3d9a4658-a8fd-4e0a-976f-02b8f8abc52b/2', '3d9a4658-a8fd-4e0a-976f-02b8f8abc52b/3', '3d9a4658-a8fd-4e0a-976f-02b8f8abc52b/4'])
}}
)
UNION ALL SELECT * FROM (
{{ test_expect_distinct_values(
    ref('event_sequence'),
    "environment",
    values=['production', 'development', 'test'])
}}
)
UNION ALL SELECT * FROM (
{{ test_expect_distinct_values(
    ref('interactions'),
    "environment",
    values=['production', 'development', 'test'])
}}
)
-- fixture is made so only this interaction has test env for user message
UNION ALL SELECT * FROM (
{{ test_expect_distinct_values(
    get_where_subquery_explicit(ref('interactions'), where="environment = 'test'"),
    "interaction_id",
    values=['third_external_user/3/9'])
}}
)
UNION ALL SELECT * FROM (
{{ test_expect_distinct_values(
    ref('user_messages'),
    "environment",
    values=['production', 'development', 'test'])
}}
)

{%- else -%}

SELECT NULL LIMIT 0

{%- endif -%}