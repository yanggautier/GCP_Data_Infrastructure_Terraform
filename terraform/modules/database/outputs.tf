output "cloud_sql_private_ip" {
  description = "Private IP address of the Cloud SQL instance."
  value       = google_sql_database_instance.postgresql_instance.private_ip_address
}

output "time_sleep_wait_for_sql_instance_id" {
  description = "ID of time sleep"
  value       = time_sleep.wait_for_sql_instance.id
}