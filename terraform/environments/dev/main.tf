# Define google providers version
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }

    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
    }

    docker = {
      source  = "kreuzwerker/docker"
      version = "2.23.1"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
  }

  backend "gcs" {
    bucket = "state-file-dev-buckets" # it must be a static bucket not a dynamic bucket name
    prefix = "terraform/state"
  }
}

# Google provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Include all shared local variables
# Remplacer votre bloc locals actuel par :
locals {
  # Charger la configuration depuis le fichier YAML
  shared_config = yamldecode(file("${path.root}/../../shared/locals.yaml"))

  # Sélectionner la configuration de l'environnement actuel
  current_env = local.shared_config.env_config[var.environment]
}

# Enable APIs for GCP services
resource "google_project_service" "apis" {
  for_each = toset([
    "servicenetworking.googleapis.com",
    "composer.googleapis.com",
    "datastream.googleapis.com",
    "bigquery.googleapis.com",
    "sqladmin.googleapis.com",
    "cloudbuild.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "containerregistry.googleapis.com",
    "redis.googleapis.com"
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# VPC configuration module
module "networking" {
  source                        = "../../modules/networking"
  project_id                    = var.project_id
  region                        = var.region
  environment                   = var.environment
  datastream_subnetwork_address = var.datastream_subnetwork_address
  gke_subnetwork_address        = var.gke_subnetwork_address
  gke_secondary_pod_range       = var.gke_secondary_pod_range
  gke_secondary_service_range   = var.gke_secondary_service_range
  depends_on                    = [google_project_service.apis]
}

# Storage (GCS) module, bucket for business data, DBT docs 
module "storage" {
  source      = "../../modules/storage"
  project_id  = var.project_id
  region      = var.region
  environment = var.environment

  depends_on = [google_project_service.apis]
}

# Database module, create PostgreSQL Cloud SQL instance and databases for business and Superset
module "database" {
  source                           = "../../modules/database"
  project_id                       = var.project_id
  region                           = var.region
  environment                      = var.environment
  business_database_name           = var.business_database_name
  business_database_user_name      = var.business_database_user_name
  superset_database_name           = var.superset_database_name
  superset_database_user_name      = var.superset_database_user_name
  instance_tier                    = local.current_env.instance_tier
  disk_size                        = local.current_env.disk_size
  backup_enabled                   = local.current_env.backup_enabled
  deletion_protection              = local.current_env.deletion_protection
  max_replication_slots            = local.current_env.max_replication_slots
  max_wal_senders                  = local.current_env.max_wal_senders
  business_db_password_secret_name = var.business_db_password_secret_name
  business_secret_version          = var.business_secret_version
  superset_db_password_secret_name = var.superset_db_password_secret_name
  superset_secret_version          = var.superset_secret_version
  vpc_id                           = module.networking.vpc_id
  private_vpc_connection_id        = module.networking.private_ip_alloc_name
  vpc_name                         = module.networking.vpc_name
  datastream_subset_name           = module.networking.datastream_subnet_name
  private_vpc_connection           = module.networking.private_vpc_connection

  depends_on = [
    google_project_service.apis,
    module.networking
  ]
}

# Module for core of Datastream
module "datastream_core" {
  source                               = "../../modules/datastream-core"
  project_id                           = var.project_id
  region                               = var.region
  environment                          = var.environment
  vpc_id                               = module.networking.vpc_id
  private_vpc_connection_id            = module.networking.private_ip_alloc_name
  database_name                        = var.business_database_name
  database_user_name                   = var.business_database_user_name
  datastream_subnet_id                 = module.networking.datastream_subnet_id
  db_password_secret_name              = var.business_db_password_secret_name
  bigquery_bronze_dataset_id           = module.bigquery.bigquery_bronze_dataset_id
  wait_for_sql_instance_id             = module.database.time_sleep_wait_for_sql_instance_id
  cloud_sql_private_ip                 = module.database.cloud_sql_private_ip
  datastream_private_connection_subnet = var.datastream_private_connection_subnet

  depends_on = [
    google_project_service.apis,
    module.database,
    module.networking
  ]

}
# Create a service account for Kubernetes
resource "google_service_account" "kubernetes_sa" {
  account_id   = "kubernetes-sa"
  display_name = "Kubernetes Service Account"
  project      = var.project_id
  description  = "Service account for Kubernetes"
}
# Module for bigquery 
module "bigquery" {
  source                           = "../../modules/bigquery"
  project_id                       = var.project_id
  region                           = var.region
  environment                      = var.environment
  bigquery_owner_user              = var.bigquery_owner_user
  bigquery_analyst_user            = var.bigquery_analyst_user
  bigquery_contributor_user        = var.bigquery_contributor_user
  datastream_service_account_email = module.datastream_core.datastream_service_account_email
  kubernetes_service_account_email = google_service_account.kubernetes_sa.email

  depends_on = [google_project_service.apis, google_service_account.kubernetes_sa]
}

# Datastream Stream module
module "datastream_stream" {
  source                                = "../../modules/datastream-stream"
  project_id                            = var.project_id
  region                                = var.region
  environment                           = var.environment
  bigquery_bronze_dataset_id            = module.bigquery.bigquery_bronze_dataset_id
  source_connection_profile_object      = module.datastream_core.datastream_source_connection_profile_object
  destination_connection_profile_object = module.datastream_core.datastream_destination_connection_profile_object

  depends_on = [
    google_project_service.apis,
    module.datastream_core,
    module.database.datastream_setup,
    module.database.postgresql_setup_completed
  ]
}

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
resource "google_container_cluster" "kubernetes_cluster" {
  name     = "kubernetes-cluster-${var.environment}"
  location = var.region
  project  = var.project_id

  network    = module.networking.vpc_id
  subnetwork = module.networking.gke_subnet_id
  # Configuration for Autopilot mode
  enable_autopilot = true
  # Or Standard mode with custom node pool
  # initial_node_count       = 1
  # remove_default_node_pool = true

  # Enable IP aliasing for GKE
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }

  # Enable deletion protection for the GKE cluster
  deletion_protection = var.cluster_deletion_protection
}

data "google_client_config" "default" {}

# Use Google provider with registry auth
provider "docker" {
    registry_auth {
    address  = "${var.region}-docker.pkg.dev"
    username = "oauth2accesstoken"
    password = data.google_client_config.default.access_token
  }
}

# Use Kubernetes provider
provider "kubernetes" {
  host                   = "https://${google_container_cluster.kubernetes_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.kubernetes_cluster.master_auth[0].cluster_ca_certificate)
}

# Use Helm provider
provider "helm" {
  kubernetes = {
    host                   = "https://${google_container_cluster.kubernetes_cluster.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.kubernetes_cluster.master_auth[0].cluster_ca_certificate)
  }
}

# Module for Cloud Composer and GKE
module "orchestration" {
  source                              = "../../modules/orchestration"
  project_id                          = var.project_id
  region                              = var.region
  environment                         = var.environment
  vpc_id                              = module.networking.vpc_id
  gke_subnet_id                       = module.networking.gke_subnet_id
  cloud_composer_size                 = var.cloud_composer_size
  cloud_composer_scheduler_cpu        = var.cloud_composer_scheduler_cpu
  cloud_composer_scheduler_memory_gb  = var.cloud_composer_scheduler_memory_gb
  cloud_composer_scheduler_storage_gb = var.cloud_composer_scheduler_storage_gb
  cloud_composer_webserver_cpu        = var.cloud_composer_webserver_cpu
  cloud_composer_websever_memory_gb   = var.cloud_composer_websever_memory_gb
  cloud_composer_webserver_storage_gb = var.cloud_composer_webserver_storage_gb
  cloud_composer_worker_cpu           = var.cloud_composer_worker_cpu
  cloud_composer_worker_memory_gb     = var.cloud_composer_worker_memory_gb
  cloud_composer_worker_storage_gb    = var.cloud_composer_worker_storage_gb
  gke_master_ipv4_cidr_block          = var.gke_master_ipv4_cidr_block
  cluster_deletion_protection         = var.cluster_deletion_protection
  bigquery_bronze_dataset_id          = module.bigquery.bigquery_bronze_dataset_id
  kubernetes_service_account_email    = google_service_account.kubernetes_sa.email
  kubernetes_service_account_id       = google_service_account.kubernetes_sa.name
  cloud_composer_admin_email          = var.cloud_composer_admin_email

  depends_on = [
    google_project_service.apis,
    module.networking,
    google_service_account.kubernetes_sa,
    google_container_cluster.kubernetes_cluster
  ]
}

# Superset module
module "dataviz" {
  source                           = "../../modules/dataviz"
  project_id                       = var.project_id
  region                           = var.region
  environment                      = var.environment
  superset_db_password             = module.database.superset_db_password
  superset_database_name           = var.superset_database_name
  superset_database_user_name      = var.superset_database_user_name
  kubernetes_service_account_email = google_service_account.kubernetes_sa.email
  superset_redis_cache_host        = module.database.superset_redis_cache_host
  cloud_sql_instance_name          = module.database.cloud_sql_instance_name
  kubernetes_service_account_id    = google_service_account.kubernetes_sa.id
  repository_id                    = module.orchestration.repository_id
  repository_name                  = module.orchestration.repository_name

  depends_on = [
    google_project_service.apis,
    module.networking,
    google_container_cluster.kubernetes_cluster
  ]
}