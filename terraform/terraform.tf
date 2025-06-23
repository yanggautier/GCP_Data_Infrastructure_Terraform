# Terraform network configuration for GCP DVD Rental Data Infrastructure
resource "google_project_service" "service_networking_api" {
  project = var.project_id
  service = "servicenetworking.googleapis.com"
  disable_on_destroy = false
  
  timeouts {
    create = "15m"
    update = "15m"
  }
}

resource "google_project_service" "composer_api" {
  project = var.project_id
  service = "composer.googleapis.com"
}

# Create a Google Cloud Storage bucket
resource "google_storage_bucket" "dvd-rental-bucket" {
  name          = "dvd-rental-bucket-${var.environment}-${random_id.bucket_suffix.hex}"
  location      = var.region
  storage_class = "STANDARD"
  force_destroy = true

  uniform_bucket_level_access = true

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 30
    }
  }
  versioning {
    enabled = false
  }
}


resource "random_id" "bucket_suffix" {
  byte_length = 4
}

output "bucket_name" {
  value = google_storage_bucket.dvd-rental-bucket.name
}

output "bucket_self_link" {
  value = google_storage_bucket.dvd-rental-bucket.self_link
}

# Create a VPC network and subnetwork for Datastream
resource "google_compute_network" "datastream_vpc" {
  name                    = "datastream-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Define the CIDR range for the subnetwork
variable "subnetwork_address" {
  description = "CIDR range for the subnetwork"
  type        = string
  default     = "10.2.0.0/24"
}

# Create a subnetwork for Datastream
resource "google_compute_subnetwork" "datastream_subnet" {
  project       = var.project_id
  region        = var.region
  name          = "datastream-subnet"
  ip_cidr_range = var.subnetwork_address
  network       = google_compute_network.datastream_vpc.id
}

# Reserve IP range for private services (Cloud SQL)
resource "google_compute_global_address" "private_ip_alloc" {
  project       = var.project_id
  name          = "private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.datastream_vpc.id
}

# Create private service connection for Cloud SQL
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.datastream_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]

  depends_on = [google_project_service.service_networking_api]

  timeouts {
    create = "10m"
    delete = "10m"
  }
}

# Define the environment-specific configurations for Cloud SQL
locals {
  env_config = {
    dev = {
      instance_tier         = "db-f1-micro"
      disk_size             = 20
      backup_enabled        = false
      deletion_protection   = false
      max_replication_slots = 10
      max_wal_senders       = 10
    }
    staging = {
      instance_tier         = "db-custom-1-3840"
      disk_size             = 50
      backup_enabled        = true
      deletion_protection   = false
      max_replication_slots = 50
      max_wal_senders       = 50
    }
    prod = {
      instance_tier         = "db-custom-2-4096"
      disk_size             = 100
      backup_enabled        = true
      deletion_protection   = true
      max_replication_slots = 100
      max_wal_senders       = 100
    }
  }

  current_env = local.env_config[var.environment]
}

# Create a Cloud SQL PostgreSQL instance
resource "google_sql_database_instance" "dvd_rental_sql_postgresql" {
  project          = var.project_id
  name             = "dvd-rental-${var.environment}-instance"
  region           = var.region
  database_version = "POSTGRES_15"

  depends_on = [
    google_compute_network.datastream_vpc,
    google_service_networking_connection.private_vpc_connection
  ]
  
  settings {
    tier              = local.current_env.instance_tier
    disk_size         = local.current_env.disk_size
    availability_type = var.environment == "prod" ? "REGIONAL" : "ZONAL"
    activation_policy = "ALWAYS"
    
    user_labels = {
      network-tag = "cloudsql"
    }

    # Enable logical decoding for Datastream
    database_flags {
      name  = "cloudsql.logical_decoding"
      value = "on"
    }

    database_flags {
      name  = "max_replication_slots"
      value = tostring(local.current_env.max_replication_slots)
    }

    database_flags {
      name  = "max_wal_senders"
      value = tostring(local.current_env.max_wal_senders)
    }

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.datastream_vpc.id
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled                        = local.current_env.backup_enabled
      start_time                    = var.environment == "prod" ? "03:00" : "02:00"
      point_in_time_recovery_enabled = local.current_env.backup_enabled
      
      dynamic "backup_retention_settings" {
        for_each = local.current_env.backup_enabled ? [1] : []
        content {
          retained_backups = 7
          retention_unit   = "COUNT"
        }
      }
    }
  }
  
  deletion_protection = local.current_env.deletion_protection
}

