terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
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
locals {
  source = "../../shared"
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
  depends_on                = [google_project_service.apis, module.networking]
}

# Remplacez l'ancien module "datastream" par "datastream_core"
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
  bigquery_dataset_id                  = module.bigquery.bigquery_dataset_id
  wait_for_sql_instance_id             = module.database.time_sleep_wait_for_sql_instance_id
  cloud_sql_private_ip                 = module.database.cloud_sql_private_ip
  depends_on                           = [google_project_service.apis, module.database, module.networking]
  datastream_private_connection_subnet = var.datastream_private_connection_subnet
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

  depends_on = [google_project_service.apis]
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
  depends_on                          = [google_project_service.apis]
}

module "datastream_stream" {
  source                                = "../../modules/datastream-stream"
  project_id                            = var.project_id
  region                                = var.region
  environment                           = var.environment
  bigquery_dataset_id                   = module.bigquery.bigquery_dataset_id
  source_connection_profile_object      = module.datastream_core.datastream_source_connection_profile_object
  destination_connection_profile_object = module.datastream_core.datastream_destination_connection_profile_object

  depends_on = [
    google_project_service.apis,
    module.datastream_core,
    module.database.datastream_setup,
    module.database.postgresql_setup_completed
  ]
}