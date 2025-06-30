#!/bin/bash
set -e

# Variables
PROJECT_ID="${project_id}"
REGION="${region}"
SQL_INSTANCE_NAME="${sql_instance_name}"
DB_USER_NAME="${db_user_name}"
DB_NAME="${db_name}"
DB_PASSWORD="${db_password}"
CLOUD_SQL_PRIVATE_IP="${private_ip_address}" # Cette variable n'est pas directement utilisée pour la connexion via PROXY_PORT localement

# --- Démarrage du Cloud SQL Proxy ---
# Définir un port local pour le proxy
LOCAL_PROXY_PORT=5432
# Le nom de l'instance Cloud SQL au format attendu par le proxy
# C'est généralement project_id:region:instance_name
CLOUD_SQL_PROXY_INSTANCE_NAME="$PROJECT_ID:$REGION:$SQL_INSTANCE_NAME"

echo "Starting Cloud SQL Proxy for instance: $CLOUD_SQL_PROXY_INSTANCE_NAME on port $LOCAL_PROXY_PORT..."
# Télécharger le proxy si pas déjà fait (bonne pratique pour les scripts auto-suffisants)
if ! command -v cloud_sql_proxy &> /dev/null
then
    echo "cloud_sql_proxy not found. Downloading..."
    wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O /usr/local/bin/cloud_sql_proxy
    chmod +x /usr/local/bin/cloud_sql_proxy
fi

# Démarrer le proxy en arrière-plan
# Authentification via les credentials de l'environnement Cloud Build
/usr/local/bin/cloud_sql_proxy -instances="$CLOUD_SQL_PROXY_INSTANCE_NAME"=tcp:"$LOCAL_PROXY_PORT" &
PROXY_PID=$! # Stocker le PID du proxy
echo "Cloud SQL Proxy started with PID: $PROXY_PID"

# Attendre que le proxy soit prêt à écouter
echo "Waiting for Cloud SQL Proxy to be ready on 127.0.0.1:$LOCAL_PROXY_PORT..."
timeout=60
for i in $(seq 1 $timeout); do
  nc -z -w 1 127.0.0.1 "$LOCAL_PROXY_PORT" && break
  echo "Proxy port $LOCAL_PROXY_PORT not open yet, retrying in 1 second..."
  sleep 1
  if [ "$i" -eq "$timeout" ]; then
    echo "Timeout waiting for Cloud SQL Proxy to be ready. Aborting."
    kill $PROXY_PID || true
    exit 1
  fi
done
echo "Cloud SQL Proxy is ready."

# --- Fin Démarrage du Cloud SQL Proxy ---

# Wait for the database instance to be reachable (via the proxy now)
# The previous check on CLOUD_SQL_PRIVATE_IP is less relevant now as we connect via proxy
# You can remove the direct IP check or keep it as an additional safeguard.
# For simplicity, let's just rely on the proxy now.

echo "Granting REPLICATION role to $DB_USER_NAME using postgres user via proxy..."
# Connect to the local proxy port, which forwards to Cloud SQL
# Use PGPASSWORD environment variable for the 'postgres' superuser (if it has a password set)
# Or, if using IAM database authentication for 'postgres', no password needed.
# For simplicity and robustnes, if your 'postgres' user doesn't have a password set, you don't need PGPASSWORD here.
# If 'postgres' user has a password, define PGPASSWORD. For Cloud SQL, 'postgres' user is usually created without a password if not explicitly set.
# Assuming 'postgres' user doesn't require a password for proxy connection here.
psql "host=127.0.0.1 port=$LOCAL_PROXY_PORT user=postgres dbname=postgres" -c "ALTER USER \"$DB_USER_NAME\" WITH REPLICATION;"
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to grant REPLICATION role to $DB_USER_NAME." >&2
  kill $PROXY_PID || true # Kill the proxy on error
  exit 1
fi
echo "REPLICATION role granted to $DB_USER_NAME."

# --- Arrêter le proxy une fois les opérations de super-utilisateur terminées ---
echo "Stopping Cloud SQL Proxy (PID: $PROXY_PID)..."
kill $PROXY_PID
wait $PROXY_PID || true # Attendre la terminaison du proxy, ignorer les erreurs si déjà mort
echo "Cloud SQL Proxy stopped."

# PostgreSQL Configuration for Datastream user
# The Cloud SQL Proxy is no longer running at this point for the following connections.
# This means the subsequent psql commands must connect directly to the private IP.
# If Cloud Build environment (private worker pool) has direct access to the VPC,
# and thus to the private IP of Cloud SQL, this will work.
# If not, you'd need to keep the proxy running for all psql commands.
# Given your existing setup, it implies direct VPC access for subsequent steps.

export PGPASSWORD="$DB_PASSWORD"
DB_CONNECTION_STRING="host=$CLOUD_SQL_PRIVATE_IP port=5432 user=$DB_USER_NAME dbname=$DB_NAME"

echo "Connecting to PostgreSQL and executing publication setup..."
# Ensure the setup_replication.sql is idempotent or handles existing publications
psql "$DB_CONNECTION_STRING" -f "${path_module}/setup_replication.sql"
if [ $? -ne 0 ]; then
  echo "ERROR: PostgreSQL publication setup failed." >&2
  exit 1
fi
echo "PostgreSQL publication setup completed."

echo "Connecting to PostgreSQL and checking/dropping existing replication slot..."
psql "$DB_CONNECTION_STRING" -f "${path_module}/drop_replication_slot.sql"
if [ $? -ne 0 ]; then
  echo "ERROR: Dropping existing replication slot failed." >&2
  exit 1
fi
echo "Existing replication slot checked/dropped."

echo "Connecting to PostgreSQL and creating logical replication slot..."
# This call MUST be separate to ensure a clean transaction context.
psql "$DB_CONNECTION_STRING" -f "${path_module}/create_replication_slot.sql"
if [ $? -ne 0 ]; then
  echo "ERROR: Logical replication slot creation failed." >&2
  exit 1
fi
echo "Logical replication slot created successfully."


echo "PostgreSQL setup completed successfully."
echo "No cleanup needed."