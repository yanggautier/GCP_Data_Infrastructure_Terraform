output "composer_environment_name" {
  description = "Name of the Cloud Composer environment."
  value       = google_composer_environment.dbt_orchestration.name
}

output "dbt_runner_service_url" {
  description = "URL of the Cloud Run DBT runner service."
  value       = google_cloud_run_service.dbt_runner.status[0].url
}