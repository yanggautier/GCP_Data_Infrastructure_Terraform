#!/bin/bash
set -e

# Variables
PROJECT_ID="${project_id}"
REGION="${region}"
SQL_INSTANCE_NAME="${sql_instance_name}"
DB_USER_NAME="${db_user_name}"
DB_NAME="${db_name}"
DB_PASSWORD="${db_password}"
CLOUD_SQL_PRIVATE_IP="${private_ip_address}"
PATH_MODULE="${path_module}"

# Get the private IP address of the Cloud SQL instance
echo "Retrieving private IP for Cloud SQL instance: $SQL_INSTANCE_NAME..."
if [ -z "$CLOUD_SQL_PRIVATE_IP" ]; then
  echo "Error: Could not retrieve private IP for instance $SQL_INSTANCE_NAME."
  exit 1
fi

echo "Cloud SQL instance private IP: $CLOUD_SQL_PRIVATE_IP"

# Wait for the database instance to be reachable on its private IP
# Cloud Build ayant une connectivité directe, cette attente est plus fiable.
echo "Waiting for PostgreSQL instance to be reachable on $CLOUD_SQL_PRIVATE_IP:5432..."
timeout=180 # Increased timeout for network readiness
for i in $(seq 1 $timeout); do
  nc -z -w 1 "$CLOUD_SQL_PRIVATE_IP" 5432 && break
  echo "Port 5432 not open yet on $CLOUD_SQL_PRIVATE_IP, retrying in 1 second..."
  sleep 1
  if [ "$i" -eq "$timeout" ]; then
    echo "Timeout waiting for Cloud SQL instance to be reachable. Aborting."
    exit 1
  fi
done
echo "PostgreSQL instance is reachable on $CLOUD_SQL_PRIVATE_IP:5432."

# Granting REPLICATION role to $DB_USER_NAME using postgres user via gcloud sql connect.
# This command handles authentication (including IAM) and proxying internally,
# making it suitable for Cloud Build environments. The Cloud Build service account
# must have appropriate IAM roles (e.g., roles/cloudsql.client) to connect.
echo "Granting REPLICATION role to $DB_USER_NAME using postgres user via gcloud sql connect..."
gcloud sql connect "$SQL_INSTANCE_NAME" \
  --user=postgres \
  --database=postgres \
  --quiet \
  --project="$PROJECT_ID" \
  --no-browser \
  --force-tcp \
  -- \
  -c "ALTER USER \"$DB_USER_NAME\" WITH REPLICATION;"
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to grant REPLICATION role to $DB_USER_NAME using gcloud sql connect." >&2
  exit 1
fi
echo "REPLICATION role granted to $DB_USER_NAME."


# PostgreSQL Configuration
export PGPASSWORD="$DB_PASSWORD"
DB_CONNECTION_STRING="host=$CLOUD_SQL_PRIVATE_IP port=5432 user=$DB_USER_NAME dbname=$DB_NAME"


echo "Connecting to PostgreSQL and executing publication setup..."
psql "$DB_CONNECTION_STRING" -f "${PATH_MODULE}/setup_replication.sql"
if [ $? -ne 0 ]; then
  echo "ERROR: PostgreSQL publication setup failed." >&2
  exit 1
fi
echo "PostgreSQL publication setup completed."

echo "Connecting to PostgreSQL and checking/dropping existing replication slot..."
psql "$DB_CONNECTION_STRING" -f "${PATH_MODULE}/drop_replication_slot.sql"
if [ $? -ne 0 ]; then
  echo "ERROR: Dropping existing replication slot failed." >&2
  exit 1
fi
echo "Existing replication slot checked/dropped."


echo "Connecting to PostgreSQL and creating logical replication slot..."
# This call MUST be separate to ensure a clean transaction context.
psql "$DB_CONNECTION_STRING" -f "${PATH_MODULE}/create_replication_slot.sql"
if [ $? -ne 0 ]; then
  echo "ERROR: Logical replication slot creation failed." >&2
  exit 1
fi
echo "Logical replication slot created successfully."


echo "PostgreSQL setup completed successfully."
echo "No cleanup needed."
