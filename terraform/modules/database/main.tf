data "google_secret_manager_secret_version" "db_password_secret" {
  secret  = var.db_password_secret_name
  version = var.secret_version
  project = var.project_id
}

resource "google_sql_database_instance" "dvd_rental_sql_postgresql" {
  project         = var.project_id
  name            = "dvd-rental-${var.environment}-instance"
  region          = var.region
  database_version = "POSTGRES_15"

  depends_on = [
    var.datastream_vpc_id,
    var.private_vpc_connection_id # Wait for private connection
  ]

  settings {
    tier            = var.instance_tier
    disk_size       = var.disk_size
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
    
    ip_configuration {
      ipv4_enabled                        = false
      private_network                     = var.datastream_vpc_id
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled                 = var.backup_enabled
      start_time              = var.environment == "prod" ? "03:00" : "02:00"
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

resource "google_sql_database" "dvd_rental_db" {
  name     = var.database_name
  instance = google_sql_database_instance.dvd_rental_sql_postgresql.name
}

resource "google_sql_user" "dvd_rental_user" {
  name     = var.database_user_name
  instance = google_sql_database_instance.dvd_rental_sql_postgresql.name
  password = data.google_secret_manager_secret_version.db_password_secret.secret_data
}

resource "time_sleep" "wait_for_sql_instance" {
  depends_on = [
    google_sql_database_instance.dvd_rental_sql_postgresql,
    google_sql_database.dvd_rental_db,
    google_sql_user.dvd_rental_user
  ]
  create_duration = "600s" 
}

resource "null_resource" "configure_postgresql_for_datastream" {
  triggers = {
    sql_instance_id      = google_sql_database_instance.dvd_rental_sql_postgresql.id
    db_password_hash     = sensitive(data.google_secret_manager_secret_version.db_password_secret.secret_data)
    sql_instance_name    = google_sql_database_instance.dvd_rental_sql_postgresql.name
    project_id_trigger   = var.project_id
    region_trigger       = var.region
    db_user_name_trigger = var.database_user_name
    db_name_trigger      = var.database_name
  }

  depends_on = [
    google_sql_database_instance.dvd_rental_sql_postgresql,
    google_sql_database.dvd_rental_db,
    google_sql_user.dvd_rental_user,
    time_sleep.wait_for_sql_instance,
  ]

  provisioner "local-exec" {
    # Use templatefile to render the script, passing all necessary variables.
    # Terraform evaluates this *before* passing the final string to the shell.
    command = <<EOT
     OUTPUT_FILE="${path.module}/configure_postgresql_output.log"
     ${templatefile("${path.module}/configure_postgresql.sh.tpl", {
      project_id        = var.project_id
      region            = var.region
      sql_instance_name = google_sql_database_instance.dvd_rental_sql_postgresql.name
      db_user_name      = var.database_user_name
      db_name           = var.database_name
      db_password       = data.google_secret_manager_secret_version.db_password_secret.secret_data
      path_module       = path.module
      sql_instance_name = google_sql_database_instance.dvd_rental_sql_postgresql.name
      private_ip_address = google_sql_database_instance.dvd_rental_sql_postgresql.private_ip_address
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
    when = destroy
    command = "echo 'PostgreSQL configuration null_resource destroyed.'"
  }
}
# Output pour la dépendance du module datastream-stream
output "postgresql_setup_completed" {
  value = null_resource.configure_postgresql_for_datastream.id
  description = "A dependency indicator for PostgreSQL setup completion."
}
