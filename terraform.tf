# Create a Google Cloud Storage bucket
resource "google_storage_bucket" "dvd-rental-bucket" {
    name          = "dvd-rental-bucket"
    location      = "europe-west9"
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

resource "google_sql_database_instance" "dvd-rental-sql-postgresql" {
  name             = "dvd-rental-instance"
  database_version = "POSTGRES_15"
  region           = "europe-west9"

  settings {
    # Second-generation instance tiers are based on the machine
    # type. See argument reference below.
    tier = "db-f1-micro"
    deletion_protection_enabled = false
  }
}
resource "google_sql_database" "dvd_rental_db" {
  name     = "dvd_rental_db"
  instance = google_sql_database_instance.dvd-rental-sql-postgresql.name
}

data "google_secret_manager_secret_version" "db_password_secret" {
  secret  = "postgres-instance-password" #replace with your secret name
  project = "dvd-rental-project"   # replace with your GCP project ID)
}

resource "google_sql_user" "dvd_rental_user" {
  name     = var.cloud_sql_user_name
  instance = google_sql_database_instance.dvd-rental-sql-postgresql.name
  password_wo = data.google_secret_manager_secret_version.db_password_secret.secret_data
  password_wo_version = 1 # incremental version number
}

resource "google_bigquery_dataset" "dvd_rental_bigquery_dataset" {
  dataset_id = "dvd_rental_bigquery_dataset"
  location   = "europe-west9"
  description = "Dataset for DVD rental data"

  labels = {
    environment = "production"
    team        = "data-engineering"
  }
  
   # Define access controls for the dataset
  access {
    role          = "OWNER"
    user_by_email =  var.bigquery_owner_user # Replace with your email
  }

}

output "bigquery_dataset_id" {
  description = "ID of the BigQuery dataset"
  value       = google_bigquery_dataset.dvd_rental_bigquery_dataset.id
}