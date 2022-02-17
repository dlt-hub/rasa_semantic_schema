{{
    config(
        materialized='table',
        schema="staging",
        dist="sender_id",
        cluster_by='sender_id'

    )
}}

with sender_user_events as
    (select distinct  sender_id,
             _load_id,
            max(u.{{ var('user_id') }}) over (partition by sender_id
                                order by _load_id
                                rows between unbounded preceding and unbounded following) as user_id
    from {{ source('events', 'event_user') }} as u

    union all
    select distinct  sender_id,
            _load_id,
            max(ss.{{ var('user_id') }}) over (partition by sender_id
                                order by _load_id
                                rows between unbounded preceding and unbounded following) as user_id
    from {{ source('events', 'event_session_started') }} as ss
),
sender_users as
    (select sender_id,
            _load_id,
            coalesce(max(user_id), sender_id) as user_id
     from sender_user_events
     group by 1,2
    )
select distinct
    s.sender_id,
    -- there should not be multiple users per sender,
    -- but the values are depedent on implementation so we force keep 1st value
    first_value(s.user_id) over (partition by s.sender_id
                                order by s._load_id
                                rows between unbounded preceding and unbounded following)  as user_id
    from sender_users as s
inner join sender_users as su_new
    on s.user_id=su_new.user_id
inner join {{ ref('load_ids') }} AS l
    ON su_new._load_id = l.load_id
