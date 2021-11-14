-- one conversation must have one user_id (we also count nulls)
SELECT conversation_id, count(distinct COALESCE(user_id, '__count_nulls__')) as uperc FROM {{ ref('stg_interactions') }}
GROUP BY conversation_id
HAVING uperc <> 1