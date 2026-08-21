#!/bin/bash
set -e

# Wait for initdb to complete
until [ -f /var/lib/postgresql/data/postgresql.conf ]; do
    sleep 1
done

# Wait a bit more for initdb to finish
sleep 2

# Modify pg_hba.conf to use trust for Docker network
sed -i 's/scram-sha-256/trust/g' /var/lib/postgresql/data/pg_hba.conf

# Reload PostgreSQL config
pg_ctl reload -D /var/lib/postgresql/data

exec docker-entrypoint.sh postgres
