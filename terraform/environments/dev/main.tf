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

    /*
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    */
  }

  backend "gcs" {
    bucket = "state-file-dev-buckets" # it must be a static bucket not a dynamic bucket name
    prefix = "terraform/state"
  }
}

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

# Enable APIs
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
    "containerregistry.googleapis.com"
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}


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

module "storage" {
  source      = "../../modules/storage"
  project_id  = var.project_id
  region      = var.region
  environment = var.environment

  depends_on = [google_project_service.apis]
}

module "database" {
  source                    = "../../modules/database"
  project_id                = var.project_id
  region                    = var.region
  environment               = var.environment
  database_name             = var.database_name
  database_user_name        = var.database_user_name
  instance_tier             = local.current_env.instance_tier
  disk_size                 = local.current_env.disk_size
  backup_enabled            = local.current_env.backup_enabled
  deletion_protection       = local.current_env.deletion_protection
  max_replication_slots     = local.current_env.max_replication_slots
  max_wal_senders           = local.current_env.max_wal_senders
  db_password_secret_name   = var.db_password_secret_name
  secret_version            = var.secret_version
  vpc_id                    = module.networking.vpc_id
  private_vpc_connection_id = module.networking.private_ip_alloc_name
  vpc_name                  = module.networking.vpc_name
  datastream_subset_name    = module.networking.datastream_subnet_name
  private_vpc_connection    = module.networking.private_vpc_connection

  depends_on = [
    google_project_service.apis,
    module.networking
  ]
}

module "datastream_core" {
  source                               = "../../modules/datastream-core"
  project_id                           = var.project_id
  region                               = var.region
  environment                          = var.environment
  vpc_id                               = module.networking.vpc_id
  private_vpc_connection_id            = module.networking.private_ip_alloc_name
  database_name                        = var.database_name
  database_user_name                   = var.database_user_name
  datastream_subnet_id                 = module.networking.datastream_subnet_id
  db_password_secret_name              = var.db_password_secret_name
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
# Create a service account for DBT to access BigQuery
resource "google_service_account" "dbt_sa" {
  account_id   = "dbt-bigquery-sa"
  display_name = "DBT BigQuery Service Account"
  project      = var.project_id
  description  = "Service account for DBT to access BigQuery"
}

module "bigquery" {
  source                           = "../../modules/bigquery"
  project_id                       = var.project_id
  region                           = var.region
  environment                      = var.environment
  bigquery_owner_user              = var.bigquery_owner_user
  bigquery_analyst_user            = var.bigquery_analyst_user
  bigquery_contributor_user        = var.bigquery_contributor_user
  datastream_service_account_email = module.datastream_core.datastream_service_account_email
  dbt_service_account_email        = google_service_account.dbt_sa.email

  depends_on = [google_project_service.apis, google_service_account.dbt_sa]
}


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
resource "google_container_cluster" "dbt_cluster" {
  name       = "dbt-cluster-${var.environment}"
  location   = var.region
  project    = var.project_id

  network    = module.networking.vpc_id
  subnetwork = module.networking.gke_subnet_id
  # Configuration for Autopilot mode
  enable_autopilot = true
  # Or Standard mode with custom node pool
  # initial_node_count       = 1
  # remove_default_node_pool = true

  /*
  # Enable private cluster
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.gke_master_ipv4_cidr_block
  }
  */
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

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.dbt_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.dbt_cluster.master_auth[0].cluster_ca_certificate)
  # Explicitly depend on the GKE cluster to ensure it's ready before configuring the Kubernetes provider
}


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
  dbt_service_account_email           = google_service_account.dbt_sa.email
  dbt_service_account_id              = google_service_account.dbt_sa.name

  depends_on = [
    google_project_service.apis,
    module.networking,
    google_service_account.dbt_sa,
    google_container_cluster.dbt_cluster
  ]
}