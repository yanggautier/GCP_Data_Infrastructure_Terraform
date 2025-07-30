# Cluster GKE
resource "google_container_cluster" "dbt_cluster" {
  name     = "dbt-cluster-${var.environment}"
  location = var.region
  project  = var.project_id
  network    = var.vpc_id
  subnetwork = var.gke_subnet_id

  # Configuration for Autopilot mode
  enable_autopilot = true
  
  # Or Standard mode with custom node pool
  # initial_node_count       = 1
  # remove_default_node_pool = true

  # Enable private cluster
  private_cluster_config {
    enable_private_nodes = true
    enable_private_endpoint = false
    master_ipv4_cidr_block = var.gke_master_ipv4_cidr_block
  }
  # Enable IP aliasing for GKE
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }
}

provider "kubernetes" {
  host                   = google_container_cluster.dbt_cluster.endpoint
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.dbt_cluster.master_auth[0].cluster_ca_certificate)
  
}

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
      image_version = var.cloud_composer_size
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