output "cloud_sql_private_ip" {
  value = google_sql_database_instance.dvd_rental_sql_postgresql.private_ip_address
}

output "sql_proxy_ip" {
  value = google_compute_instance.sql_proxy.network_interface[0].network_ip
}

output "postgresql_setup_commands" {
  value = <<-EOF
    -- Connect to your PostgreSQL instance and run these commands:
    -- 1. Create the publication:
    CREATE PUBLICATION datastream_publication FOR ALL TABLES;
    
    -- 2. Create the replication slot:
    SELECT pg_create_logical_replication_slot('datastream_slot', 'pgoutput');
    
    -- 3. Verify the setup:
    SELECT slot_name, plugin, slot_type, active FROM pg_replication_slots;
    SELECT pubname FROM pg_publication;
    
    -- Connection command:
    psql "host=${google_sql_database_instance.dvd_rental_sql_postgresql.private_ip_address} port=5432 dbname=${var.database_name} user=${var.database_user_name}"
  EOF
}

# Create a Cloud SQL database
resource "google_sql_database" "dvd_rental_db" {
  name     = var.database_name
  instance = google_sql_database_instance.dvd_rental_sql_postgresql.name
}

# Get the database password from Secret Manager
data "google_secret_manager_secret_version" "db_password_secret" {
  secret  = "postgres-instance-password"
  project = var.project_id
}

# Create database user with proper configuration for Datastream
resource "google_sql_user" "dvd_rental_user" {
  name     = var.database_user_name
  instance = google_sql_database_instance.dvd_rental_sql_postgresql.name
  password = data.google_secret_manager_secret_version.db_password_secret.secret_data
}

# APIs activation
resource "google_project_service" "datastream_api" {
  project = var.project_id
  service = "datastream.googleapis.com"
  
  timeouts {
    create = "10m"
  }
}

resource "google_project_service" "bigquery_api" {
  project = var.project_id
  service = "bigquery.googleapis.com"
}

resource "google_project_service" "sqladmin_api" {
  project = var.project_id
  service = "sqladmin.googleapis.com"
}

# Create a service account for Datastream
resource "google_service_account" "datastream_service_account" {
  account_id   = "datastream-service-account"
  display_name = "Datastream Service Account"
  project      = var.project_id
}

# Assign roles to the Datastream service account
resource "google_project_iam_member" "datastream_admin" {
  project = var.project_id
  role    = "roles/datastream.admin"
  member  = "serviceAccount:${google_service_account.datastream_service_account.email}"
}

resource "google_project_iam_member" "bigquery_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.datastream_service_account.email}"
}

resource "google_project_iam_member" "cloud_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.datastream_service_account.email}"
}

resource "google_project_iam_member" "access_secret_manager" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.datastream_service_account.email}"
}

# Create a BigQuery dataset for DVD rental data
resource "google_bigquery_dataset" "dvd_rental_bigquery_dataset" {
  dataset_id  = "dvd_rental_bigquery_dataset"
  location    = var.region
  description = "Dataset for DVD rental data"

  labels = {
    environment = var.environment
    team        = "data-engineering"
  }

  # Define access controls for the dataset
  access {
    role          = "roles/bigquery.dataOwner"
    user_by_email = var.bigquery_owner_user
  }

  access {
    role          = "roles/bigquery.dataViewer"
    user_by_email = var.bigquery_analyst_user
  }

  access {
    role          = "roles/bigquery.dataEditor"
    user_by_email = var.bigquery_contributor_user
  }

  # Add service account access
  access {
    role          = "roles/bigquery.dataEditor"
    user_by_email = google_service_account.datastream_service_account.email
  }
}

