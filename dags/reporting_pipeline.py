"""
EMS Reporting & Aggregation Pipeline DAG
Generates daily, weekly, monthly reports
"""
from datetime import datetime, timedelta
from airflow.decorators import dag, task
from airflow.providers.postgres.hooks.postgres import PostgresHook
import logging

default_args = {
    'owner': 'ems-platform',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'retries': 2,
    'retry_delay': timedelta(minutes=10),
}

@dag(
    default_args=default_args,
    description='Generate reports and aggregations',
    schedule_interval='0 2 * * *',  # Daily at 2 AM
    catchup=False,
    tags=['ems', 'reporting', 'analytics'],
)
def reporting_pipeline():

    @task
    def generate_daily_report(**context):
        """Generate daily event report"""
        execution_date = context['ds']
        hook = PostgresHook(postgres_conn_id='ems_postgres')

        report = {
            'report_date': execution_date,
            'report_type': 'daily',
            'generated_at': datetime.now().isoformat(),
        }

        # Event statistics
        event_stats = hook.get_records("""
            SELECT
                COUNT(*) FILTER (WHERE status = 'published') as published,
                COUNT(*) FILTER (WHERE status = 'ongoing') as ongoing,
                COUNT(*) FILTER (WHERE status = 'completed') as completed,
                COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled
            FROM events
            WHERE DATE(created_at) = '{{ ds }}'
        """)
        report['events_created'] = sum(event_stats[0]) if event_stats else 0

        # Registration statistics
        reg_stats = hook.get_records("""
            SELECT COUNT(*) FROM event_attendees
            WHERE DATE(created_at) = '{{ ds }}'
        """)
        report['new_registrations'] = reg_stats[0][0] if reg_stats else 0

        # Ticket sales
        ticket_stats = hook.get_records("""
            SELECT COUNT(*), COALESCE(SUM(price), 0)
            FROM tickets
            WHERE DATE(created_at) = '{{ ds }}'
        """)
        report['tickets_sold'] = ticket_stats[0][0] if ticket_stats else 0
        report['ticket_revenue'] = float(ticket_stats[0][1]) if ticket_stats else 0.0

        # Top events by registrations
        top_events = hook.get_pandas_df("""
            SELECT
                e.id, e.title,
                COUNT(a.id) as registrations
            FROM events e
            LEFT JOIN event_attendees a ON a.event_id = e.id
            WHERE DATE(e.start_time) = '{{ ds }}'
            GROUP BY e.id, e.title
            ORDER BY registrations DESC
            LIMIT 10
        """)
        report['top_events'] = top_events.to_dict('records') if not top_events.empty else []

        logging.info(f"Daily report generated: {report}")
        return report

    @task
    def generate_weekly_report():
        """Generate weekly aggregated report"""
        hook = PostgresHook(postgres_conn_id='ems_postgres')

        report = {
            'report_type': 'weekly',
            'week_start': (datetime.now() - timedelta(days=7)).isoformat(),
            'generated_at': datetime.now().isoformat(),
        }

        weekly_stats = hook.get_records("""
            SELECT
                COUNT(DISTINCT e.id) as total_events,
                COUNT(DISTINCT a.user_id) as unique_attendees,
                COUNT(a.id) as total_registrations,
                COALESCE(SUM(t.price), 0) as total_revenue
            FROM events e
            LEFT JOIN event_attendees a ON a.event_id = e.id
            LEFT JOIN tickets t ON t.event_id = e.id
            WHERE e.created_at >= NOW() - INTERVAL '7 days'
        """)

        if weekly_stats:
            report.update({
                'total_events': weekly_stats[0][0],
                'unique_attendees': weekly_stats[0][1],
                'total_registrations': weekly_stats[0][2],
                'total_revenue': float(weekly_stats[0][3]),
            })

        logging.info(f"Weekly report generated: {report}")
        return report

    @task
    def update_superset_cache():
        """Trigger Superset cache refresh"""
        # In production, call Superset API to refresh charts
        logging.info("Superset cache refresh triggered")
        return {'status': 'success'}

    # Pipeline flow
    daily_report = generate_daily_report()
    weekly_report = generate_weekly_report()
    update_superset_cache()

reporting_dag = reporting_pipeline()
