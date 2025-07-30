

# Service account pour Cloud Composer
resource "google_service_account" "cloud_composer_service_account" {
  account_id   = "composer-service-account"
  display_name = "Cloud Composer Service Account"
  project      = var.project_id
}

# Attibutes IAM pour le service account Cloud Composer
resource "google_project_iam_member" "composer_worker_role" {
  project = var.project_id
  role    = "roles/composer.worker"
  member  = "serviceAccount:${google_service_account.cloud_composer_service_account.email}"
}
# Attribution IAM pour le service account Cloud Composer
resource "google_project_iam_member" "composer_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloud_composer_service_account.email}"
}

resource "google_project_iam_member" "artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.cloud_composer_service_account.email}"
}

# Référentiel Artifact Registry pour les images Docker DBT
resource "google_artifact_registry_repository" "dbt_repo" {
  project       = var.project_id
  location      = var.region
  repository_id = "dbt-images"
  format        = "DOCKER"
}

# Environnement Cloud Composer pour l'orchestration DBT
resource "google_composer_environment" "dbt_orchestration" {
  name     = "composer-dbt-${var.environment}"
  region   = var.region
  project  = var.project_id
  
  depends_on = [
    google_project_iam_member.composer_sa_user,
    google_project_iam_member.composer_worker_role
  ]
  config {
    software_config {
      image_version = var.cloud_composer_version
    }

    environment_size = var.cloud_composer_size
    workloads_config {
      scheduler {
        cpu        = var.cloud_composer_scheduler_cpu
        memory_gb  = var.cloud_composer_scheduler_memory_gb
        storage_gb = var.cloud_composer_scheduler_storage_gb
      }

      web_server {
        cpu        = var.cloud_composer_webserver_cpu
        memory_gb  = var.cloud_composer_websever_memory_gb
        storage_gb = var.cloud_composer_webserver_storage_gb
      }

      worker {
        cpu        = var.cloud_composer_worker_cpu
        memory_gb  = var.cloud_composer_worker_memory_gb
        storage_gb = var.cloud_composer_worker_storage_gb
      }
    }

    node_config {
      service_account = google_service_account.cloud_composer_service_account.email
    }
  }
}