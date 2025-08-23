# ---------------------- Project level variables ------------------------------
# Terraform variables for the dev environment
variable "project_id" {
  description = "Project ID"
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

# ---------------------- Business database variables ------------------------------
variable "business_database_name" {
  description = "Name of the Cloud SQL database"
  type        = string
  default     = "my_db"
}

variable "business_database_user_name" {
  description = "Cloud SQL user "
  type        = string
  default     = "db_user"
}

# ---------------------- Superset database variables ------------------------------
variable "superset_database_name" {
  description = "Name of the Cloud SQL superset database"
  type        = string
}

variable "superset_database_user_name" {
  description = "Cloud SQL user for Superset database"
  type        = string
}

# ---------------------- BigQuery IAM variables ------------------------------
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


# ---------------------- Networking variables ------------------------------
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


# ---------------------- Secret Manager variables ------------------------------
# Secret name for the Cloud SQL database password in Secret Manager
variable "business_db_password_secret_name" {
  description = "Secret name form Secret Manager"
  type        = string
}

# Secret version for the Cloud SQL database password in Secret Manager
variable "business_secret_version" {
  description = "Version of secret in Secret Manager"
  type        = number
  default     = 1
}

variable "superset_db_password_secret_name" {
  description = "Secret name form Secret Manager"
  type        = string
}

# Secret version for the Cloud SQL database password in Secret Manager
variable "superset_secret_version" {
  description = "Version of secret in Secret Manager"
  type        = number
  default     = 1
}

# ------------------------ GKE variables ------------------------------
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

variable "cluster_deletion_protection" {
  description = "Enable deletion protection for the GKE cluster"
  type        = bool
  default     = false
}

variable "gke_master_ipv4_cidr_block" {
  description = "CIDR block for the GKE master IP."
  type        = string
}

# ---------------------- Cloud Composer variables ------------------------------
# Cloud Composer variables
variable "cloud_composer_size" {
  description = "Size of the Cloud Composer environment."
  type        = string
  default     = "ENVIRONMENT_SIZE_SMALL"
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

variable "admin_email" {
  description = "Admin email for cloud composer dag run failure"
  type        = string
}
