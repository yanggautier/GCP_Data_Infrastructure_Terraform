# Create a BigQuery dataset for the bronze layer
resource "google_bigquery_dataset" "bronze_dataset" {
  dataset_id = "bronze_${var.environment}"
  location   = var.region
  description = "Raw data from Datastream."

  labels = {
    environment = var.environment
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

  # Access for the Datastream service account
  access {
    role          = "roles/bigquery.dataEditor"
    user_by_email = var.datastream_service_account_email
  }

  # Access for the DBT service account
  access {
    role          = "roles/bigquery.dataViewer"
    user_by_email = var.dbt_service_account_email
  }
  
}


# Create a BigQuery dataset for the silver layer
resource "google_bigquery_dataset" "silver_dataset" {
  dataset_id = "silver_${var.environment}"
  location   = var.region
  description = "Silver dataset"

  labels = {
    environment = var.environment
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

  # Access for the DBT service account
  access {
    role          = "roles/bigquery.dataEditor"
    user_by_email = var.dbt_service_account_email
  }
}

# Create a BigQuery dataset for the gold layer
resource "google_bigquery_dataset" "gold_dataset" {
  dataset_id = "gold_${var.environment}"
  location   = var.region
  description = "Gold dataset"

  labels = {
    environment = var.environment
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

  # Access for the DBT service account
  access {
    role          = "roles/bigquery.dataEditor"
    user_by_email = var.dbt_service_account_email
  }
}