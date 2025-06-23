# datastream_stream.tf
# Ce fichier doit être appliqué APRÈS avoir configuré manuellement PostgreSQL
# et vérifié que les connection profiles fonctionnent correctement

# Variables requises (ajoutez-les à votre fichier variables.tf si pas déjà présent)
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

# Références aux ressources existantes
data "google_datastream_connection_profile" "source" {
  connection_profile_id = "postgresql-source-${var.environment}"
  location             = var.region
  project              = var.project_id
}

data "google_datastream_connection_profile" "destination" {
  connection_profile_id = "bigquery-destination-${var.environment}"
  location             = var.region
  project              = var.project_id
}

# Création du stream Datastream
resource "google_datastream_stream" "postgres_to_bigquery_stream" {
  display_name  = "PostgreSQL to BigQuery Stream"
  location      = var.region
  stream_id     = "postgres-to-bigquery-${var.environment}"
  desired_state = "RUNNING"

  source_config {
    source_connection_profile = data.google_datastream_connection_profile.source.id
    postgresql_source_config {
      max_concurrent_backfill_tasks = 12
      publication                   = "datastream_publication"
      replication_slot              = "datastream_slot"
      include_objects {
        postgresql_schemas {
          schema = "public"
          postgresql_tables {
            table = "actor"
          }
        }
      }
    }
  }

  destination_config {
    destination_connection_profile = data.google_datastream_connection_profile.destination.id
    bigquery_destination_config {
      data_freshness = "900s"
      source_hierarchy_datasets {
        dataset_template {
          location    = var.region
          dataset_id_prefix = "dvd_rental_"
          kms_key_name = null
        }
      }
      # Configuration pour la gestion des erreurs
      single_target_dataset {
        dataset_id = "dvd_rental_bigquery_dataset"
      }
    }
  }

  backfill_all {
    # Configuration pour le backfill initial
  }

  # Configuration pour la gestion des erreurs et monitoring
  labels = {
    environment = var.environment
    source      = "postgresql"
    destination = "bigquery"
    team        = "data-engineering"
  }
}

# Outputs pour le monitoring
output "datastream_stream_id" {
  description = "ID du stream Datastream"
  value       = google_datastream_stream.postgres_to_bigquery_stream.id
}

output "datastream_stream_name" {
  description = "Nom du stream Datastream"
  value       = google_datastream_stream.postgres_to_bigquery_stream.name
}

output "datastream_state" {
  description = "État du stream Datastream"
  value       = google_datastream_stream.postgres_to_bigquery_stream.state
}