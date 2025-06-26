# Définitions des variables globales partagées

variable "project_id" {
  description = "DVD Project ID"
  type        = string
  default     = "dbt-project-dvd-rent" # Replace by you projet GCP ID
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "europe-west9"
}

variable "environment" {
  description = "Environment for the resources (e.g., dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "database_name" {
  description = "Name of the Cloud SQL database"
  type        = string
  default     = "dvd_rental_db"
}

variable "database_user_name" {
  description = "Cloud SQL user"
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

variable "subnetwork_address" {
  description = "CIDR range for the Datastream subnetwork"
  type        = string
  default     = "10.2.0.0/24"
}