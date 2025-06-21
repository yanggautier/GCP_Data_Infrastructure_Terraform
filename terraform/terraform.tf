# Create a Google Cloud Storage bucket
resource "google_storage_bucket" "dvd-rental-bucket" {
  name          = "dvd-rental-bucket"
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
    enabled = false # Deactivate versioning
  }
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
  default     = "10.0.0.0/24"
}

# Create a subnetwork for Datastream
resource "google_compute_subnetwork" "datastream_subnet" {
  project       = var.project_id
  region        = var.region
  name          = "datastream-subnet"
  ip_cidr_range = var.subnetwork_address
  network       = google_compute_network.datastream_vpc.id
}

# Define the environment-specific configurations for Cloud SQL
locals {
  env_config = {
    dev = {
      instance_tier         = "db-f1-micro"
      disk_size             = 20
      backup_enabled        = false
      deletion_protection   = false
      max_replication_slots = 2
    }
    staging = {
      instance_tier         = "db-custom-1-3840"
      disk_size             = 50
      backup_enabled        = true
      deletion_protection   = false
      max_replication_slots = 5
    }
    prod = {
      instance_tier         = "db-custom-2-4096"
      disk_size             = 100
      backup_enabled        = true
      deletion_protection   = true
      max_replication_slots = 10
    }
  }

  current_env = local.env_config[var.environment]
}

# Create a Cloud SQL PostgreSQL instance
resource "google_sql_database_instance" "dvd-rental-sql-postgresql" {
  project          = var.project_id
  name             = "dvd-rental-${var.environment}-instance"
  region           = var.region
  database_version = "POSTGRES_15"

  settings {
    tier              = local.current_env.instance_tier
    activation_policy = var.environment == "prod" ? "REGIONAL" : "ZONAL"
    disk_size         = local.current_env.disk_size
    disk_type         = var.environment == "prod" ? "pd-ssd" : "pd-standard"

    database_flags {
      name  = "wal_level"
      value = "logical"
    }

    database_flags {
      name  = "max_replication_slots"
      value = local.current_env.max_replication_slots
    }

    backup_configuration {
      enabled    = local.current_env.backup_enabled
      start_time = var.environment == "prod" ? "03:00" : "02:00"
    }

  }
  deletion_protection = local.current_env.deletion_protection
}

# Create a Cloud SQL database
resource "google_sql_database" "dvd_rental_db" {
  name     = var.database_name
  instance = google_sql_database_instance.dvd-rental-sql-postgresql.name
}

# Create a secret in Secret Manager for the database password
data "google_secret_manager_secret_version" "db_password_secret" {
  secret  = "postgres-instance-password" #replace with your secret name
  project = "dvd-rental-project"         # replace with your GCP project ID)
}

resource "google_sql_user" "dvd_rental_user" {
  name                = var.darabase_user_name
  instance            = google_sql_database_instance.dvd-rental-sql-postgresql.name
  password_wo         = data.google_secret_manager_secret_version.db_password_secret.secret_data
  password_wo_version = data.google_secret_manager_secret_version.db_password_secret.version
}

# APIs activation
resource "google_project_service" "datastream_api" {
  project = var.project_id
  service = "datastream.googleapis.com"
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
resource "google_project_iam_member" "datatream_admin" {
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

variable "private_connection_address" {
  description = "Private IP address for the Datastream connection profile"
  type        = string
  default     = "10.1.0.0/24" # Adjust the subnet as needed
}

# Create a BigQuery dataset for DVD rental data
resource "google_bigquery_dataset" "dvd_rental_bigquery_dataset" {
  dataset_id  = "dvd_rental_bigquery_dataset"
  location    = var.region
  description = "Dataset for DVD rental data"

  labels = {
    environment = "production"
    team        = "data-engineering"
  }

  # Define access controls for the dataset
  access {
    role          = "OWNER"
    user_by_email = var.bigquery_owner_user # Replace with your email
  }

  access {
    role          = "READER"
    user_by_email = var.bigquery_analyst_user # Replace with your email
  }

  access {
    role          = "CONTRIBUTOR"
    user_by_email = var.bigquery_contributor_user # Replace with your email
  }

}

# Create a Datastream connection profile for Cloud SQL
resource "google_datastream_private_connection" "private_connection" {
  display_name          = "Datastream Connection Profile"
  project               = var.project_id
  location              = var.region
  private_connection_id = "datastream-connection-profile-${var.environment}"

  vpc_peering_config {
    vpc    = google_compute_network.datastream_vpc.id
    subnet = var.private_connection_address
  }

  depends_on = [
    google_project_service.datastream_api,
    google_project_service.sqladmin_api
  ]
}

output "bigquery_dataset_id" {
  description = "ID of the BigQuery dataset"
  value       = google_bigquery_dataset.dvd_rental_bigquery_dataset.id
}


resource "google_datastream_connection_profile" "source" {
  display_name          = "DataStream PostgreSQL Source Connection Profile"
  project               = var.project_id
  location              = var.region
  connection_profile_id = "postgresql-source-connection-profile-${var.environment}"

  postgresql_profile {
    hostname = google_sql_database_instance.dvd-rental-sql-postgresql.ip_address[0].ip_address
    port     = 5432
    database = var.database_name
    username = var.darabase_user_name
    password = data.google_secret_manager_secret_version.db_password_secret.secret_data
  }

  private_connectivity {
    private_connection = google_datastream_private_connection.private_connection.id
  }

  depends_on = [
    google_project_service.datastream_api,
    google_project_service.sqladmin_api,
    google_sql_database_instance.dvd-rental-sql-postgresql
  ]
}

# Create a Datastream connection profile for BigQuery
resource "google_datastream_connection_profile" "destination" {
  display_name          = "DataStream BigQuery Destination Connection Profile"
  project               = var.project_id
  location              = var.region
  connection_profile_id = "bigquery-destination-connection-profile-${var.environment}"

  bigquery_profile {}

  private_connectivity {
    private_connection = google_datastream_private_connection.private_connection.id
  }

  depends_on = [
    google_project_service.datastream_api,
    google_bigquery_dataset.dvd_rental_bigquery_dataset
  ]
}


resource "google_datastream_stream" "postgres_to_bigquery_stream" {
  display_name  = "PostgreSQL to BigQuery Stream"
  location      = var.region
  stream_id     = "postgres-to-bigquery-stream-${var.environment}"
  desired_state = "RUNNING"

  source_config {
    source_connection_profile = google_datastream_connection_profile.source.id
    postgresql_source_config {
      max_concurrent_backfill_tasks = 12
      publication                   = "publication"
      replication_slot              = "replication_slot"
      include_objects {
        postgresql_schemas {
          schema = "schema"
          postgresql_tables {
            table = "table"
            postgresql_columns {
              column = "column"
            }
          }
        }
      }
      exclude_objects {
        postgresql_schemas {
          schema = "schema"
          postgresql_tables {
            table = "table"
            postgresql_columns {
              column = "column"
            }
          }
        }
      }
    }
  }

  destination_config {
    destination_connection_profile = google_datastream_connection_profile.destination.id
    bigquery_destination_config {
      data_freshness = "900s"
      source_hierarchy_datasets {
        dataset_template {
          location = "us-central1"
        }
      }
    }
  }

  backfill_all {
    postgresql_excluded_objects {
      postgresql_schemas {
        schema = "schema"
        postgresql_tables {
          table = "table"
          postgresql_columns {
            column = "column"
          }
        }
      }
    }
  }
}