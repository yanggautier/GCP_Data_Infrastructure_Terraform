
# ------------------------------ Secret Manager ---------------------------------
# Get secret from Secrect Manager
data "google_secret_manager_secret_version" "business_db_password_secret" {
  secret  = var.business_db_password_secret_name
  version = var.business_secret_version
  project = var.project_id
}

data "google_secret_manager_secret_version" "superset_db_password_secret" {
  secret  = var.superset_db_password_secret_name
  version = var.superset_secret_version
  project = var.project_id
}

# ------------------------------ Creation of CloudSQL PostgreSQL ---------------------------------
# Creation of instance Cloud SQL PostgreSQL
resource "google_sql_database_instance" "postgresql_instance" {
  project          = var.project_id
  name             = "sql-${var.environment}-instance"
  region           = var.region
  database_version = "POSTGRES_15"

  depends_on = [
    var.vpc_id,
    var.private_vpc_connection_id # Wait for private connection
  ]

  settings {
    tier              = var.instance_tier
    disk_size         = var.disk_size
    availability_type = var.environment == "prod" ? "REGIONAL" : "ZONAL"
    activation_policy = "ALWAYS"

    database_flags {
      name  = "cloudsql.logical_decoding"
      value = "on"
    }

    database_flags {
      name  = "max_replication_slots"
      value = tostring(var.max_replication_slots)
    }

    database_flags {
      name  = "max_wal_senders"
      value = tostring(var.max_wal_senders)
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }

    ip_configuration {
      ipv4_enabled                                  = true
      private_network                               = var.vpc_id
      #private_network                              = var.vpc_id
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled                        = var.backup_enabled
      start_time                     = var.environment == "prod" ? "03:00" : "02:00"
      point_in_time_recovery_enabled = var.backup_enabled

      dynamic "backup_retention_settings" {
        for_each = var.backup_enabled ? [1] : []
        content {
          retained_backups = 7
          retention_unit   = "COUNT"
        }
      }
    }
  }
  deletion_protection = var.deletion_protection
}

# ------------------------------ Configuration for Superset database ---------------------------------
# Create a database in cloud sql instance for business
resource "google_sql_database" "business_db" {
  name     = var.business_database_name
  instance = google_sql_database_instance.postgresql_instance.name
}

# Creation of cloud sql user
resource "google_sql_user" "business_user" {
  name     = var.business_database_user_name
  instance = google_sql_database_instance.postgresql_instance.name
  password = data.google_secret_manager_secret_version.business_db_password_secret.secret_data

  depends_on = [
    google_sql_database_instance.postgresql_instance,
  google_sql_database.business_db]
}

resource "random_string" "postgres_password_gen" {
  length           = 16
  special          = true
  override_special = "!@#$%^&*"
}

# Add a time to wait sql intance to be ready
resource "time_sleep" "wait_for_sql_instance" {
  depends_on = [
    google_sql_database_instance.postgresql_instance,
    google_sql_database.business_db,
    google_sql_user.business_user
  ]
  create_duration = "600s"
}

resource "null_resource" "configure_postgresql_for_datastream" {
  triggers = {
    sql_instance_id      = google_sql_database_instance.postgresql_instance.id
    db_password_hash     = sensitive(data.google_secret_manager_secret_version.business_db_password_secret.secret_data)
    sql_instance_name    = google_sql_database_instance.postgresql_instance.name
    project_id_trigger   = var.project_id
    region_trigger       = var.region
    db_user_name_trigger = var.business_database_user_name
    db_name_trigger      = var.business_database_name
  }

  depends_on = [
    google_sql_database_instance.postgresql_instance,
    google_sql_database.business_db,
    google_sql_user.business_user,
    time_sleep.wait_for_sql_instance,
  ]

  provisioner "local-exec" {
    # Use templatefile to render the script, passing all necessary variables.æ
    # Terraform evaluates this *before* passing the final string to the shell.
    command = <<EOT
     OUTPUT_FILE="${path.module}/configure_postgresql_output.log"
     ${templatefile("${path.module}/configure_postgresql.sh.tpl", {
    project_id         = var.project_id
    region             = var.region
    sql_instance_name  = google_sql_database_instance.postgresql_instance.name
    db_user_name       = var.business_database_user_name
    db_name            = var.business_database_name
    db_password        = data.google_secret_manager_secret_version.business_db_password_secret.secret_data
    PATH_MODULE        = "${path.module}"
    postgres_password  = random_string.postgres_password_gen.result
    sql_instance_name  = google_sql_database_instance.postgresql_instance.name
    private_ip_address = google_sql_database_instance.postgresql_instance.private_ip_address
})} > "$OUTPUT_FILE" 2>&1

      # Affiche le contenu du fichier pour que Cloud Build le capture
      echo "--- configure_postgresql.sh.tpl output ---"
      cat "$OUTPUT_FILE"
      echo "-----------------------------------------"

      # Vérifie le code de sortie du script (important pour détecter les échecs)
      if [ $? -ne 0 ]; then
        echo "ERROR: configure_postgresql.sh.tpl failed. Check logs above."
        exit 1
      fi
    EOT
working_dir = path.module
}

provisioner "local-exec" {
  when    = destroy
  command = "echo 'PostgreSQL configuration null_resource destroyed.'"
}
}
# Output pour la dépendance du module datastream-stream
output "postgresql_setup_completed" {
  value       = null_resource.configure_postgresql_for_datastream.id
  description = "A dependency indicator for PostgreSQL setup completion."
}

# ------------------------------ Configuration for Superset database ---------------------------------
# Create a database in cloud sql instance for business
resource "google_sql_database" "superset_db" {
  name     = var.superset_database_name
  instance = google_sql_database_instance.postgresql_instance.name
}

# Creation of cloud sql user
resource "google_sql_user" "superset_db_admin_user" {
  name     = var.superset_database_user_name
  instance = google_sql_database_instance.postgresql_instance.name
  password = data.google_secret_manager_secret_version.business_db_password_secret.secret_data

  depends_on = [
    google_sql_database_instance.postgresql_instance,
  google_sql_database.superset_db]
}

# ------------------------------ Configuration for Memorystore ----------------------------------
resource "google_redis_instance" "superset_redis_cache" {
  name           = "superset-redis-cache-${var.environment}"
  tier           = var.redis_instance_tier
  memory_size_gb = var.redis_memory_size_gb
  region         = var.region
  project        = var.project_id
  connect_mode   = "DIRECT_PEERING"
  #location_id    = var.region

  lifecycle {
    prevent_destroy = false
  }
  # Specify the VPC for the project
  authorized_network = "projects/${var.project_id}/global/networks/${var.vpc_name}"
}