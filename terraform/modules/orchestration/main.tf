# Service Cloud Run pour l'exécution de DBT
resource "google_cloud_run_service" "dbt_runner" {
  name     = "dbt-runner"
  location = var.region
  project  = var.project_id

  template {
    spec {
      containers {
        image = "gcr.io/cloudrun/hello" # Image temporaire, à remplacer par l'image DBT
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

# Compte de service pour Cloud Composer
resource "google_service_account" "cloud_composer_service_account" {
  account_id   = "composer-service-account"
  display_name = "Cloud Composer Service Account"
  project      = var.project_id
}

# Attribution des rôles au compte de service Composer
resource "google_project_iam_member" "composer_worker_role" {
  project = var.project_id
  role    = "roles/composer.worker"
  member  = "serviceAccount:${google_service_account.cloud_composer_service_account.email}"
}

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
      image_version = "composer-3-airflow-2.9.3"
    }

    environment_size = "ENVIRONMENT_SIZE_SMALL"

    workloads_config {
      scheduler {
        cpu        = 1
        memory_gb  = 2
        storage_gb = 1
      }

      web_server {
        cpu        = 1
        memory_gb  = 2
        storage_gb = 1
      }

      worker {
        cpu        = 1
        memory_gb  = 2
        storage_gb = 10
      }
    }

    node_config {
      service_account = google_service_account.cloud_composer_service_account.email
    }
  }
}