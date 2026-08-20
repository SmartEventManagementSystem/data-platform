"""
EMS Event Analytics Pipeline DAG
Loads event data, computes analytics, and stores to Iceberg
"""
from datetime import datetime, timedelta
from airflow.decorators import dag, task
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.providers.kafka.operators.kafka import KafkaProduceOperator
import json
import logging

default_args = {
    'owner': 'ems-platform',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

@dag(
    default_args=default_args,
    description='Event analytics data pipeline',
    schedule_interval='@hourly',
    catchup=False,
    tags=['ems', 'analytics', 'events'],
)
def event_analytics_pipeline():
    """
    Pipeline stages:
    1. Extract - Fetch events, tickets, attendees from PostgreSQL
    2. Transform - Compute aggregations and metrics
    3. Load - Store to Iceberg via Kafka
    """

    @task
    def extract_events(**context):
        """Extract events data from PostgreSQL"""
        hook = PostgresHook(postgres_conn_id='ems_postgres')
        sql = """
            SELECT
                e.id, e.title, e.description, e.location,
                e.start_time, e.end_time, e.status,
                e.max_attendees, e.current_attendees,
                e.price, e.currency,
                COUNT(DISTINCT t.id) as ticket_count,
                COUNT(DISTINCT att.user_id) as registration_count
            FROM events e
            LEFT JOIN tickets t ON t.event_id = e.id
            LEFT JOIN event_attendees att ON att.event_id = e.id
            WHERE e.created_at >= '{{ ds }}'
            GROUP BY e.id
        """
        df = hook.get_pandas_df(sql)
        df['extract_date'] = context['ds']
        return df.to_json()

    @task
    def transform_events(raw_data, **context):
        """Transform and compute analytics"""
        import pandas as pd
        df = pd.read_json(raw_data)

        # Compute metrics
        df['occupancy_rate'] = (df['current_attendees'] / df['max_attendees'] * 100).round(2)
        df['revenue'] = (df['ticket_count'] * df['price']).round(2)
        df['avg_ticket_price'] = df['price']

        # Add derived fields
        df['pipeline_timestamp'] = datetime.now().isoformat()
        df['data_quality_score'] = df.apply(
            lambda x: 100 if x['current_attendees'] <= x['max_attendees'] else 85, axis=1
        )

        return df.to_json()

    @task
    def load_to_kafka(transformed_data):
        """Load transformed data to Kafka for downstream processing"""
        import pandas as pd
        df = pd.read_json(transformed_data)

        # Produce to Kafka topics
        kafka_messages = []
        for _, row in df.iterrows():
            message = {
                'event_id': row['id'],
                'title': row['title'],
                'occupancy_rate': row['occupancy_rate'],
                'revenue': row['revenue'],
                'timestamp': row['pipeline_timestamp'],
            }
            kafka_messages.append(json.dumps(message))

        # Return messages for Kafka operator
        return kafka_messages

    @task
    def compute_realtime_metrics():
        """Compute real-time metrics for dashboards"""
        hook = PostgresHook(postgres_conn_id='ems_postgres')

        metrics = {}

        # Total events
        result = hook.get_records("""
            SELECT COUNT(*) FROM events WHERE status = 'published'
        """)
        metrics['total_published_events'] = result[0][0] if result else 0

        # Total attendees today
        result = hook.get_records("""
            SELECT COUNT(*) FROM event_attendees
            WHERE DATE(created_at) = CURRENT_DATE
        """)
        metrics['new_registrations_today'] = result[0][0] if result else 0

        # Revenue today
        result = hook.get_records("""
            SELECT COALESCE(SUM(amount), 0) FROM balance_transactions
            WHERE DATE(created_at) = CURRENT_DATE AND type = 'credit'
        """)
        metrics['revenue_today'] = float(result[0][0]) if result else 0.0

        logging.info(f"Computed metrics: {metrics}")
        return metrics

    # Task dependencies
    raw_events = extract_events()
    transformed = transform_events(raw_events)
    load_to_kafka(transformed)
    compute_realtime_metrics()

event_analytics_dag = event_analytics_pipeline()
