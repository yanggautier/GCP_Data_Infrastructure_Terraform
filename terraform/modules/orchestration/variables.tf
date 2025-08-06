variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "region" {
  description = "The GCP region."
  type        = string
}

variable "environment" {
  description = "The environment (e.g., dev, staging, prod)."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC network."
  type        = string   
}

variable "dbt_namespace" {
  description = "Namespace for DBT in GKE."
  type        = string
  default     = "dbt"
}

variable "gke_subnet_id" {
  description = "ID of the subnetwork for the GKE cluster."
  type        = string  
}

# ------------------ Variables for GKE ----------------------
variable "cluster_deletion_protection" {
  description = "Enable deletion protection for the GKE cluster"
  type        = bool
}

variable "gke_master_ipv4_cidr_block" {
  description = "CIDR block for the GKE master IP."
  type        = string
}

variable "dbt_service_account_email" {
  description = "Email of the DBT service account."
  type        = string
}
variable "dbt_service_account_id" {
  description = "ID of the DBT service account."
  type        = string
}
# ------------- Variables for Cloud Composer ----------------
variable "cloud_composer_version" {
  description = "Version of Cloud Composer to use."
  type        = string
  default     = "composer-3-airflow-2.9.3"
}

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

# ------------------ Variables for BigQuery ------------------
variable "bigquery_bronze_dataset_id" {
  description = "ID of the BigQuery dataset."
  type        = string  
}
