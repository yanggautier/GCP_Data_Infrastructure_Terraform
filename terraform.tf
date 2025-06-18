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
  }
}

