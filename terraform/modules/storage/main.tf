# Crée un bucket Google Cloud Storage pour les données DVD Rental
resource "google_storage_bucket" "data-bucket" {
  name                        = "data-bucket-${var.environment}-${random_id.bucket_suffix.hex}"
  location                    = var.region
  storage_class               = "STANDARD"
  force_destroy               = true
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

# Bucket pour les artefacts DBT
resource "google_storage_bucket" "dbt-bucket" {
  name                        = "dbt-bucket-${var.environment}-${random_id.dbt_bucket_suffix.hex}"
  location                    = var.region
  storage_class               = "STANDARD"
  force_destroy               = true
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

resource "random_id" "dbt_bucket_suffix" {
  byte_length = 4
}