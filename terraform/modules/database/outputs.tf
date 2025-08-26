output "cloud_sql_private_ip" {
  description = "Private IP address of the Cloud SQL instance."
  value       = google_sql_database_instance.postgresql_instance.private_ip_address
}

output "time_sleep_wait_for_sql_instance_id" {
  description = "ID of time sleep"
  value       = time_sleep.wait_for_sql_instance.id
}

output "superset_db_password" {
  description = "Superset database password"
  value       = data.google_secret_manager_secret_version.superset_db_password_secret.secret_data
}

output "cloud_sql_instance_name" {
  description = "Cloud SQL Instance name."
  value       = google_sql_database_instance.postgresql_instance.name
}

output "superset_redis_cache_host" {
  description = "Memorystore redis instance host"
  value = google_redis_instance.superset_redis_cache.host
}

