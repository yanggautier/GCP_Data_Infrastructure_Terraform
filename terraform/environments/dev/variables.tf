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
}

variable "bigquery_analyst_user" {
  description = "Email of the BigQuery analyst user"
  type        = string
}

variable "bigquery_contributor_user" {
  description = "Email of the BigQuery contributor user"
  type        = string
}

# Subnetwork for Datastream
variable "datastream_subnetwork_address" {
  description = "CIDR range for the subnetwork"
  type        = string
  default     = "10.2.0.0/24"
}

# SUbnetwork for the dbt GKE cluster
variable "gke_subnetwork_address" {
  description = "CIDR range for the subnetwork"
  type        = string
  default     = "10.4.0.0/24"
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

variable "secret_version" {
  description = "Version of secret in Secret Manager"
  type        = number
  default     = 1
}

# Secondary subnet used for GKE Pods (Alias IP ranges)
variable "gke_secondary_pod_range" {
  description = "Secondary IP range for GKE pods"
  type        = string
  default     = "10.10.0.0/16"
}

# Secondary subnet used for GKE Services (Alias IP ranges)
variable "gke_secondary_service_range" {
  description = "Secondary IP range for GKE services"
  type        = string
  default     = "10.20.0.0/20"
}

variable "gke_master_ipv4_cidr_block" {
  description = "CIDR block for the GKE master IP."
  type        = string
  default     = "172.16.0.0/28"
}

# Cloud Composer variables
variable "cloud_composer_size" {
  description = "Size of the Cloud Composer environment."
  type        = string
  default     = "composer-size-small"
}

variable "cloud_composer_scheduler_cpu" {
  description = "CPU count for the Cloud Composer scheduler."
  type        = number
  default     = 1
}

variable "cloud_composer_scheduler_memory_gb" {
  description = "Memory in GB for the Cloud Composer scheduler."
  type        = number
  default     = 2
}

variable "cloud_composer_scheduler_storage_gb" {
  description = "Storage in GB for the Cloud Composer scheduler."
  type        = number
  default     = 1
}

variable "cloud_composer_webserver_cpu" {
  description = "CPU count for the Cloud Composer web server."
  type        = number
  default     = 1
}

variable "cloud_composer_websever_memory_gb" {
  description = "Memory in GB for the Cloud Composer web server."
  type        = number
  default     = 2
}

variable "cloud_composer_webserver_storage_gb" {
  description = "Storage in GB for the Cloud Composer web server."
  type        = number
  default     = 1
}

variable "cloud_composer_worker_cpu" {
  description = "CPU count for the Cloud Composer worker."
  type        = number
  default     = 1
}

variable "cloud_composer_worker_memory_gb" {
  description = "Memory in GB for the Cloud Composer worker."
  type        = number
  default     = 2
}

variable "cloud_composer_worker_storage_gb" {
  description = "Storage in GB for the Cloud Composer worker."
  type        = number
  default     = 10
}