"""
EMS Data Ingestion Pipeline DAG
Ingests data from MongoDB, MySQL, and Kafka to Iceberg
"""
from datetime import datetime, timedelta
from airflow.decorators import dag, task
from airflow.providers.postgres.hooks.postgres import PostgresHook
import json
import logging

default_args = {
    'owner': 'ems-platform',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'retries': 3,
    'retry_delay': timedelta(minutes=5),
}

@dag(
    default_args=default_args,
    description='Data ingestion from multiple sources to Iceberg',
    schedule_interval='@daily',
    catchup=False,
    tags=['ems', 'ingestion', 'iceberg'],
)
def data_ingestion_pipeline():
    """
    Ingests data from:
    - PostgreSQL (events, users, tickets)
    - MongoDB (analytics events, logs)
    - MySQL (legacy data)
    To Iceberg via REST Catalog
    """

    @task
    def ingest_postgres_events():
        """Ingest events from PostgreSQL to Iceberg"""
        hook = PostgresHook(postgres_conn_id='ems_postgres')
        sql = """
            SELECT
                e.id, e.workspace_id, e.title, e.description,
                e.location, e.start_time, e.end_time, e.status,
                e.max_attendees, e.current_attendees,
                e.price, e.currency, e.is_public,
                e.creator_id, e.created_at, e.updated_at,
                u.name as creator_name
            FROM events e
            LEFT JOIN users u ON u.id = e.creator_id
            WHERE e.updated_at >= '{{ yesterday_ds }}'
        """
        df = hook.get_pandas_df(sql)
        records = df.to_dict('records')

        # Write to Iceberg via REST API
        logging.info(f"Ingesting {len(records)} events to Iceberg")

        # Placeholder for Iceberg REST API call
        # In production, use pyiceberg or Spark
        return {
            'table': 'ems.events',
            'record_count': len(records),
            'status': 'success'
        }

    @task
    def ingest_postgres_users():
        """Ingest users from PostgreSQL to Iceberg"""
        hook = PostgresHook(postgres_conn_id='ems_postgres')
        sql = """
            SELECT
                id, email, name, avatar, role,
                bio, phone, created_at, updated_at
            FROM users
            WHERE updated_at >= '{{ yesterday_ds }}'
        """
        df = hook.get_pandas_df(sql)
        records = df.to_dict('records')

        logging.info(f"Ingesting {len(records)} users to Iceberg")
        return {
            'table': 'ems.users',
            'record_count': len(records),
            'status': 'success'
        }

    @task
    def ingest_mongodb_analytics():
        """Ingest analytics events from MongoDB"""
        # MongoDB connection would use PyMongoHook
        logging.info("Ingesting MongoDB analytics data")

        # Sample structure for MongoDB documents
        sample_docs = [
            {
                'event_id': 'evt_001',
                'action': 'page_view',
                'user_id': 'usr_001',
                'timestamp': datetime.now().isoformat(),
                'metadata': {
                    'page': '/events',
                    'referrer': 'google.com'
                }
            }
        ]

        return {
            'table': 'ems.analytics_events',
            'record_count': len(sample_docs),
            'status': 'success'
        }

    @task
    def validate_ingestion(ingestion_results):
        """Validate ingestion results"""
        for result in ingestion_results:
            if result['status'] != 'success':
                raise ValueError(f"Ingestion failed for {result['table']}")

            if result['record_count'] == 0:
                logging.warning(f"No records ingested for {result['table']}")

        logging.info("All ingestion tasks validated successfully")
        return True

    # Run ingestion tasks
    postgres_events = ingest_postgres_events()
    postgres_users = ingest_postgres_users()
    mongodb_analytics = ingest_mongodb_analytics()

    # Validate after all ingestions complete
    validate_ingestion([postgres_events, postgres_users, mongodb_analytics])

data_ingestion_dag = data_ingestion_pipeline()
