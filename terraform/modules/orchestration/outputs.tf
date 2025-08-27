output "composer_environment_name" {
  description = "Name of the Cloud Composer environment."
  value       = google_composer_environment.dbt_orchestration.name
}

output "repository_id" {
  description = "Repository id"
  value       = google_artifact_registry_repository.dbt_repo.repository_id
}

output "repository_name" {
  description = "Repository name"
  value       = google_artifact_registry_repository.dbt_repo.name
}