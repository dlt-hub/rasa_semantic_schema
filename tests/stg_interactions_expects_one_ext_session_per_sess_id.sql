-- one session must have one external session id
SELECT session_id, count(distinct COALESCE(user_id, '__count_nulls__')) as extspersid FROM {{ ref('stg_interactions') }}
GROUP BY session_id
HAVING extspersid <> 1