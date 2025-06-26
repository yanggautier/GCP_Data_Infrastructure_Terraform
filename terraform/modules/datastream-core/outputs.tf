# terraform/modules/datastream-core/outputs.tf

output "datastream_service_account_email" {
  description = "Email of the Datastream service account."
  value       = google_service_account.datastream_service_account.email
}

output "datastream_private_connection_id" {
  description = "ID of the Datastream private connection."
  value       = google_datastream_private_connection.private_connection.id
}

output "datastream_source_connection_profile_id" {
  description = "ID of the Datastream source connection profile."
  value       = google_datastream_connection_profile.source.id
}

output "datastream_destination_connection_profile_id" {
  description = "ID of the Datastream destination connection profile."
  value       = google_datastream_connection_profile.destination.id
}

output "datastream_source_connection_profile_object" {
  description = "The entire Datastream source connection profile object."
  value       = google_datastream_connection_profile.source
}

output "datastream_destination_connection_profile_object" {
  description = "The entire Datastream destination connection profile object."
  value       = google_datastream_connection_profile.destination
}