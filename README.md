# Rasa Semantic Schema DBT Package
**Rasa Semantic Schema Package** transforms the tracker store events into relational schema suitable for reporting via, for example, `users`, `sessions` or `interactions` tables. It runs on top of data sets (so called *sources*) created by Rasa Ingestion Pipeline. This pipeline continuously loads the tracker store data into two **source schemas** that represent event stream from RASA SDK tracker store in relational form.

| schema                | description                                  |
| --------------------- | -------------------------------------------- |
| {schema_prefix}_event | Schema with raw tracker events               |
| {schema_prefix}_model | Schema with stories, rules and model domains |
|                       |                                              |

[See here for **source schema** details](README_SOURCE_SCHEMA.md)


DBT package will create two more **semantic schemas** by transforming the tracker store events in **source schemas** into meaningful and stateful entities like users, sessions, interactions and more.

| schema                  | description                                               |
| ----------------------- | --------------------------------------------------------- |
| {schema_prefix}_staging | Various intermediate tables that optimize schema building |
| {schema_prefix}_views   | Final semantic schema tables used for reporting           |
|                         |                                                           |

[See here for **semantic schema** details](README_SCHEMA.md)

All the schemas that correspond to a single tracker store share a **schema prefix** that should be supplied both to the pipeline and this package.

## How to Use This Package
We recommend that you add this package as a dependence to your own DBT package. We provide a quick start template [here](https://github.com/scale-vector/rasa_semantic_schema_customization) if you do not have experience with DBT.

## Package customizations
### When to Customize the Package
We advice you to customize your package if
- you send external user ids in the `metadata` field of the user message
- you send external session id in the above metadata
- you want to track handovers and you have a special action(s) or intent(s) in your model that you want to measure in your reports
- you have any other intent or action that you want to measure ie. if you have intents that indicate that user is frustrated, you can easily configure the package to start measuring them
- your bot has multiple skills and you need to measure them separately in your reports.

### External user and session ids
Package allows to use a field passed in `metadata` of `user` or `session_start` event as an user identifier. The default is to use `sender_id` as such. The table `users` is built upon the `user_id` passed and such *user id* is present in `sessions` and `interactions` table.

In the same way, additional session identifier can be passed. Such session identifier may be for example used to correlate session between web/mobile app and a bot. The default external session id is again `sender_id`.

The columns names for user and external session ids may be configured in `dbt_project` or by passing the variables in command line

```
dbt run --profiles-dir . --vars "{source_schema_prefix: findemo_eks, user_id: metadata__user_id, external_session_id: metadata__mitter_id}" --fail-fast
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
Package facilitates surfacing intents that open particular scenario, story or a skill. The list of such intents is configured in seeds and available in interaction and session level as `first_intent` field.

## Running DBT Package Manually
Like any other package, this one can be also run from the command line. This is the preferred method when you need to customize it deeper ie. by changing the transformations in `sql` files. 

### Pick Up the Warehouse and DBT Profile
We support both Redshift and BigQuery in the same package. In order to use any of them, you need to provide access credentials to the profile that you choose. Each profile requires set of environment variables to be present and have corresponding `.example.env` file that you can use to define env variables.

1. `rasa_semantic_schema_redshift` and `.redshift.example.env` profile to connect to Redshift
2. `rasa_semantic_schema_bigquery` and `.bigquery.example.env` profile to connect to BigQuery with a set of environment variables
3. `rasa_semantic_schema_bigquery_service_file` and `.bigquery_file.example.env` profile to connect to BigQuery with a service account credentials file

To use any of the profiles
1. Enable the profile in `dbt_project.yml` (or pass the profile explicitly to the `dbt` command)
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
By default destination (`staging` and `views`) schemas will use the same schema prefix as **source schemas** (`event` and `model`). Alternative destination schema prefix can be specified with `dest_schema_prefix` variable. This allows to have several semantic schemas created from single source schema for example to test different settings, run automated tests or experiment with model transformations.

Currently only **full refresh** runs are supported when destination schema prefix is different from source schema prefix.

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
3. test if source schema (`event`) was created (or have the package fail on non existing tables)
```
dbt test --profiles-dir . --vars "{source_schema_prefix: findemo_eks}" -s tag:prerequisites
```
will return non 0 exit code if fails

4. run the package incrementally
5. optionally run tests

## Package Versioning
Versioning of this package follows the semantic versioning with `MAJOR.MINOR.REVISION` pattern. This is particularly relevant if you use this package as a DBT dependency in other DBT package.

1. `MAJOR` and `MINOR` indicate significant update that should be deployed manually. Running package should be stopped and dependencies updated. **A full refresh of the models may be required before scheduled incremental loads are enabled again.**
2. `REVISION` may be applied by changing the revision/version in DBT `packages.yml`. **Full refresh is not required**

## Loads lifecycle and `_loads` table
Package identifies new data by finding all load identifiers in `_loads` table in `event` schema that have only one entry with status 0.

On the successful processing new records are inserted with status = 1.

### Full Refresh
Full refresh will take all the existing distinct loads from the `_loads` table.
[dbt docs](https://docs.getdbt.com/docs/building-a-dbt-project/building-models/configuring-incremental-models#what-if-the-columns-of-my-incremental-model-change)
```
dbt run --full-refresh --profiles-dir . --vars "{source_schema_prefix: findemo_eks}" --fail-fast
```