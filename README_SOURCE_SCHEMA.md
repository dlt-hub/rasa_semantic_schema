# Source Schemas
Source schemas are created by Rasa Ingestion Pipeline by representing tracker store documents and bot models data in relational form. There are two separate schemas created.

## Event Schema

Event schema represents tracker store events and contains following tables.

* **event** corresponds to the tracker and represents the order of the events for particular conversation.
* **event_<event_type>** a set of tables corresponding to particular event types
* **event_<event_type>__<nested_field_name>** child tables with the data from nested fields which could not be flattened (they were lists of simple values or objects)

### Common Columns

**event** and **event_<event_type>** tables contain several common columns

| column name  | column type | description                                                                                  |
| ------------ | ----------- | -------------------------------------------------------------------------------------------- |
| _record_hash | str         | Unique id of the record                                                                      |
| _root_hash   | str         | Unique id of the top level parent record, in case of top level parent equals to _record_hash |
| timestamp    | timestamp   | Timestamp of the event                                                                       |
| model_id     | str         | ID of the model that generated the event, from SDK 3.0 or inferred from RASA X models        |
| sender_id    | str         | ID of the conversation                                                                       |
| _load_id     | str         | Batch identifier, used in incremental loading                                                |
|              |             |                                                                                              |

### Propagated Fields

Several fields are propagated to child tables in order to link them to parent tables but also to support partitioning and clustering of the data (depening on the warehouse ie. Redshift vs BigQuery)


| column name  | column type | description                                                         |
| ------------ | ----------- | ------------------------------------------------------------------- |
| _record_hash |             |                                                                     |
| _root_hash   |             |                                                                     |
| _parent_hash | str         | Unique ID of the parent record                                      |
| _pos         | int         | Position in the list in the parent record that generated this table |
| _timestamp   | timestamp   | Propagated parent timestamp, supports partitioning                  |
| _dist_key    | str         | Propagated *sender_id* to support clustering                        |
|              |             |                                                                     |

## Model Schema

Represents bot model with tables that correspond to

* stories
* rules
* domain

with the same rules for table linking as above

# Unpacking Engine

Unpacking engine transforms nested JSON document into a relational form. Each document is processed recursively

* Simple values and JSON objects are flattened at the current recurson level and represented as fields in the current table. The flattened field names have following convention `<complex_field_name>__<nested_compex_field_name>__..__<simple_field_name>`
* Lists increase recursion and create child tables 
* All rows in all tables have unique ids
* Child tables are linked to parent tables with parent unique id

Engine allows to transform JSON document before unpacking. For example `model` schema is transformed to remove unnecessary nesting and to obtain simpler relational form.

Engine allows custom break downs into child tables ie. `event` schema breaks down recustion level 0 tables by `event_type` to have separate tables for different types of events.

Engine allows to propagate a set of fields to all child tables. This allows to use consistent partitioning and clustering for parent and child tables.

Engine generates schema definition files that can be exporet ie. as DBT schema. It also generates schema migrations between any two versions. Schema migrations are backwards compatible.

Engine infers following field types
* string
* double
* bigint
* timestamp

for fields with conflicting types, variant columns will be generated.

## System Tables

Engine generates two system tables

* `_versions` that holds history of schema migrations
* `_loads` that holds history of the loaded batches and allows for further ordered processing of new data (which DBT package also uses)
