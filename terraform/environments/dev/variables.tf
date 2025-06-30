# Inclut les variables globales du répertoire partagé
# Note: Dans un vrai projet, ces variables seraient définies dans le fichier commun
# et utilisées ici, ou overridees si nécessaire. Pour cet exemple, je les redéfinis pour la clarté.
variable "project_id" {
  description = "DVD Project ID"
  type        = string
  default     = "dbt-project-dvd-rent-464116"
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "state_file_bucket" {
  description = "Bucker for state files"
  type        = string
  default     = "state-file-dev-buckets"
}

variable "environment" {
  description = "Environment for the resources (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
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
  default     = "yangguole@outlook.com"
}

variable "bigquery_analyst_user" {
  description = "Email of the BigQuery analyst user"
  type        = string
  default     = "inmoglio@gmail.com"
}

variable "bigquery_contributor_user" {
  description = "Email of the BigQuery contributor user"
  type        = string
  default     = "guoleyang@gmail.com"
}

variable "subnetwork_address" {
  description = "CIDR range for the subnetwork"
  type        = string
  default     = "10.2.0.0/24"
}

variable "datastream_private_connection_subnet" {
  description = "Subnet of private connection for peering"
  type        = string
  default     = "10.200.0.0/24"
}

variable "db_password_secret_name" {
  description = "Secret name form Secret Manager"
  type        = string
  default     = "postgres-instance-password"
}

# Ceci est un exemple pour inclure les locals partagés
# Dans un environnement réel, vous pourriez les gérer via un fichier `backend.tf`
# ou en les passant en tant que variables. Pour l'exemple, nous allons les redéfinir
# comme une source locale pour les modules qui en ont besoin.
locals {
  env_config = {
    dev = {
      instance_tier         = "db-f1-micro"
      disk_size             = 20
      backup_enabled        = false
      deletion_protection   = false
      max_replication_slots = 10
      max_wal_senders       = 10
    }
    staging = {
      instance_tier         = "db-custom-1-3840"
      disk_size             = 50
      backup_enabled        = true
      deletion_protection   = false
      max_replication_slots = 50
      max_wal_senders       = 50
    }
    prod = {
      instance_tier         = "db-custom-2-4096"
      disk_size             = 100
      backup_enabled        = true
      deletion_protection   = true
      max_replication_slots = 100
      max_wal_senders       = 100
    }
  }
  current_env = local.env_config[var.environment]
}

variable "secret_version" {
  description = "Version of secret in Secret Manager"
  type        = number
  default     = 1
}