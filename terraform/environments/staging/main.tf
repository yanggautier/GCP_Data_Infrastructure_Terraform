terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
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

# Get secret form Secret Manager
data "google_secret_manager_secret_version" "db_password_secret" {
  secret  = "postgres-instance-password"
  project = var.project_id
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
  source                           = "../../modules/networking"
  project_id                       = var.project_id
  region                           = var.region
  environment                      = var.environment
  subnetwork_address               = var.subnetwork_address
  datastream_service_account_email = module.datastream_core.datastream_service_account_email
  cloud_sql_private_ip             = module.database.cloud_sql_private_ip
}

module "storage" {
  source      = "../../modules/storage"
  project_id  = var.project_id
  region      = var.region
  environment = var.environment
}

module "database" {
  source                    = "../../modules/database"
  project_id                = var.project_id
  region                    = var.region
  environment               = var.environment
  database_name             = var.database_name
  database_user_name        = var.database_user_name
  datastream_vpc_id         = module.networking.datastream_vpc_id
  private_vpc_connection_id = module.networking.private_ip_alloc_name
  instance_tier             = local.current_env.instance_tier
  disk_size                 = local.current_env.disk_size
  backup_enabled            = local.current_env.backup_enabled
  deletion_protection       = local.current_env.deletion_protection
  max_replication_slots     = local.current_env.max_replication_slots
  max_wal_senders           = local.current_env.max_wal_senders
}

# Remplacez l'ancien module "datastream" par "datastream_core"
module "datastream_core" {
  source                       = "../../modules/datastream-core"
  project_id                   = var.project_id
  region                       = var.region
  environment                  = var.environment
  datastream_vpc_id            = module.networking.datastream_vpc_id
  private_vpc_connection_id    = module.networking.private_ip_alloc_name
  sql_proxy_id                 = module.networking.sql_proxy_id
  sql_proxy_ip                 = module.networking.sql_proxy_ip
  database_name                = var.database_name
  database_user_name           = var.database_user_name
  db_password                  = data.google_secret_manager_secret_version.db_password_secret.secret_data
  bigquery_dataset_id          = module.bigquery.bigquery_dataset_id
  wait_for_sql_instance_id     = module.database.time_sleep_wait_for_sql_instance_id
  allow_datastream_to_proxy_id = module.networking.allow_datastream_to_proxy_id
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
}

module "orchestration" {
  source      = "../../modules/orchestration"
  project_id  = var.project_id
  region      = var.region
  environment = var.environment
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
    module.datastream_core
  ]
}