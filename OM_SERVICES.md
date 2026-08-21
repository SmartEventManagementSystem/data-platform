# OpenMetadata Services - Connection Details

## Database Services

### 1. PostgreSQL - Events Database
```
Service Name: postgres-events
Service Type: PostgreSQL
Description: PostgreSQL for event data

Connection:
  Host: ems-postgres-events
  Port: 5432
  Database: ems_events
  Username: emsuser
  Password: emspass123
  SSL Mode: disable
```

---

### 2. PostgreSQL - Airflow Metadata
```
Service Name: postgres-airflow
Service Type: PostgreSQL
Description: PostgreSQL for Airflow metadata

Connection:
  Host: ems-postgres-airflow
  Port: 5432
  Database: airflow
  Username: airflow
  Password: airflow123
  SSL Mode: disable
```

---

### 3. PostgreSQL - Superset Metadata
```
Service Name: postgres-superset
Service Type: PostgreSQL
Description: PostgreSQL for Superset metadata

Connection:
  Host: ems-postgres-superset
  Port: 5432
  Database: superset
  Username: superset
  Password: superset123
  SSL Mode: disable
```

---

### 4. PostgreSQL - OpenMetadata Database
```
Service Name: postgres-om
Service Type: PostgreSQL
Description: PostgreSQL for OpenMetadata

Connection:
  Host: ems-postgres-om
  Port: 5432
  Database: openmetadata_db
  Username: openmetadata
  Password: openmetadata123
  SSL Mode: disable
```

---

### 5. MongoDB
```
Service Name: mongodb
Service Type: MongoDB
Description: MongoDB for analytics

Connection:
  Host: ems-mongodb
  Port: 27017
  Database: ems_analytics
  Username: emsuser
  Password: emspass123
  Auth Source: admin
```

---

## Messaging Services

### 6. Kafka
```
Service Name: kafka
Service Type: Kafka
Description: Kafka event streaming

Connection:
  Bootstrap Servers: ems-kafka:29092
  Schema Registry URL: ems-schema-registry:8081
```

---

## Pipeline Services

### 7. Airflow
```
Service Name: airflow
Service Type: Airflow
Description: Apache Airflow orchestration

Connection:
  Host: ems-airflow-webserver
  Port: 8080
  Auth Provider: Basic Auth

Metadata Database:
  Connection Type: PostgreSQL
  Host: ems-postgres-airflow
  Port: 5432
  Database: airflow
  Username: airflow
  Password: airflow123
```

---

## Dashboard Services

### 8. Superset
```
Service Name: superset
Service Type: Superset
Description: Apache Superset BI tool

Connection:
  Host: ems-superset
  Port: 8088
```

---

## Storage Services

### 9. MinIO (S3-compatible)
```
Service Name: minio
Service Type: S3
Description: MinIO S3-compatible storage

Connection:
  Bucket: warehouse
  Prefix: (empty)
  Region: us-east-1
  Access Key: minioadmin
  Secret Key: minioadmin123
  S3 Endpoint URL: http://ems-minio:9000
  S3A Path: warehouse
```

---

## Search Services

### 10. Elasticsearch
```
Service Name: elasticsearch
Service Type: ElasticSearch
Description: Elasticsearch search engine

Connection:
  Host: ems-elasticsearch
  Port: 9200
  Username: (none)
  Password: (none)
  SSL: false
```

---

## Vector Database

### 11. Qdrant
```
Service Name: qdrant
Service Type: OpenSearch
Description: Qdrant vector database

Connection:
  Host: ems-qdrant
  Port: 6333
```

---

## How to Add Services in OpenMetadata UI

### Step 1: Go to Settings → Services
1. Open http://localhost:8585
2. Login: admin@openmetadata.org / admin
3. Click Settings (gear icon) → Services

### Step 2: Add Database Service
1. Click "Add New Service"
2. Select "Database" category
3. Choose "PostgreSQL"
4. Fill in connection details
5. Click "Save"
6. Go to "Ingestion" tab
7. Click "Add Ingestion" → "Run Immediately"

### Step 3: Add Messaging Service (Kafka)
1. Click "Add New Service"
2. Select "Messaging" category
3. Choose "Kafka"
4. Fill in bootstrap servers: ems-kafka:29092

### Step 4: Add Pipeline Service (Airflow)
1. Click "Add New Service"
2. Select "Pipeline" category
3. Choose "Airflow"
4. Fill in details as shown above

---

## Quick Setup Commands (Optional)

To test connections from within Docker network:

```bash
# Test PostgreSQL
docker exec ems-postgres-events psql -U emsuser -d ems_events -c "SELECT 1"

# Test MongoDB
docker exec ems-mongodb mongosh -u emsuser -p emspass123 --authenticationDatabase admin

# Test Kafka
docker exec ems-kafka kafka-topics --bootstrap-server ems-kafka:29092 --list
```
