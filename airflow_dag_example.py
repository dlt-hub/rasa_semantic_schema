
from airflow.operators import BashOperator
from airflow.models import DAG
from datetime import datetime, timedelta

yesterday = datetime.combine(datetime.today() - timedelta(1),
                                  datetime.min.time())
args = {
    'owner': 'airflow',
    'start_date': yesterday,
}

dag = DAG(
    dag_id='Rasabot_semantic_schema',
    default_args=args,
    schedule_interval='0 0 * * *')


pg_pass = 'input here' #get from your secret manager / credential store such as airflow / env vars, etc.
schema_prefix = ''
# --full-refresh

cmd = f"""env $(cat .env | grep "^[^#;]" | xargs) PG_PASSWORD={pg_pass} dbt run  --profiles-dir . --vars "{{source_schema_prefix: {schema_prefix}}" --fail-fast
"""

schema_task = BashOperator(
    task_id='rasa_semantic_dbt_package', bash_command=cmd, dag=dag)


schema_task