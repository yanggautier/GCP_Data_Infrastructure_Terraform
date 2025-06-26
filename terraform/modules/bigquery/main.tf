# Crée un dataset BigQuery pour les données DVD rental
resource "google_bigquery_dataset" "dvd_rental_bigquery_dataset" {
  dataset_id = "dvd_rental_bigquery_dataset"
  location   = var.region
  description = "Dataset for DVD rental data"

  labels = {
    environment = var.environment
    team        = "data-engineering"
  }

  # Définit les contrôles d'accès pour le dataset
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

  # Ajoute l'accès au compte de service Datastream
  access {
    role          = "roles/bigquery.dataEditor"
    user_by_email = var.datastream_service_account_email
  }
}