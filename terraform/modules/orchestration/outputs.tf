output "composer_environment_name" {
  description = "Name of the Cloud Composer environment."
  value       = google_composer_environment.dbt_orchestration.name
}