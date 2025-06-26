variable "project_id" {
  description = "DVD Project ID"
  type        = string
  default     = "dvd-rental-project-staging" # Remplacez par votre ID de projet staging
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "europe-west9"
}

variable "environment" {
  description = "Environment for the resources (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "state_file_bucket" {
  description = "Bucker for state files"
  type = string
  default = "state-files-prod" 
}

variable "database_name" {
  description = "Name of the Cloud SQL database"
  type        = string
  default     = "dvd_rental_db"
}

variable "database_user_name" {
  description = "Cloud SQL user "
  type        = string
  default     = "dvd_rental_user"
}

variable "bigquery_owner_user" {
  description = "Email for the owner of the BigQuery dataset"
  type        = string
  default     = "staging_owner@example.com" # Mettez une adresse mail réelle
}

variable "bigquery_analyst_user" {
  description = "Email of the BigQuery analyst user"
  type        = string
  default     = "staging_analyst@example.com" # Mettez une adresse mail réelle
}

variable "bigquery_contributor_user" {
  description = "Email of the BigQuery contributor user"
  type        = string
  default     = "staging_contributor@example.com" # Mettez une adresse mail réelle
}

variable "subnetwork_address" {
  description = "CIDR range for the subnetwork"
  type        = string
  default     = "10.2.0.0/24"
}

locals {
  env_config = {
    dev = {
      instance_tier           = "db-f1-micro"
      disk_size               = 20
      backup_enabled          = false
      deletion_protection     = false
      max_replication_slots = 10
      max_wal_senders       = 10
    }
    staging = {
      instance_tier           = "db-custom-1-3840"
      disk_size               = 50
      backup_enabled          = true
      deletion_protection     = false
      max_replication_slots = 50
      max_wal_senders       = 50
    }
    prod = {
      instance_tier           = "db-custom-2-4096"
      disk_size               = 100
      backup_enabled          = true
      deletion_protection     = true
      max_replication_slots = 100
      max_wal_senders       = 100
    }
  }
  current_env = local.env_config[var.environment]
}