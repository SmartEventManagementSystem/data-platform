# EMS Data Platform

## Overview

Full data infrastructure for the Event Management System platform, built with modern data engineering tools.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           EMS Data Platform                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                    │
│  │  PostgreSQL  │    │   MongoDB    │    │    MySQL     │  Data Sources     │
│  │   Events     │    │  Analytics   │    │   Legacy     │                    │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘                    │
│         │                   │                   │                            │
│         └───────────────────┼───────────────────┘                            │
│                             ▼                                                  │
│                   ┌───────────────────┐                                       │
│                   │     Debezium       │  CDC                                 │
│                   │     (Kafka)       │                                       │
│                   └─────────┬──────────┘                                       │
│                             │                                                  │
│         ┌───────────────────┼───────────────────┐                             │
│         ▼                   ▼                   ▼                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                      │
│  │    Kafka    │    │  Airflow    │    │   Flink     │                      │
│  │  Streaming  │    │  Pipeline   │    │   Stream    │                      │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘                      │
│         │                  │                  │                             │
│         ▼                  ▼                  ▼                              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                      │
│  │  Superset   │    │   Iceberg   │    │    Trino    │                      │
│  │    BI       │    │   Lakehouse │    │   Query     │                      │
│  └─────────────┘    └─────────────┘    └──────┬──────┘                      │
│                              │                 │                              │
│                              ▼                 ▼                              │
│                     ┌─────────────────────┐                                   │
│                     │     MinIO (S3)      │  Storage                         │
│                     │   + OpenMetadata    │  + Catalog                       │
│                     └─────────────────────┘                                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Version | Port | Purpose |
|-----------|---------|------|---------|
| **Kafka** | 7.6.0 | 9092 | Event streaming platform |
| **Kafka UI** | latest | 8090 | Kafka management UI |
| **Schema Registry** | 7.6.0 | 8081 | Avro/JSON schema registry |
| **Kafka Connect** | 7.6.0 | 8083 | CDC connectors |
| **Airflow** | 2.9.0 | 8085 | Pipeline orchestration |
| **Superset** | 4.0.1 | 8088 | BI and visualization |
| **OpenMetadata** | 1.3.0 | 8585 | Data catalog |
| **Elasticsearch** | 8.12.0 | 9200 | Search and indexing |
| **Iceberg REST** | 1.5.2 | 8181 | Lakehouse catalog |
| **Spark + Iceberg** | 3.5_1.5.2 | 8080 | SQL on Iceberg |
| **MinIO** | latest | 9000 | S3-compatible storage |
| **Trino** | 437 | 8089 | Distributed SQL engine |
| **NiFi** | 2.0.0 | 8443 | Data flow automation |
| **Flink** | 1.19.0 | 8083 | Stream processing |
| **Debezium** | 2.5 | 8086 | CDC |
| **PostgreSQL** | 15 | 5432-5436 | Relational databases |
| **MongoDB** | 7.0 | 27017 | Document database |
| **MySQL** | 8.0 | 3306 | Legacy database |
| **Redis** | 7 | 6379 | Caching |
| **Qdrant** | 1.7.0 | 6333 | Vector database for RAG |
| **BigQuery Emulator** | latest | 9051 | Analytics warehouse |
| **Iceberg Catalog** | 1.5.2 | 8181 | Lakehouse metadata |
| **Hive Metastore** | 3.0.0 | 9083 | Table metadata |
| **Apache Atlas** | 3.2.1 | 21000 | Data governance |

## Quick Start

### Prerequisites

- Docker & Docker Compose
- At least 16GB RAM recommended
- 50GB disk space

### Start All Services

```bash
cd data-platform

# Start all services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f [service-name]
```

### Stop All Services

```bash
docker compose down

# Remove volumes (WARNING: deletes all data)
docker compose down -v
```

## Service Access

