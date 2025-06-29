# terraform/modules/datastream-stream/main.tf

# NOTE IMPORTANTE : Nous ne pouvons pas utiliser 'data' ici.
# Les profils de connexion sont passés directement en tant qu'objets depuis un autre module.

resource "google_datastream_stream" "postgres_to_bigquery_stream" {
  display_name = "PostgreSQL to BigQuery Stream"
  location     = var.region
  stream_id    = "postgres-to-bigquery-${var.environment}"
  desired_state = "RUNNING"

  source_config {
    # Référence directe à l'ID de l'objet du profil de connexion source passé en variable
    source_connection_profile = var.source_connection_profile_object.id
    postgresql_source_config {
      max_concurrent_backfill_tasks = 12
      publication                   = "datastream_publication"
      replication_slot              = "datastream_slot"
      include_objects {
        postgresql_schemas {
          schema = "public"
        }
      }
    }
  }

  destination_config {
    # Référence directe à l'ID de l'objet du profil de connexion destination passé en variable
    destination_connection_profile = var.destination_connection_profile_object.id
    bigquery_destination_config {
      data_freshness = "900s"
      single_target_dataset {
        dataset_id = "${var.project_id}:${var.bigquery_dataset_id}"
      }
    }
  }

  backfill_all {}

  labels = {
    environment = var.environment
    source      = "postgresql"
    destination = "bigquery"
    team        = "data-engineering"
  }

  # Dépendances implicites via les variables, mais on peut ajouter explicites si besoin
  # depends_on = [
  #   var.source_connection_profile_object,
  #   var.destination_connection_profile_object
  # ]
}