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

log_info "Starting EMS Data Platform..."
log_info "Using PostgreSQL for OpenMetadata (not MySQL)"

# Stop any existing containers
log_info "Stopping existing containers..."
docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true

# Start core infrastructure first (essential for DE)
CORE_SERVICES="postgres-om postgres-events redis redis-local kafka zookeeper schema-registry elasticsearch"
log_info "Starting core services..."
docker compose up -d $CORE_SERVICES 2>/dev/null || docker-compose up -d $CORE_SERVICES 2>/dev/null

# Wait for databases to be ready
log_info "Waiting for databases to be ready..."
for i in {1..30}; do
    if docker exec ems-postgres-om pg_isready -U openmetadata &>/dev/null && \
       docker exec ems-postgres-events pg_isready -U emsuser &>/dev/null; then
        log_ok "Databases ready!"
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

# Start OpenMetadata
log_info "Starting OpenMetadata..."
docker compose up -d openmetadata 2>/dev/null || docker-compose up -d openmetadata 2>/dev/null

# Start data services
DATA_SERVICES="trino minio mc iceberg-rest kafka-ui"
log_info "Starting data services (Trino, MinIO, Iceberg)..."
docker compose up -d $DATA_SERVICES 2>/dev/null || docker-compose up -d $DATA_SERVICES 2>/dev/null

# Wait for OpenMetadata to be healthy
log_info "Waiting for OpenMetadata (this takes ~2-3 minutes on first start)..."
for i in {1..60}; do
    if curl -sf http://localhost:8585/healthcheck &>/dev/null; then
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
log_info "EMS Data Platform - All Started"
log_info "=========================================="
echo ""

docker ps --format "  {{.Names}}: {{.Status}}" | grep ems | grep -v "Exited" | head -20

echo ""
log_info "Key Services:"
for port in 5432 6379 6380 8585 8089 9092 8090 9000 9001 9200; do
    case $port in
        5432) name="PostgreSQL (events)" ;;
        6379) name="Redis (auth)" ;;
        6380) name="Redis (no auth)" ;;
        8585) name="OpenMetadata" ;;
        8089) name="Trino" ;;
        9092) name="Kafka" ;;
        8090) name="Kafka UI" ;;
        9000) name="MinIO API" ;;
        9001) name="MinIO Console" ;;
        9200) name="Elasticsearch" ;;
    esac
    if nc -z localhost $port 2>/dev/null; then
        echo -e "  ${GREEN}${name} (:${port}) OK${NC}"
    else
        echo -e "  ${RED}${name} (:${port}) FAIL${NC}"
    fi
done

echo ""
log_info "Access URLs:"
echo "  OpenMetadata:   http://localhost:8585"
echo "  Kafka UI:       http://localhost:8090"
echo "  Trino:          http://localhost:8089"
echo "  MinIO Console:  http://localhost:9001 (minioadmin/minioadmin123)"
echo ""
log_info "Full status: docker ps"
log_info "Logs: docker logs <container-name>"
echo ""
log_info "To start optional services (Airflow, Spark, NiFi):"
log_info "  docker compose --profile full up -d"
