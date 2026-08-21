# EMS Data Platform

## Overview

Data infrastructure for the Event Management System platform, built with modern data engineering tools.

**Note:** Uses PostgreSQL as the primary database driver (not MySQL).

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           EMS Data Platform                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                   │
│  │  PostgreSQL  │    │   MongoDB    │    │  PostgreSQL  │  Data Sources     │
│  │   Events     │    │  Analytics   │    │ OpenMetadata │                   │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘                   │
│         │                   │                   │                            │
│         └───────────────────┼───────────────────┘                            │
│                             ▼                                                │
│                   ┌───────────────────┐                                      │
│                   │     Debezium       │  CDC                                 │
│                   │     (Kafka)       │                                      │
│                   └─────────┬──────────┘                                      │
│                             │                                                │
│         ┌───────────────────┼───────────────────┐                            │
│         ▼                   ▼                   ▼                            │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                     │
│  │    Kafka    │    │  OpenMeta    │    │   Flink     │                     │
│  │  Streaming  │    │   data       │    │   Stream    │                     │
│  └──────┬──────┘    └─────────────┘    └──────┬──────┘                     │
│         │                                      │                             │
│         ▼                                      ▼                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                    │
│  │   Iceberg   │    │   Trino     │    │    Trino    │                    │
│  │   Lakehouse │    │   Query     │    │   Query     │                    │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘                    │
│         │                   │                   │                            │
│         └───────────────────┴───────────────────┘                            │
│                             ▼                                                │
│                     ┌─────────────────────┐                                  │
│                     │     MinIO (S3)      │  Storage                        │
│                     └─────────────────────┘                                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Version | Port | Purpose |
|-----------|---------|------|---------|
| **PostgreSQL** | 15 | 5432 | Event database |
| **PostgreSQL (OM)** | 15 | 5436 | OpenMetadata database |
| **PostgreSQL (Airflow)** | 15 | 5434 | Airflow metadata |
| **PostgreSQL (Superset)** | 15 | 5435 | Superset metadata |
| **Kafka** | 7.6.0 | 9092 | Event streaming |
| **Kafka UI** | latest | 8090 | Kafka management UI |
| **Schema Registry** | 7.6.0 | 8081 | Avro/JSON schema registry |
| **OpenMetadata** | 1.7.4 | 8585 | Data catalog |
| **Elasticsearch** | 8.12.0 | 9200 | Search and indexing |
| **Iceberg REST** | 1.6.0 | 8181 | Lakehouse catalog |
| **MinIO** | latest | 9000/9001 | S3-compatible storage |
| **Trino** | 436 | 8089 | Distributed SQL engine |
| **Redis** | 7 | 6379/6380 | Caching |
| **MongoDB** | 7.0 | 27017 | Document database |
| **Flink** | 1.19.0 | 8083 | Stream processing |
| **Debezium** | 2.5 | 9086 | CDC |
| **NiFi** | 2.0.0 | 8443 | Data flow automation |
| **Qdrant** | 1.7.0 | 6333 | Vector database for RAG |

## Prerequisites

- Docker & Docker Compose (v2+)
- At least 10GB RAM recommended (16GB for full stack)
- 50GB disk space

## Quick Start

### 1. Start Core Services (Recommended for Development)

```bash
cd data-platform
./start-local.sh
```

This starts essential services:
- PostgreSQL (events, OpenMetadata, Airflow)
- Redis
- Kafka + Zookeeper + Schema Registry
- Elasticsearch
- OpenMetadata
- Trino
- MinIO + Iceberg REST

### 2. Start All Services (Full Stack)

```bash
cd data-platform
docker compose up -d
```

### 3. Check Status

```bash
./start-local.sh --status
# or
docker compose ps
```

### 4. Stop Services

```bash
docker compose down

# Stop and remove volumes (WARNING: deletes all data)
docker compose down -v
```

## Service Access

| Service | URL | Credentials |
|---------|-----|------------|
| **OpenMetadata** | http://localhost:8585 | admin / admin123 |
| **Kafka UI** | http://localhost:8090 | - |
| **MinIO Console** | http://localhost:9001 | minioadmin / minioadmin123 |
| **Trino** | http://localhost:8089 | - |
| **Elasticsearch** | http://localhost:9200 | - |
| **Qdrant** | http://localhost:6333 | - |
| **NiFi** | https://localhost:8443 | - |
| **Flink** | http://localhost:8083 | - |
| **MongoDB** | localhost:27017 | emsuser / emspass123 |

## Database Connections

| Database | Host | Port | User | Password | Database |
|----------|------|------|------|----------|----------|
| Events | postgres-events | 5432 | emsuser | emspass123 | ems_events |
| OpenMetadata | postgres-om | 5436 | openmetadata | openmetadata123 | openmetadata_db |
| Airflow | postgres-airflow | 5434 | airflow | airflow123 | airflow |
| Superset | postgres-superset | 5435 | superset | superset123 | superset |

## Kafka Topics

| Topic | Description |
|-------|-------------|
| `ems.events` | Event creation and updates |
| `ems.users` | User registration events |
| `ems.tickets` | Ticket purchase events |
| `ems.analytics` | User behavior analytics |
| `ems.notifications` | Push notification events |

## OpenMetadata Setup

OpenMetadata is pre-configured with PostgreSQL driver (not MySQL).

1. Go to http://localhost:8585
2. Login with admin / admin123
3. Configure services:
   - Kafka: kafka:29092
   - Database: postgres-events:5432 (emsuser/emspass123)

## Trino Query Engine

Connect to Trino for SQL queries across data sources:

```bash
# Using trino CLI (install first)
trino --server http://localhost:8089

# Or connect via Superset
# http://localhost:8088
```

### Trino Catalogs

| Catalog | Description |
|---------|-------------|
| `postgres` | PostgreSQL events database |
| `postgresql` | PostgreSQL (Iceberg config) |
| `iceberg` | Iceberg tables via MinIO |

## Iceberg + MinIO (Lakehouse)

MinIO is configured with Iceberg REST catalog:

```bash
# Access MinIO Console
http://localhost:9001
# Credentials: minioadmin / minioadmin123

# Buckets created:
# - warehouse (Iceberg data)
# - spark-warehouse
# - datalake
```

## Troubleshooting

### OpenMetadata not starting
```bash
# Check PostgreSQL for OpenMetadata is healthy
docker compose ps postgres-om

# Check logs
docker compose logs openmetadata

# May take 2-3 minutes on first start
```

### Kafka not starting
```bash
# Check zookeeper
docker compose logs zookeeper

# Reset Kafka
docker compose down
docker compose up -d kafka zookeeper
```

### MinIO buckets not created
```bash
# Run mc init manually
docker compose exec mc /bin/sh -c "mc alias set ems http://minio:9000 minioadmin minioadmin123 && mc mb ems/warehouse"
```

### Trino not connecting to catalogs
```bash
# Check catalog configs
cat config/trino/etc/catalog/*.properties

# Restart Trino
docker compose restart trino
```

## Development

### Adding New Services

Add new services to `docker-compose.yml`. Use `postgres-om` as template for PostgreSQL-based services.

### Connecting to PostgreSQL from Host

```bash
# Events database
psql -h localhost -p 5432 -U emsuser -d ems_events

# OpenMetadata database
psql -h localhost -p 5436 -U openmetadata -d openmetadata_db
```

### Running SQL Scripts

```bash
# Initialize events database
docker compose exec -T postgres-events psql -U emsuser -d ems_events < scripts/init-postgres-events.sql
```

## License

MIT
