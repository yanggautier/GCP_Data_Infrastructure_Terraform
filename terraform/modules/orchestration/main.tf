# ----------------- Configuration for DBT GKE IAM --------------------=
# Assign the DB@T service account the BigQuery User role
resource "google_project_iam_member" "dbt_bigquery_user" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${var.kubernetes_service_account_email}"
}

resource "google_project_iam_member" "dbt_bigquery_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${var.kubernetes_service_account_email}"
}

# --------------- Configuration for Kubernetes RBAC  ---------------------
# Create a Kubernetes service account for DBT
resource "kubernetes_service_account" "dbt_k8s_sa" {
  metadata {
    name      = "dbt-k8s-sa"
    namespace = var.dbt_namespace
    annotations = {
      "iam.gke.io/gcp-service-account" = var.kubernetes_service_account_email
    }
  }
  depends_on = [kubernetes_namespace.dbt_namespace]

  lifecycle {
    create_before_destroy = true
  }
}

# Bind the DBT service account to the Kubernetes service account
resource "google_service_account_iam_binding" "workload_identity_binding" {
  service_account_id = var.kubernetes_service_account_id
  role               = "roles/iam.workloadIdentityUser"
  members            = ["serviceAccount:${var.project_id}.svc.id.goog[${var.dbt_namespace}/${kubernetes_service_account.dbt_k8s_sa.metadata[0].name}]"]
}

# ----------------- Configuration for Artifact Repository ---------------------
resource "google_artifact_registry_repository" "dbt_repo" {
  repository_id = "dbt-repo-${var.environment}"
  location      = var.region
  project       = var.project_id
  format        = "DOCKER"
  description   = "Artifact Registry repository for DBT images"
}

# Configure for DBT profiles
resource "google_secret_manager_secret" "dbt_profiles" {
  secret_id = "dbt-profiles-${var.environment}"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "dbt_profiles_version" {
  secret = google_secret_manager_secret.dbt_profiles.id
  secret_data = templatefile("${path.module}/dbt_profiles.yml.tpl", {
    project_id = var.project_id
    dataset    = var.bigquery_bronze_dataset_id
    region     = var.region
  })
}

# Name space for DBT
resource "kubernetes_namespace" "dbt_namespace" {
  metadata {
    name = var.dbt_namespace
  }

  timeouts {
    delete = "10m"
  }

  depends_on = [
    google_secret_manager_secret_version.dbt_profiles_version
  ]
}

# CSI Secret Store Driver
resource "kubernetes_secret" "dbt_config" {
  metadata {
    name      = "dbt-config"
    namespace = kubernetes_namespace.dbt_namespace.metadata[0].name
  }
  data = {
    "profiles.yml" = base64encode(google_secret_manager_secret_version.dbt_profiles_version.secret_data)
  }
  type = "Opaque"

  lifecycle {
    create_before_destroy = true
  }
}

# Networking policy for DBT namespace
resource "kubernetes_network_policy" "dbt_network_policy" {
  metadata {
    name      = "dbt-network-policy"
    namespace = kubernetes_namespace.dbt_namespace.metadata[0].name
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

  depends_on = [kubernetes_namespace.dbt_namespace]
}

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
  name    = "composer-dbt-${var.environment}"
  region  = var.region
  project = var.project_id

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
      network         = var.vpc_id
      subnetwork      = var.gke_subnet_id
    }
  }
}

resource "google_storage_bucket_object" "dbt_run_dag_file" {
  name   = "dags/dbt_run_dag.py"
  bucket = split("/", replace(google_composer_environment.dbt_orchestration.config[0].dag_gcs_prefix, "gs://", ""))[0]
  content = templatefile("${path.module}/../../dags/dbt_run_dag.py.tpl", {
    dbt_namespace     = var.dbt_namespace
    dbt_k8s_sa_name   = kubernetes_service_account.dbt_k8s_sa.metadata[0].name
    dbt_default_image = "ghcr.io/dbt-labs/dbt-bigquery:latest"
    dbt_custom_image  = "{{ var.region }}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.dbt_repo.name}/dbt:latest"
    cloud_composer_admin_email = var.cloud_composer_admin_email
  })

  depends_on = [
    google_composer_environment.dbt_orchestration
  ]
}