-- one conversation must have one user_id (we also count nulls)
SELECT sender_id, count(distinct COALESCE(user_id, '__count_nulls__')) as uperc FROM {{ ref('stg_interactions') }}
GROUP BY sender_id
HAVING uperc <> 1