{{
    config(tags=["test_fixture_jm", "full", "incremental", "unit"])
}}

{%- if var("source_dataset_name") == "test_fixture_jm" -%}

SELECT * FROM (

{{ test_expect_distinct_values(
    get_where_subquery_explicit(ref('stg_interactions')),
    "story_intent",
    values=['request_limit_change', 'enquire_transaction_failure', 'request_transaction_refund', 'view_bill_details', 'view_transactions', 'view_user_details'])
}}

)
UNION ALL SELECT * FROM (

{{ test_expect_distinct_values(
    get_where_subquery_explicit(ref('stg_sessions')),
    "first_story_intent",
    values=['request_limit_change', 'enquire_transaction_failure', 'request_transaction_refund', 'view_bill_details', 'view_transactions', 'view_user_details'])
}}
)

{%- else -%}

SELECT NULL LIMIT 0

{%- endif -%}