#!/bin/bash
set -e

# Variables
PROJECT_ID="${project_id}"
REGION="${region}"
SQL_INSTANCE_NAME="${sql_instance_name}"
DB_USER_NAME="${db_user_name}"
DB_NAME="${db_name}"
DB_PASSWORD="${db_password}"
SQL_SCRIPT_PATH="${sql_script_path}"

# Path of Cloud SQL Proxy (Verify with 'which cloud-sql-proxy' on your machine)
CLOUD_SQL_PROXY_BIN="/usr/local/bin/cloud-sql-proxy"

# Verify if proxy executing
if pgrep -f "$CLOUD_SQL_PROXY_BIN $PROJECT_ID:$REGION:$SQL_INSTANCE_NAME.*-p 5432 --private-ip" > /dev/null; then
    echo "Cloud SQL Proxy for $SQL_INSTANCE_NAME is already running."
    PROXY_PID=$(pgrep -f "$CLOUD_SQL_PROXY_BIN $PROJECT_ID:$REGION:$SQL_INSTANCE_NAME.*-p 5432 --private-ip" | head -n 1)
else
    echo "Starting Cloud SQL Proxy for $SQL_INSTANCE_NAME..."
    # Launch proxy
    "$CLOUD_SQL_PROXY_BIN" "$PROJECT_ID:$REGION:$SQL_INSTANCE_NAME" -p 5432 --private-ip&
    PROXY_PID=$!
    echo "Cloud SQL Proxy started with PID: $PROXY_PID"

    # Wait for proxy
    echo "Waiting for Cloud SQL Proxy to become available on 127.0.0.1:5432..."
    timeout=60
    for i in $(seq 1 $timeout); do
      nc -z 127.0.0.1 5432 && break
      echo "Port 5432 not open yet, retrying in 1 second..."
      sleep 1
      if [ "$i" -eq "$timeout" ]; then
        echo "Timeout waiting for Cloud SQL Proxy. Aborting."
        kill $PROXY_PID || true
        exit 1
      fi
    done
    echo "Cloud SQL Proxy is listening on 127.0.0.1:5432."
fi

# PostgreSQL Configuration
export PGPASSWORD="$DB_PASSWORD"
echo "Connecting to PostgreSQL and executing $SQL_SCRIPT_PATH..."
psql "host=127.0.0.1 port=5432 user=$DB_USER_NAME dbname=$DB_NAME" \
     -f "$SQL_SCRIPT_PATH"

if [ $? -eq 0 ]; then
  echo "PostgreSQL setup completed successfully."
else
  echo "PostgreSQL setup failed. Check logs above."
  exit 1
fi

# Cleaning
if [ -n "$PROXY_PID" ]; then
  echo "Killing Cloud SQL Proxy (PID: $PROXY_PID)..."
  kill "$PROXY_PID" || true
fi