# Récupère le mot de passe de la base de données depuis Secret Manager
data "google_secret_manager_secret_version" "db_password_secret" {
  secret  = var.db_password_secret_name
  project = var.project_id
}

# Create Cloud SQL PostgreSQL instance
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

    # Active le décodage logique pour Datastream
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

# Crée une base de données Cloud SQL
resource "google_sql_database" "dvd_rental_db" {
  name     = var.database_name
  instance = google_sql_database_instance.dvd_rental_sql_postgresql.name
}

# Crée un utilisateur de base de données avec la configuration appropriée pour Datastream
resource "google_sql_user" "dvd_rental_user" {
  name     = var.database_user_name
  instance = google_sql_database_instance.dvd_rental_sql_postgresql.name
  password = data.google_secret_manager_secret_version.db_password_secret.secret_data
}

# Attendre que l'instance Cloud SQL soit prête
resource "time_sleep" "wait_for_sql_instance" {
  depends_on = [
    google_sql_database_instance.dvd_rental_sql_postgresql,
    google_sql_database.dvd_rental_db,
    google_sql_user.dvd_rental_user
  ]
  create_duration = "120s" # Attendre 2 minutes pour que l'instance soit entièrement prête
}


/*
# Create a service account for the SQL proxy VM
resource "google_service_account" "sql_proxy_sa" {
  account_id   = "sql-proxy-${var.environment}"
  display_name = "SQL Proxy Service Account"
  project      = var.project_id
}

# Grant necessary permissions to the service account
resource "google_project_iam_member" "sql_proxy_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.sql_proxy_sa.email}"
}

# Update the compute instance to use the proper service account
resource "google_compute_instance" "sql_proxy" {
  name         = "sql-proxy-${var.environment}"
  machine_type = "e2-micro"
  zone         = "${var.region}-a"
  project      = var.project_id

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 10
    }
  }

  network_interface {
    network    = var.datastream_vpc_name
    subnetwork = var.datastream_subset_name
  }

  # Fixed service account configuration
  service_account {
    email  = google_service_account.sql_proxy_sa.email
    scopes = ["cloud-platform"]
  }

  tags = ["sql-proxy"]

  metadata_startup_script = <<-EOF
#!/bin/bash
apt-get update
apt-get install -y postgresql-client socat

# Create a service to forward connections to Cloud SQL
cat > /etc/systemd/system/sql-proxy.service << 'EOL'
[Unit]
Description=SQL Proxy Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/socat TCP4-LISTEN:5432,fork,reuseaddr TCP4:${google_sql_database_instance.dvd_rental_sql_postgresql.private_ip_address}:5432
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

systemctl enable sql-proxy.service
systemctl start sql-proxy.service
EOF
}
*/

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
    command = templatefile("${path.module}/configure_postgresql.sh.tpl", {
      project_id        = var.project_id
      region            = var.region
      sql_instance_name = google_sql_database_instance.dvd_rental_sql_postgresql.name
      db_user_name      = var.database_user_name
      db_name           = var.database_name
      db_password       = data.google_secret_manager_secret_version.db_password_secret.secret_data
      sql_script_path   = "${path.module}/setup_replication.sql"
      # You could also pass CLOUD_SQL_PROXY_PATH here if it needs to be dynamic
      # cloud_sql_proxy_path = "/usr/local/bin/cloud-sql-proxy"
    })
    
    # working_dir is set on the provisioner level, not in the template.
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
