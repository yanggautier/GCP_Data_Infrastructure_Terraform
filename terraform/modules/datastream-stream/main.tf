# Establish Datastream connection between PostgreSQL database and Bigquery dataset
resource "google_datastream_stream" "postgres_to_bigquery_stream" {
  display_name  = "PostgreSQL to BigQuery Stream"
  location      = var.region
  stream_id     = "postgres-to-bigquery-${var.environment}"
  desired_state = "RUNNING"

  source_config {
    # Reference to source profilke
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
    # Reference to destination profile
    destination_connection_profile = var.destination_connection_profile_object.id
    bigquery_destination_config {
      data_freshness = "900s"
      single_target_dataset {
        dataset_id = "${var.project_id}:${var.bigquery_bronze_dataset_id}"
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

}