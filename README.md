# Rasa Semantic Schema
This DBT package runs on top of data sets created by Rasa Ingestion Pipeline. This pipeline continously loads the tracker store data into two **raw schemas** that represent events in tracker store in relational form.

| schema                | description                                  |
| --------------------- | -------------------------------------------- |
| {schema_prefix}_event | Schema with raw tracker events               |
| {schema_prefix}_model | Schema with stories, rules and model domains |
|                       |                                              |

[See here for **raw schema** details](README_RAW_SCHEMA.md)


DBT package will create two more **semantic schemas** by transforming the tracker store events in **raw schema** into meaningful and stateful entities like users, sessions, interactions and more.

| schema                  | description                                               |
| ----------------------- | --------------------------------------------------------- |
| {schema_prefix}_staging | Various intermediate tables that optimize schema building |
| {schema_prefix}_views   | Final semantic schema tables used for reporting           |
|                         |                                                           |

[See here for **semantic schema** details](README_SCHEMA.md)

All the schemas that correspond to a single tracker store share a **schema prefix** that should be supplied both to the pipeline and this package.

## Quickstart Guide for DBT Runner
[DBT Package Runner](https://github.com/scale-vector/rasa_data_ingestion_deployment/blob/master/autopoiesis/DEPLOYMENT.md#semantic-schema-dbt-package) is one of the component of the Rasa Ingestion Pipeline. It will automate the execution of this package after it is properly customized.

In order to customize the package you should do the following:

1. Fork or clone the package so you can work on your own copy. Forking is the preferred method.
2. Cutomize the copy of the package if necessary. Several customizations are accessible via configuration in `dbt_project.yml` file.
3. Push your changes to the repository and confgure access to it as described [here]()
4. The DBT Runner will use the same configuration settings and secrets that are used for other components. No further configuration is necessary for this method

We advice you to customize your package if
- you send external user ids in the `metadata` field of the user message
- you send external session id in the above metadata
- you want to track handovers and you have a special action(s) or intent(s) in your model that you want to measure in your reports
- you have any other intent or action that you want to measure ie. if you have intents that indicate that user is frustrated, you can easily configure the package to start measuring them
- your bot has multiple skills and you need to measure them separately in your reports.

## Package customizations

### External user and session ids
Package allows to use a field passed in `metadata` of `user` or `session_start` event as an user identifer. The default is to use `sender_id` as such. The table `users` is built upon the `user_id` passed and such *user id* is present in `sessions` and `interactions` table.

In the same way, additional session identifier can be passed. Such session identifier may be for example used to correlate session between web/mobile app and a bot. The default external session id is `sender_id`.

The columns names for user and external session ids may be configured in `dbt_project` or by passing the variables in command line

```
dbt run --profiles-dir . --vars "{source_schema_prefix: findemo_eks, user_id: metadata__use
r_id, external_session_id: metadata__mitter_id}" --fail-fast
```

### Configuring metrics on actions and intents counts
Package allows to define actions and intents that are counted in interaction and session level and may be used as a metric. Example

1. intents and actions that indicate low confidence or fallbacks
2. intents that indicate that user is frustrated or angry ( and can measure frustration rate )
3. actions that indicate handoff to agent (and can be used to measure containment/handover rate)
4. intents that indicate that user disputes the actions of the bot
5. intents that indicate that user satisfaction with the service

All of those can be set up via seeds or `dbt_project` variables.

### First story intents
Package facilitates surfacing intents that open particular scenario, story or a skill. The list of such intents is configured in seeds and available in interaction and session level as `first_intent` field. The list of such intents can be configured via Seeds

### Seeds
Currently you can define intents that start particular story in the seeds

## Running DBT Package Manually
Like any other package, this one can be also run from the command line. This is the preferred method when you need to customize it deeper ie. by changing the transformations in `sql` files. 
### Pick Up the Warehouse and DBT Profile
We support both Redshift and BigQuery in the same package. In order to use any of them, you need to provide access credentials to the profile that you choose. Each profile requres set of environment variables to be present and have corresponding `.example.env` file that you can use to define env variables.

1. `rasa_semantic_schema_redshift` and `.redshift.example.env` profile to connect to Redshift
2. `rasa_semantic_schema_bigquery` and `.bigquery.example.env` profile to connect to BigQuery with a set of environment variables
3. `rasa_semantic_schema_bigquery_service_file` and `.bigquery_file.example.env` profile to connect to BigQuery with a service account credentials file

To use any of the profiles
1. Enable the profile in `dbt_project.yml` (or pass the profile explicitely to the `dbt` command)
2. Copy the relevant `.example.env` into `.env` and fill the environment variables (copying will prevent you from pushing your credentials to repository)
3. Export the credentials into shell via `set -a && source .env && set +a`

The documentation is provided [here](https://github.com/scale-vector/rasa_data_ingestion_deployment/blob/master/autopoiesis/DEPLOYMENT.md#redshift-access).

### Specify the Schema Prefix
The prefix to the schema is passed in `source_schema_prefix` variable to each dbt command.

### Run The Package

1. install dependencies
```
dbt deps --profiles-dir .
```
2. update seeds
```
dbt seed --profiles-dir . --vars "{source_schema_prefix: findemo_eks}"
```

3. run the package
```
dbt run --profiles-dir . --vars "{source_schema_prefix: findemo_eks}" --fail-fast
```

### Easy Experimentation with Destination Schema Prefix
By default destination (`staging` and `views`) schemas will use the same schema prefix as **raw schemas** (`event` and `model`). Alternative destination schema prefix can be specified with `dest_schema_prefix` variable. This allows to have several semantic schemas created from single raw schema for example to test different settings, run automated tests or exepriment with model transformations.

Currently only **full refresh** runs are supported when destination schema prefix is different.


```
dbt run --profiles-dir . --vars "{source_schema_prefix: findemo_eks, dest_schema_prefix: findemo_eks_experiments}" --fail-fast --full-refresh
```

### Running in Production
1. install dependencies (package uses `dbt-expectations` for testing)
```
dbt deps --profiles-dir .
```
2. update seeds
```
dbt seed --profiles-dir . --vars "{source_schema_prefix: findemo_eks}"
```
3. test if raw schema (`event`) was created (or have the package fail on non existing tables)
```
dbt test --profiles-dir . --vars "{source_schema_prefix: findemo_eks}" -s tag:prerequisities
```
will return non 0 exit code if fails

4. run the package incrementally
5. optionally run tests

## Loads lifecycle and `_loads` table
Package identifies new data by finding all load identifiers in `_loads` table in `event` schema that have only one entry with status 0.

On the successful processing new records are inserted with status = 1.

### Full Refresh
Full refresh will take all the existing distinct loads from the `_loads` table.
[dbt docs](https://docs.getdbt.com/docs/building-a-dbt-project/building-models/configuring-incremental-models#what-if-the-columns-of-my-incremental-model-change)
```
dbt run --full-refresh --profiles-dir . --vars "{source_schema_prefix: findemo_eks}" --fail-fast
```