| Service | URL | Credentials |
|---------|-----|------------|
| Airflow | http://localhost:8085 | admin / admin123 |
| Superset | http://localhost:8088 | admin / admin123 |
| OpenMetadata | http://localhost:8585 | admin / admin123 |
| Kafka UI | http://localhost:8090 | - |
| Flink | http://localhost:8083 | - |
| Spark UI | http://localhost:8080 | - |
| MinIO Console | http://localhost:9001 | minioadmin / minioadmin123 |
| Trino | http://localhost:8089 | - |
| NiFi | https://localhost:8443 | - |
| Elasticsearch | http://localhost:9200 | - |
| Qdrant | http://localhost:6333 | - |
| MinIO API | http://localhost:9000 | minioadmin / minioadmin123 |
| Hive Metastore | http://localhost:9083 | - |

## Data Flow

### 1. Event Streaming (Kafka)
```
PostgreSQL → Debezium → Kafka Topics → Flink/Spark → Iceberg
```

### 2. Pipeline Orchestration (Airflow)
```
Source DBs → Extract → Transform → Load → Iceberg → Superset
```

### 3. Real-time Analytics (Flink)
```
Kafka Events → Flink Stream → Real-time Aggregations → Dashboard
```

## Kafka Topics

| Topic | Description |
|-------|-------------|
| `ems.events` | Event creation and updates |
| `ems.users` | User registration events |
| `ems.tickets` | Ticket purchase events |
| `ems.analytics` | User behavior analytics |
| `ems.notifications` | Push notification events |

## Iceberg Tables

| Table | Description |
|-------|-------------|
| `ems.events` | All event data with time travel |
| `ems.users` | User profiles and preferences |
| `ems.analytics_events` | Page views, clicks, sessions |
| `ems.revenue` | Financial aggregations |

## Superset Setup

1. Go to http://localhost:8088
2. Login with admin / admin123
3. Add database connection:
   - Database: PostgreSQL (ems-postgres-events:5432)
   - Username: emsuser
   - Password: emspass123

## OpenMetadata Setup

1. Go to http://localhost:8585
2. Login with admin / admin123
3. Configure services:
   - Airflow (http://airflow-webserver:8080)
   - Kafka (kafka:29092)
   - Database (postgres-events:5432)

## Airflow DAGs

### event_analytics_pipeline.py
Hourly pipeline that:
1. Extracts events, tickets, attendees from PostgreSQL
2. Computes analytics metrics
3. Loads to Kafka for real-time processing

### ingestion_pipeline.py
Daily pipeline that:
1. Ingests data from PostgreSQL
2. Ingests analytics from MongoDB
3. Validates ingestion to Iceberg

### reporting_pipeline.py
Daily report generation:
1. Daily event reports
2. Weekly aggregations
3. Superset cache refresh

## Development

### Add new DAG
```bash
# Create DAG file
touch dags/my_dag.py

# DAG will be auto-loaded by Airflow
```

### Connect new database to OpenMetadata
```bash
# Register in OpenMetadata UI
# Or use API:
curl -X POST http://localhost:8585/api/v1/services/databaseServices \
  -H "Content-Type: application/json" \
  -d @config/om-database.json
```

## Troubleshooting

### Kafka not starting
```bash
# Check zookeeper
docker compose logs zookeeper

# Reset Kafka
docker compose down -v
docker compose up -d
```

### Airflow not connecting to PostgreSQL
```bash
# Check network
docker network inspect ems-dataplatform

# Recreate containers
docker compose restart airflow-webserver
```

### MinIO buckets not created
```bash
# Run mc init manually
docker compose exec mc /bin/sh -c "mc alias set ems http://minio:9000 minioadmin minioadmin123 && mc mb ems/warehouse"
```

## Environment Variables

All sensitive values should be overridden in production:

```bash
# Create .env file
cat > .env << EOF
POSTGRES_PASSWORD=secure_password_here
REDIS_PASSWORD=secure_password_here
SUPERSET_SECRET_KEY=secure_key_here
MINIO_ROOT_PASSWORD=secure_password_here
EOF
```

## License

MIT
