
# ----------------- Configuration for DBT GKE IAM ---------------------

# Assign the DB@T service account the BigQuery User role
resource "google_project_iam_member" "dbt_bigquery_user" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${var.dbt_service_account_email}"
}

resource "google_project_iam_member" "dbt_bigquery_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${var.dbt_service_account_email}"
}

# --------------- Configuration for Kubernetes RBAC  ---------------------
# Create a Kubernetes service account for DBT
resource "kubernetes_service_account" "dbt_k8s_sa" {
  metadata {
    name      = "dbt-k8s-sa"
    namespace = var.dbt_namespace
    annotations = {
      "iam.gke.io/gcp-service-account" = var.dbt_service_account_email
    }
  }
}

# Bind the DBT service account to the Kubernetes service account
resource "google_service_account_iam_binding" "workload_identity_binding" {
  service_account_id = var.dbt_service_account_id
  role               = "roles/iam.workloadIdentityUser"
  members            = ["serviceAccount:${var.project_id}.svc.id.goog[${var.dbt_namespace}/${kubernetes_service_account.dbt_k8s_sa.metadata[0].name}]"]
}

# ----------------- Configuration for Artifact Repository ---------------------
resource "google_artifact_registry_repository" "dbt_repo" {
  repository_id = "dbt-repo-${var.environment}"
  location = var.region
  project  = var.project_id
  format = "DOCKER"
  description = "Artifact Registry repository for DBT images"
}

# ----------------- Configuration for Cluster GKE ---------------------
/*
# Create a GKE Cluster Service Account
resource "google_service_account" "gke_node_service_account" {
  account_id   = "gke-node-service-account"
  display_name = "GKE Node Service Account"
  project      = var.project_id
}

# Assign the GKE Cluster Service Account the Container Admin role
resource "google_project_iam_member" "cluster_admin_role" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.gke_node_service_account.email}"
}


# Cluster GKE
resource "google_container_cluster" "dbt_cluster" {
  name       = "dbt-cluster-${var.environment}"
  location   = var.region
  project    = var.project_id

  network    = var.vpc_id
  subnetwork = var.gke_subnet_id
  # Configuration for Autopilot mode
  enable_autopilot = true
  # Or Standard mode with custom node pool
  # initial_node_count       = 1
  # remove_default_node_pool = true

  # Enable private cluster
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.gke_master_ipv4_cidr_block
  }
  
  # Enable IP aliasing for GKE
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Enable deletion protection for the GKE cluster
  deletion_protection = var.cluster_deletion_protection
}
*/
# Configure for DBT profiles
resource "google_secret_manager_secret" "dbt_profiles" {
  secret_id = "dbt-profiles-${var.environment}"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "dbt_profiles_version" {
  secret      = google_secret_manager_secret.dbt_profiles.id
  secret_data = templatefile("${path.module}/dbt_profiles.yml.tpl", {
    project_id = var.project_id
    dataset    = var.bigquery_bronze_dataset_id
    region     = var.region
  })
}

# CSI Secret Store Driver
resource "kubernetes_secret" "dbt_config" {
  metadata {
    name      = "dbt-config"
    namespace = var.dbt_namespace
  }
  data = {
    "profiles.yml" = base64encode(google_secret_manager_secret_version.dbt_profiles_version.secret_data)
  }
  type = "Opaque"
}

resource "kubernetes_network_policy" "dbt_network_policy" {
  metadata {
    name      = "dbt-network-policy"
    namespace = var.dbt_namespace
  }

  spec {
    pod_selector {
      match_labels = {
        app = "dbt"
      }
    }

    policy_types = ["Ingress", "Egress"]

    egress {
      # Autoriser seulement BigQuery API
      to {
        namespace_selector {}
      }
      ports {
        port     = "443"
        protocol = "TCP"
      }
    }
  }
}

# ----------------- Configuration for DBT Deployment ---------------------
# Create a Kubernetes deployment for DBT
/*
resource "kubernetes_deployment" "dbt" {
  metadata {
    name      = "dbt"
    namespace = var.dbt_namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "dbt"
      }
    }

    template {
      metadata {
        labels = {
          app = "dbt"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.dbt_k8s_sa.metadata[0].name
        
        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          fs_group        = 2000
        }

        container {
          name  = "dbt"
          image = "ghcr.io/dbt-labs/dbt-bigquery:latest"

          env {
            name  = "DBT_PROFILES_DIR"
            value = "/app/profiles"
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            name       = "dbt-profiles"
            mount_path = "/app/profiles"
            read_only  = true
          }
        }

        volume {
          name = "dbt-profiles"
          secret {
            secret_name = kubernetes_secret.dbt_config.metadata[0].name
          }
        }
      }
    }
  }
}
*/

# -------------- Configuration for Cloud Composer -----------------
# Create a service account for Cloud Composer
resource "google_service_account" "cloud_composer_service_account" {
  account_id   = "composer-service-account"
  display_name = "Cloud Composer Service Account"
  project      = var.project_id
}

# Assign the Cloud Composer service account the Composer Worker role  
resource "google_project_iam_member" "composer_worker_role" {
  project = var.project_id
  role    = "roles/composer.worker"
  member  = "serviceAccount:${google_service_account.cloud_composer_service_account.email}"
}
# Assign the Cloud Composer service account the Composer Service Agent role
resource "google_project_iam_member" "composer_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloud_composer_service_account.email}"
}

resource "google_project_iam_member" "composer_gke_developer" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.cloud_composer_service_account.email}"
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
      network    = var.vpc_id
      subnetwork = var.gke_subnet_id
    }
  }
}

resource "google_storage_bucket_object" "dbt_dag_file" {
  name  = "dags/dbt_dag.py"
  bucket = google_composer_environment.dbt_orchestration.config[0].dag_gcs_prefix
  content = templatefile("${path.module}/../../dags/dbt_dag.py.tpl", {
    dbt_namespace = var.dbt_namespace
    dbt_k8s_sa_name = kubernetes_service_account.dbt_k8s_sa.metadata[0].name
  })  

  depends_on = [
    google_composer_environment.dbt_orchestration
  ]
}