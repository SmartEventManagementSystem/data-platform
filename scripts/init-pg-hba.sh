#!/bin/bash
set -e

# Wait for PostgreSQL to be ready
until PGPASSWORD=openmetadata123 psql -h postgres-om -U openmetadata -d openmetadata_db -c '\q' 2>/dev/null; do
    echo "Waiting for PostgreSQL to be ready..."
    sleep 2
done

echo "PostgreSQL is ready. Modifying pg_hba.conf..."

# Modify pg_hba.conf to use trust for all connections
sed -i 's/scram-sha-256/trust/g' /var/lib/postgresql/data/pg_hba.conf

# Reload PostgreSQL config
pg_ctl reload -D /var/lib/postgresql/data

echo "pg_hba.conf modified and reloaded."