# Create firewall rules for Datastream connectivity
resource "google_compute_firewall" "allow_datastream_to_sql" {
  name    = "allow-datastream-to-sql"
  network = google_compute_network.datastream_vpc.name
  project = var.project_id
  
  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  direction = "INGRESS"
  source_ranges = [
    "10.2.0.0/24",     # Datastream subnet
    "10.3.0.0/24",     # Private connection subnet
    "169.254.0.0/16",  # Google internal networking
    google_compute_global_address.private_ip_alloc.address
  ]

  target_tags = ["cloudsql"]
  priority    = 1000
}

# Allow internal VPC communication
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal-vpc"
  network = google_compute_network.datastream_vpc.name
  project = var.project_id
  
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  
  allow {
    protocol = "icmp"
  }

  direction     = "INGRESS"
  source_ranges = ["10.0.0.0/8"]
  priority      = 65534
}

# Create a Datastream private connection
resource "google_datastream_private_connection" "private_connection" {
  display_name          = "Datastream Private Connection"
  project               = var.project_id
  location              = var.region
  private_connection_id = "datastream-connection-${var.environment}"

  vpc_peering_config {
    vpc    = google_compute_network.datastream_vpc.id
    subnet = "10.3.0.0/24"
  }

  depends_on = [
    google_project_service.datastream_api,
    google_project_service.sqladmin_api,
    google_service_networking_connection.private_vpc_connection
  ]

  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }
}

output "bigquery_dataset_id" {
  description = "ID of the BigQuery dataset"
  value       = google_bigquery_dataset.dvd_rental_bigquery_dataset.id
}

# Wait for Cloud SQL instance to be ready
resource "time_sleep" "wait_for_sql_instance" {
  depends_on = [
    google_sql_database_instance.dvd_rental_sql_postgresql,
    google_sql_database.dvd_rental_db,
    google_sql_user.dvd_rental_user
  ]
  create_duration = "120s" # Wait 2 minutes for instance to be fully ready
}

# Create a reverse proxy VM for Cloud SQL access (required for private IP)
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
    network    = google_compute_network.datastream_vpc.name
    subnetwork = google_compute_subnetwork.datastream_subnet.name
    
    # No external IP needed
  }

  service_account {
    email  = google_service_account.datastream_service_account.email
    scopes = ["cloud-platform"]
  }

  tags = ["sql-proxy"]

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y postgresql-client
    
    # Install socat for port forwarding
    apt-get install -y socat
    
    # Create a service to forward connections to Cloud SQL
    cat > /etc/systemd/system/sql-proxy.service << 'EOL'
[Unit]
Description=SQL Proxy Service
After=network.target

[Service]
Type=simple
User=postgres
ExecStart=/usr/bin/socat TCP4-LISTEN:5432,fork,reuseaddr TCP4:${google_sql_database_instance.dvd_rental_sql_postgresql.private_ip_address}:5432
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

    # Create postgres user and start service
    useradd -m postgres || true
    systemctl enable sql-proxy.service
    systemctl start sql-proxy.service
  EOF

  depends_on = [
    google_sql_database_instance.dvd_rental_sql_postgresql,
    google_service_account.datastream_service_account
  ]
}

# Firewall rule for SQL proxy
resource "google_compute_firewall" "allow_datastream_to_proxy" {
  name    = "allow-datastream-to-proxy"
  network = google_compute_network.datastream_vpc.name
  project = var.project_id
  
  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  direction = "INGRESS"
  source_ranges = [
    "10.3.0.0/24"  # Datastream private connection subnet
  ]

  target_tags = ["sql-proxy"]
  priority    = 1000
}

