# Chat Analytics Semantic Schema

## Running DBT Package
In order to run the package, you must supply environemnt variables defining access to Redshift. The documentation is provided [here](https://github.com/scale-vector/rasa_data_ingestion_deployment/blob/master/autopoiesis/DEPLOYMENT.md#redshift-access). You can also use the [.env](.env) file as an example.
The prefix of the schemas from which packages takes and writes data must be supplied from command line.
Following example
```
env $(cat .env | grep "^[^#;]" | xargs) PG_PASSWORD=... dbt run --profiles-dir . --vars "{source_schema_prefix: carbon_bot_eks}" --fail-fast
```
1. applies environment variables from `.env` file
2. overwrites password value
3. runs the package incrementally for the `carbon_bot_eks` schema prefix

Alternatively you can apply the variables from the .env file to the shell and use `dbt run`.

### Running in Production
1. install dependencies (package uses `dbt-expectations` for testing)
```
dbt deps --profiles-dir .
```
2. update seeds
```
dbt seed --profiles-dir . --vars "{source_schema_prefix: jm_eks}"
```
3. test if raw schema (`event`) was created (or have the package fail on non existing tables)
```
dbt test --profiles-dir . --vars "{source_schema_prefix: jm_eks}" -s source:*
```
will return non 0 exit code if fails

4. run the package incrementally
5. optionally run tests

## Package customizations
Package can be customized as follows:

### External user and session ids
Package allows to use a field passed in `metadata` of `user` or `session_start` event as user identifer. The default is to use `sender_id` as such. The table `users` is built upon the `user_id` passed and such *user id* is present in `sessions` and `interactions` table.

In the same way, additional session identifier can be passed. Such session identifier may be for example used to correlate session between web/mobile app and a bot. The default external session id is `sender_id`.

The columns names for user and external session ids may be configured in `dbt_project` or by passing the variables in command line

```
dbt run --profiles-dir . --vars "{source_schema_prefix: jm_eks, user_id: metadata__use
r_id, external_session_id: metadata__mitter_id}" --fail-fast
```

### Configuring special intents and actions
Package can provide information on 

1. intents that start a story
2. intents that indicate that user is frustrated or angry
3. actions that indicate handoff to agent (and can be used to measure containment rate)
4. intents that indicate that user disputes the resolution of the scenario
5. intents that indicate that user is happy with the service

All of those can be set up via seeds or `dbt_project` variables.

## Loads lifecycle and `_loads` table
Package identifies new data by finding all load identifiers in `_loads` table in `event` schema that have only one entry with status 0.

On the successful processing new records are inserted with status = 1.

### Full Refresh
Full refresh will take all the existing distinct loads from the `_loads` table.

## Seeds

## Schemas

### Semantic schema

![dbdiagram semantic schema](docs/semantic_schema/dbdiagram_io.png)

The semantic schema contains 2 types of tables - Event tables and stateful entity tables
#### event tables:
- user messages: this table contains the user messages
- bot messages: This table contains the bot messages and actions
- slot request &fill: This table records the request and filling of slots
- story actions: Like the slot table for the setups that use stories instead of slots

#### stateful entity tables

The stateful entity tables are cumulative aggregations that calculate the state of the entity so we can use it in the context of events. For instance, we can look at a user message in the context of the conversation state and outcome (handover, conversion, etc)

- Interaction
- Session
- Conversation
- Custom user implementation: User



## Usage

The semantic schema is designed for several access patterns depending on the entity studied.
### 1. Event centric

In an event centric analysis, the event is the "fact" and the dimensions are the context of an event:
- The conversation it is part of (start, end, completion state)
- The session it is part of and its details (start, end, completion state)
- The interaction that the event is part of and what else happened during it (for instance if information was collected succesfully)
- The story (start, end, completion state)
- The event content description (intent)
- The cause and the outcome (previous dialogue message, next dialogue message)
- The position of the event in the conversation (landing, exit, scenario etc)

This access pattern is particularly helpful in answering qualitative questions such as 
- "what was the last user reply in the conversation"
- "What happened just before the user got frustrated?"
- "what the user say [perhaps in response to something]" 
- "why did the handover happen"
- "what happened before the bug occurs"

To answer these questions, we start our analysis from one of the event tables and gather context by joining via foreign keys:
- Join the event table (such as human utterance) to the stateful entity table (session, interaction, conversation)
- Join to other events tables via interaction id that is used as a foreign key. (n:n join, an interaction can have multiple events of the same type)

These joins can be done via 
- ID to the entity table (eg, interaction id)
- Interaction foreign key ("_fk" notation) to the event tables. Some foreign keys are offset to the before/after interaction such as "previous_interaction_bot_fk" which signifies that this is an interaction id meant to join to the bot actions (table) of the preceding interaction.



### 2. Stateful Abstraction centric

An interaction (or other abstraction) centric analysis supports quantitative analyses better than an event centric analysis. 

This is because the interaction is the smallest "stateful" unit of data that we can look at as having an "outcome" or "success" state.

Specifically, an interaction is the conversation segment that starts with a human utterance and ends before the start of the next one.

If the interaction is a fact, then the metrics are
- quality metrics for the interaction such as error rate, unhappy rate etc (count of interactions containing an event of a certain type)/(count of all events)
- count of interactions (how many "steps" or "interactions" or "exchanges"). We could look at totals or break them down by things like intents, or scenarios, to understand how many exchanges per scenario etc
- count (distinct) of higher aggregation entities (sessions, conversations, users)

The same logic allows for 
- session centric or conversation centric 
- in custom scenarios, user or story centric

This access pattern is particularly helpful in answering quantitative questions such as 
- Funnels that can be split by outcomes (states)
- how many interactions are in a scenario conversation
- How many conversations are in what state
- How many interactions were bounces


####glossary:
* Facts - Things that happen such as events or sales, we can sum or count them. (example: sales_value, message_id)
* Metrics - Sum, count, or a custom aggregation of facts. Example: "total sales" as sum of sales_value, "messages" as count of message_id)
* Dimensions - Descriptive attributes of a fact that can be used to break down dimensions by (source, time, context, bot version, etc) Example : Source, as in count of messages by *source*
and their dimensions as descriptive attributes in a n:1 relationship.


### Raw data schema (the source of the dbt package)


Any additions to the bot model data will immediately propagate to this schema. 

The raw data schema is a self-updating, autogenerated schema for the events designed for instant iteration, created by recursively unpacking the tracker json.

This allows creation of simple analyses without any additional effort.

To enable more complex analyses, this data is processed into a semnatic schema that rebuilds state. This semantic schema is fully customisable to your business' logic via the dbt model.
