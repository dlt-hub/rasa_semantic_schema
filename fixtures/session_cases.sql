-- this set of scripts will create several session cases out of carbon bot data
-- following cases will be mocked up or exist in the dataset and should be tested
-- 1. sender_id with NULL user_id and many sessions
-- 2. user_id with many sender_ids having sessions at the same time (with intertwined messages)
-- 3. user_id with many sender_ids coming from different loads
-- 4. user_id with single sender_id from single load

-- Redshift / Postgres
BEGIN TRANSACTION;
-- add user metadata columns
ALTER TABLE test_fixture_carbon_bot_session_cases_event.event_user ADD COLUMN metadata__user_id VARCHAR(MAX);
ALTER TABLE test_fixture_carbon_bot_session_cases_event.event_session_started ADD COLUMN metadata__user_id VARCHAR(MAX);

COMMIT TRANSACTION;

-- BigQuery
ALTER TABLE test_fixture_carbon_bot_session_cases_event.event_user ADD COLUMN metadata__user_id STRING;
ALTER TABLE test_fixture_carbon_bot_session_cases_event.event_session_started ADD COLUMN metadata__user_id STRING;

-- Any 

BEGIN TRANSACTION;

UPDATE test_fixture_carbon_bot_session_cases_event.event_user SET
    metadata__user_id = NULL
WHERE 1 = 1;

-- create a user that has overlapping sessions with several intertwined messaged
-- the sessions in the IN list have different senders and overlap
UPDATE test_fixture_carbon_bot_session_cases_event.event_user SET
    metadata__user_id = 'second_external_user'
WHERE sender_id IN ('e040fe0d-ad49-4388-af2a-379e1d6e24f7', '16bc6379-0fc7-41ee-b1b9-b8054f59f20a');

-- create user id that combines several senders coming from differen load_ids
UPDATE test_fixture_carbon_bot_session_cases_event.event_user SET
    metadata__user_id = 'third_external_user'
WHERE sender_id IN ('e040fe0d-ad49-4388-af2a-379e1d6e24f7', '3bb78215-4a2b-475e-96a8-acf83eb037a8', '2459448537496790');

UPDATE test_fixture_carbon_bot_session_cases_event.event_user SET
    metadata__user_id = 'fourth_external_user'
WHERE sender_id IN ('95cbaab0f8cb4cb59a3393e7fc61cafe', '4860519560646862');

-- add one more sender_id and load_id to the "intertwined session" case
UPDATE test_fixture_carbon_bot_session_cases_event.event_user SET
    metadata__user_id = 'second_external_user'
WHERE sender_id IN ('2627334840657340');

-- one user one sender id
UPDATE test_fixture_carbon_bot_session_cases_event.event_user SET
    metadata__user_id = 'fifth_external_user'
WHERE sender_id IN ('2485257761521706');

-- set environment to development for one session
UPDATE test_fixture_carbon_bot_session_cases_event.event_user SET
    environment = 'development'
WHERE sender_id IN ('3d9a4658-a8fd-4e0a-976f-02b8f8abc52b');
UPDATE test_fixture_carbon_bot_session_cases_event.event_bot SET
    environment = 'development'
WHERE sender_id IN ('3d9a4658-a8fd-4e0a-976f-02b8f8abc52b');
UPDATE test_fixture_carbon_bot_session_cases_event.event_slot SET
    environment = 'development'
WHERE sender_id IN ('3d9a4658-a8fd-4e0a-976f-02b8f8abc52b');
UPDATE test_fixture_carbon_bot_session_cases_event.event_action SET
    environment = 'development'
WHERE sender_id IN ('3d9a4658-a8fd-4e0a-976f-02b8f8abc52b');
UPDATE test_fixture_carbon_bot_session_cases_event.event_active_loop SET
    environment = 'development'
WHERE sender_id IN ('3d9a4658-a8fd-4e0a-976f-02b8f8abc52b');
UPDATE test_fixture_carbon_bot_session_cases_event.event_session_started SET
    environment = 'development'
WHERE sender_id IN ('3d9a4658-a8fd-4e0a-976f-02b8f8abc52b');

-- set environment to test for last user event in the session to test unlikely case with changing env during session
UPDATE test_fixture_carbon_bot_session_cases_event.event SET
    environment = 'test'
WHERE _record_hash = '93bf435209febf19591258664d33d64f';
UPDATE test_fixture_carbon_bot_session_cases_event.event_user SET
    environment = 'test'
WHERE _record_hash = '93bf435209febf19591258664d33d64f';

COMMIT TRANSACTION;


-- VERIFY counts of senders and load ids per user
SELECT metadata__user_id, count(DISTINCT sender_id), count(DISTINCT _load_id) FROM test_fixture_carbon_bot_session_cases_event.event_user
GROUP BY metadata__user_id



-- APPENDIX: a few queries that were used to check candidate sessions for mock

-- find overlapping session with more than 10 interactions
SELECT sess.session_id, sess2.session_id, sess.session_initiation_timestamp, sess.session_end_timestamp, sess2.session_initiation_timestamp, sess2.session_end_timestamp FROM test_fixture_carbon_bot_session_cases_views.sessions AS sess
    JOIN test_fixture_carbon_bot_session_cases_views.sessions AS sess2
        ON sess.session_initiation_timestamp < sess2.session_initiation_timestamp AND
            sess.session_end_timestamp > sess2.session_initiation_timestamp
WHERE sess.interactions_count > 10 AND sess2.interactions_count > 10 AND sess.session_nr > 1
ORDER BY sess.session_initiation_timestamp DESC

-- check overlap
SELECT sender_id, text, timestamp FROM test_fixture_carbon_bot_session_cases_event.event_user
WHERE sender_id IN ('16bc6379-0fc7-41ee-b1b9-b8054f59f20a', 'e040fe0d-ad49-4388-af2a-379e1d6e24f7')
ORDER BY timestamp

-- find a few long sessions with different load ids to place them in a single user
SELECT sess.session_id, sess.interactions_count, sess.session_initiation_timestamp
    ,( SELECT MAX(_load_id) FROM  test_fixture_carbon_bot_session_cases_event.event_user WHERE sender_id = sess.conversation_id) as load_id
    FROM test_fixture_carbon_bot_session_cases_views.sessions AS sess
WHERE sess.session_nr > 3 AND load_id = '1644268917.625009'
ORDER BY sess.interactions_count DESC