# Create a Datastream connection profile for PostgreSQL source (via proxy)
resource "google_datastream_connection_profile" "source" {
  display_name          = "PostgreSQL Source Connection Profile"
  project               = var.project_id
  location              = var.region
  connection_profile_id = "postgresql-source-${var.environment}"

  postgresql_profile {
    hostname = google_compute_instance.sql_proxy.network_interface[0].network_ip
    port     = 5432
    database = var.database_name
    username = var.database_user_name
    password = data.google_secret_manager_secret_version.db_password_secret.secret_data
  }

  private_connectivity {
    private_connection = google_datastream_private_connection.private_connection.id
  }
  
  timeouts {
    create = "30m"
    update = "30m"
  }

  depends_on = [
    time_sleep.wait_for_sql_instance,
    google_compute_instance.sql_proxy,
    google_compute_firewall.allow_datastream_to_proxy,
    google_datastream_private_connection.private_connection
  ]
}

# Create a Datastream connection profile for BigQuery
resource "google_datastream_connection_profile" "destination" {
  display_name          = "BigQuery Destination Connection Profile"
  project               = var.project_id
  location              = var.region
  connection_profile_id = "bigquery-destination-${var.environment}"

  bigquery_profile {}

  private_connectivity {
    private_connection = google_datastream_private_connection.private_connection.id
  }

  depends_on = [
    google_project_service.datastream_api,
    google_bigquery_dataset.dvd_rental_bigquery_dataset,
    google_datastream_private_connection.private_connection
  ]
}

# NOTE: The Datastream stream should be created AFTER manually setting up
# the PostgreSQL publication and replication slot. See the output 'postgresql_setup_commands'
# for the required SQL commands to run first.



resource "google_project_service" "cloudbuild_api" {
  project = var.project_id
  service = "cloudbuild.googleapis.com"
}

resource "google_project_service" "run_api" {
  project = var.project_id
  service = "run.googleapis.com"
}

resource "google_project_service" "artifactregistry_api" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"
}

resource "google_project_service" "containerregistry_api" {
  project = var.project_id
  service = "containerregistry.googleapis.com"
}

# DBT repo
resource "google_storage_bucket" "dbt-bucket" {
  name          = "dbt-bucket-${var.environment}-${random_id.bucket_suffix.hex}"
  location      = var.region
  storage_class = "STANDARD"
  force_destroy = true

  uniform_bucket_level_access = true

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 30
    }
  }
  versioning {
    enabled = false
  }
}


resource "google_cloud_run_service" "dbt_runner" {
  name     = "dbt-runner"
  location = var.region
  project  = var.project_id

  template {
    spec {
      containers {
        image = "gcr.io/cloudrun/hello"  # temperory image, replace after by dbt image
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_service_account" "cloud_composer_service_account" {
  account_id   = "composer-service-account"
  display_name = "Cloud Composer Service Account"
}

resource "google_project_iam_member" "composer_worker_role" {
  project = var.project_id
  role    = "roles/composer.worker"
  member  = "serviceAccount:${google_service_account.cloud_composer_service_account.email}"
}

resource "google_project_iam_member" "composer_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloud_composer_service_account.email}"
}
resource "google_project_iam_member" "artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.cloud_composer_service_account.email}"
}


resource "google_artifact_registry_repository" "dbt_repo" {
  project  = var.project_id
  location = var.region
  repository_id = "dbt-images"
  format = "DOCKER"
}


resource "google_composer_environment" "dbt_orchestration" {
  name   = "composer-dbt-${var.environment}"
  region = var.region
  project = var.project_id

  depends_on = [ 
    google_project_iam_member.composer_sa_user,
    google_project_iam_member.composer_worker_role
  ]
  config {
    software_config {
      image_version = "composer-3-airflow-2.9.3"
    }

    environment_size = "ENVIRONMENT_SIZE_SMALL"

    workloads_config {
      scheduler {
        cpu        = 1
        memory_gb  = 2
        storage_gb = 1
      }

      web_server {
        cpu        = 1
        memory_gb  = 2
        storage_gb = 1
      }

      worker {
        cpu        = 1
        memory_gb  = 2
        storage_gb = 10
      }
    }

    node_config {
      service_account = "composer-service-account@${var.project_id}.iam.gserviceaccount.com"
    }
  }
}






