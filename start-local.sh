#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[ OK ]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    exit 1
fi

if ! docker info &> /dev/null; then
    log_error "Docker is not running"
    exit 1
fi

# Check Docker Desktop memory
MEMORY=$(docker info 2>/dev/null | grep "Total Memory" | awk '{print $3}')
if [[ "${MEMORY%%.*}" -lt 10 ]]; then
    log_warn "Docker Desktop memory is ${MEMORY}. Recommended: 16GB+"
    log_warn "Go to Docker Desktop > Settings > Resources to increase memory"
fi

log_info "Starting EMS Data Platform - ALL Services..."

# Stop existing containers and remove orphans
log_info "Stopping existing containers..."
docker compose down --remove-orphans 2>/dev/null || docker-compose down --remove-orphans 2>/dev/null || true

# Step 1: Start PostgreSQL for OpenMetadata first
log_info "Starting PostgreSQL for OpenMetadata..."
docker compose up -d postgres-om

# Step 2: Configure PostgreSQL trust auth for Docker network
log_info "Configuring PostgreSQL authentication..."
for i in {1..15}; do
    if docker exec ems-postgres-om pg_isready -U openmetadata &>/dev/null; then
        docker exec ems-postgres-om bash -c "su postgres -c '/usr/lib/postgresql/15/bin/pg_ctl reload -D /var/lib/postgresql/data' 2>/dev/null || true"
        break
    fi
    echo -n "."
    sleep 2
done

# Ensure pg_hba.conf allows trust auth for Docker network
docker exec ems-postgres-om bash -c "
    if ! grep -q '0.0.0.0/0.*trust' /var/lib/postgresql/data/pg_hba.conf 2>/dev/null; then
        echo 'host all all 0.0.0.0/0 trust' >> /var/lib/postgresql/data/pg_hba.conf
        echo 'host all all ::/0 trust' >> /var/lib/postgresql/data/pg_hba.conf
    fi
    sed -i 's/scram-sha-256/trust/g' /var/lib/postgresql/data/pg_hba.conf 2>/dev/null || true
    su postgres -c '/usr/lib/postgresql/15/bin/pg_ctl reload -D /var/lib/postgresql/data'
" 2>/dev/null || log_warn "Could not configure pg_hba.conf (may already be configured)"

log_ok "PostgreSQL ready"

# Step 3: Start Elasticsearch
log_info "Starting Elasticsearch..."
docker compose up -d elasticsearch

# Step 4: Run OpenMetadata bootstrap migrations
log_info "Running OpenMetadata migrations (this takes ~1-2 minutes)..."
docker compose up -d openmetadata-bootstrap

# Wait for bootstrap to complete
for i in {1..60}; do
    status=$(docker inspect ems-openmetadata-bootstrap --format '{{.State.Status}}' 2>/dev/null || echo "running")
    if [[ "$status" == "exited" ]]; then
        log_ok "OpenMetadata migrations completed!"
        break
    fi
    echo -ne "\r  Bootstrap running... ($((i*5))s)"
    sleep 5
done
echo ""

# Check bootstrap result
if docker inspect ems-openmetadata-bootstrap --format '{{.State.ExitCode}}' 2>/dev/null | grep -qv "0"; then
    log_error "OpenMetadata bootstrap failed! Check logs: docker compose logs openmetadata-bootstrap"
    exit 1
fi

# Step 5: Start all remaining services
log_info "Starting all remaining services..."
docker compose up -d

# Step 6: Install OpenMetadata Airflow APIs
log_info "Installing OpenMetadata Airflow APIs..."
for i in {1..20}; do
    if docker exec ems-airflow-webserver airflow version &>/dev/null; then
        docker exec ems-airflow-webserver pip install --no-cache-dir openmetadata-ingestion[airflow-base] 2>/dev/null || true
        log_ok "OpenMetadata Airflow APIs installed!"
        break
    fi
    echo -n "."
    sleep 5
done
echo ""

# Wait for OpenMetadata to be ready
log_info "Waiting for OpenMetadata to be ready (~2-3 minutes)..."
for i in {1..60}; do
    if curl -sf http://localhost:8585/ >/dev/null 2>&1; then
        log_ok "OpenMetadata is ready!"
        break
    fi
    echo -ne "\r  Waiting... ($((i*5))s)"
    sleep 5
done
echo ""

# Summary
echo ""
log_info "=========================================="
log_info "EMS Data Platform - ALL Services Started"
log_info "=========================================="
echo ""

docker ps --format "  {{.Names}}: {{.Status}}" | grep ems | grep -v "Exited" | head -30

echo ""
log_info "Key Services:"
for port in 5432 5434 5435 5436 6379 6380 8585 8085 8088 8089 8090 9000 9001 9092 9200 27017 6333 8181; do
    case $port in
        5432) name="PostgreSQL (events)" ;;
        5434) name="PostgreSQL (airflow)" ;;
        5435) name="PostgreSQL (superset)" ;;
        5436) name="PostgreSQL (om)" ;;
        6379) name="Redis (auth)" ;;
        6380) name="Redis (no auth)" ;;
        8585) name="OpenMetadata" ;;
        8085) name="Airflow" ;;
        8088) name="Superset" ;;
        8089) name="Trino" ;;
        8090) name="Kafka UI" ;;
        9000) name="MinIO API" ;;
        9001) name="MinIO Console" ;;
        9092) name="Kafka" ;;
        9200) name="Elasticsearch" ;;
        27017) name="MongoDB" ;;
        6333) name="Qdrant" ;;
        8181) name="Iceberg REST" ;;
    esac
    if nc -z localhost $port 2>/dev/null; then
        echo -e "  ${GREEN}${name} (:${port}) OK${NC}"
    else
        echo -e "  ${YELLOW}${name} (:${port}) starting${NC}"
    fi
done

echo ""
log_info "Access URLs:"
echo "  OpenMetadata:   http://localhost:8585"
echo "  Airflow:       http://localhost:8085"
echo "  Superset:      http://localhost:8088"
echo "  Kafka UI:      http://localhost:8090"
echo "  Trino:         http://localhost:8089"
echo "  MinIO Console: http://localhost:9001"
echo "  Elasticsearch: http://localhost:9200"
echo "  Qdrant:        http://localhost:6333"
echo ""
log_info "Credentials:"
log_info "  OpenMetadata: admin@openmetadata.org / admin"
log_info "  Airflow:     admin / admin123"
log_info "  Superset:    admin / admin123"
log_info "  MinIO:       minioadmin / minioadmin123"
echo ""
log_info "Commands:"
echo "  docker compose logs -f        # All logs"
echo "  docker compose logs openmetadata  # OM logs"
echo "  docker compose down         # Stop all"
