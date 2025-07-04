#!/bin/bash

# Variables
PROJECT_ID="${project_id}"
REGION="${region}"
SQL_INSTANCE_NAME="${sql_instance_name}"
DB_USER_NAME="${db_user_name}"
DB_NAME="${db_name}"
DB_PASSWORD="${db_password}"
POSTGRES_PASSWORD="${postgres_password}" # Variable for postgres user password
CLOUD_SQL_PRIVATE_IP="${private_ip_address}" # Not directly used for proxy, but kept for consistency
PATH_MODULE="${PATH_MODULE}"

# --- Cloud SQL Auth Proxy Configuration ---
PROXY_PORT=5432 # Default PostgreSQL port, proxy will listen on localhost:5432
PROXY_BINARY="cloud_sql_proxy"
PROXY_URL="https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64" # For Linux AMD64 workers

# Ensure the proxy binary is available
if [ ! -f "$PROXY_BINARY" ]; then
  echo "Downloading Cloud SQL Auth Proxy..."
  # Try to download with curl first, as it's often available in Cloud Build environments
  if command -v curl >/dev/null 2>&1; then
    curl -o "$PROXY_BINARY" "$PROXY_URL"
  elif command -v wget >/dev/null 2>&1; then
    # Fallback to wget if curl is not found
    wget "$PROXY_URL" -O "$PROXY_BINARY"
  else
    echo "ERROR: Neither curl nor wget found. Please ensure one is installed in your Cloud Build environment." >&2
    exit 1
  fi

  chmod +x "$PROXY_BINARY"
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to make Cloud SQL Auth Proxy executable." >&2
    exit 1
  fi
fi

# --- Set password for 'postgres' user ---
# This is a critical step to ensure the 'postgres' user has a password that can be used.
# The Cloud Build service account needs Cloud SQL Admin role for this.
echo "Setting password for 'postgres' user using gcloud sql users set-password..."
gcloud sql users set-password postgres --host=% \
  --instance="$SQL_INSTANCE_NAME" \
  --password="$POSTGRES_PASSWORD" \
  --project="$PROJECT_ID"
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to set password for 'postgres' user." >&2
  exit 1
fi
echo "Password for 'postgres' user set successfully."


# Start the Cloud SQL Auth Proxy in the background
# The proxy will connect to the instance using its instance connection name
# and listen on localhost:5432.
# Using --private-ip to force connection via private IP if instance has both.
# Removed -enable_iam_login as it's primarily for IAM-enabled DB users, not the default 'postgres' superuser.
echo "Starting Cloud SQL Auth Proxy for instance $PROJECT_ID:$REGION:$SQL_INSTANCE_NAME..."
./"$PROXY_BINARY" -instances="$PROJECT_ID:$REGION:$SQL_INSTANCE_NAME"=tcp:127.0.0.1:"$PROXY_PORT" -ip_address_types=PRIVATE &
PROXY_PID=$! # Get the process ID of the proxy

# Wait for the proxy to be ready
echo "Waiting for Cloud SQL Auth Proxy to start on localhost:$PROXY_PORT..."
timeout=60 # Wait up to 60 seconds for the proxy
for i in $(seq 1 $timeout); do
  nc -z -w 1 127.0.0.1 "$PROXY_PORT" && break
  echo "Proxy port $PROXY_PORT not open yet, retrying in 1 second..."
  sleep 1
  if [ "$i" -eq "$timeout" ]; then
    echo "Timeout waiting for Cloud SQL Auth Proxy to be ready. Aborting."
    kill "$PROXY_PID" # Kill the proxy process
    exit 1
  fi
done
echo "Cloud SQL Auth Proxy is ready."

# --- PostgreSQL Configuration ---
# Export PGPASSWORD for the 'postgres' user for the ALTER USER command
export PGPASSWORD="$POSTGRES_PASSWORD"

# Granting REPLICATION role to $DB_USER_NAME using postgres user directly with psql,
# connecting via the local Cloud SQL Auth Proxy.
# We connect as 'postgres' user to the 'postgres' database to perform this administrative task.
echo "Granting REPLICATION role to $DB_USER_NAME using postgres user via Cloud SQL Auth Proxy..."
psql "host=127.0.0.1 port=$PROXY_PORT user=postgres dbname=postgres" -c "ALTER USER \"$DB_USER_NAME\" WITH REPLICATION;"
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to grant REPLICATION role to $DB_USER_NAME." >&2
  kill "$PROXY_PID" # Kill the proxy process on failure
  exit 1
fi
echo "REPLICATION role granted to $DB_USER_NAME."

# Now set PGPASSWORD for the 'dvd_rental_user' for subsequent calls
export PGPASSWORD="$DB_PASSWORD"
DB_CONNECTION_STRING="host=127.0.0.1 port=$PROXY_PORT user=$DB_USER_NAME dbname=$DB_NAME"


echo "Connecting to PostgreSQL and executing publication setup..."
psql "$DB_CONNECTION_STRING" -f "${PATH_MODULE}/setup_replication.sql"
if [ $? -ne 0 ]; then
  echo "ERROR: PostgreSQL publication setup failed." >&2
  kill "$PROXY_PID" # Kill the proxy process on failure
  exit 1
fi
echo "PostgreSQL publication setup completed."

echo "Connecting to PostgreSQL and checking/dropping existing replication slot..."
psql "$DB_CONNECTION_STRING" -f "${PATH_MODULE}/drop_replication_slot.sql"
if [ $? -ne 0 ]; then
  echo "ERROR: Dropping existing replication slot failed." >&2
  kill "$PROXY_PID" # Kill the proxy process on failure
  exit 1
fi
echo "Existing replication slot checked/dropped."


echo "Connecting to PostgreSQL and creating logical replication slot..."
# This call MUST be separate to ensure a clean transaction context.
psql "$DB_CONNECTION_STRING" -f "${PATH_MODULE}/create_replication_slot.sql"
if [ $? -ne 0 ]; then
  echo "ERROR: Logical replication slot creation failed." >&2
  kill "$PROXY_PID" # Kill the proxy process on failure
  exit 1
fi
echo "Logical replication slot created successfully."


echo "PostgreSQL setup completed successfully."

# Always kill the proxy process at the end
echo "Stopping Cloud SQL Auth Proxy..."
kill "$PROXY_PID"
if [ $? -ne 0 ]; then
  echo "WARNING: Failed to kill Cloud SQL Auth Proxy process $PROXY_PID." >&2
fi
echo "No cleanup needed."
