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

# Stop any existing containers
log_info "Stopping existing containers..."
docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true

# Start ALL services
log_info "Starting all services (this may take a few minutes)..."
docker compose up -d 2>/dev/null || docker-compose up -d 2>/dev/null

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
log_info "EMS Data Platform - ALL Services Started"
log_info "=========================================="
echo ""

docker ps --format "  {{.Names}}: {{.Status}}" | grep ems | grep -v "Exited" | head -25

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
        echo -e "  ${RED}${name} (:${port}) FAIL${NC}"
    fi
done

echo ""
log_info "Access URLs:"
echo "  OpenMetadata:   http://localhost:8585"
echo "  Airflow:        http://localhost:8085"
echo "  Superset:       http://localhost:8088"
echo "  Kafka UI:       http://localhost:8090"
echo "  Trino:          http://localhost:8089"
echo "  MinIO Console:  http://localhost:9001"
echo "  Elasticsearch:  http://localhost:9200"
echo "  Qdrant:         http://localhost:6333"
echo ""
log_info "Credentials: admin / admin123 (for OpenMetadata, Airflow, Superset)"
echo ""
log_info "Full status: docker ps"
log_info "Logs: docker logs <container-name>"
