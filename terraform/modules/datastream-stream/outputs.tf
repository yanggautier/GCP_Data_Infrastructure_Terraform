# terraform/modules/datastream-stream/outputs.tf

output "datastream_stream_id" {
  description = "ID of the Datastream stream."
  value       = google_datastream_stream.postgres_to_bigquery_stream.id
}

output "datastream_stream_name" {
  description = "Name of the Datastream stream."
  value       = google_datastream_stream.postgres_to_bigquery_stream.name
}

output "datastream_state" {
  description = "State of the Datastream stream."
  value       = google_datastream_stream.postgres_to_bigquery_stream.state
}