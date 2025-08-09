output "bucket_name" {
  description = "Name of the main DVD rental GCS bucket."
  value       = module.storage.data_bucket_name
}

output "cloud_sql_private_ip" {
  description = "Private IP address of the Cloud SQL instance."
  value       = module.database.cloud_sql_private_ip
}

output "postgresql_setup_commands" {
  description = "SQL commands to set up PostgreSQL publication and replication slot for Datastream."
  value       = module.database.postgresql_setup_commands
}

output "bigquery_bronze_dataset_id" {
  description = "ID of the BigQuery dataset."
  value       = module.bigquery.bigquery_bronze_dataset_id
}

output "datastream_service_account_email" {
  description = "Email of the Datastream service account."
  value       = module.datastream_core.datastream_service_account_email
}

output "datastream_source_connection_profile_id" {
  description = "ID of the Datastream source connection profile."
  value       = module.datastream_core.datastream_source_connection_profile_id
}

output "datastream_destination_connection_profile_id" {
  description = "ID of the Datastream destination connection profile."
  value       = module.datastream_core.datastream_destination_connection_profile_id
}

output "composer_environment_name" {
  description = "Name of the Cloud Composer environment."
  value       = module.orchestration.composer_environment_name
}