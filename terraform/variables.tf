variable "project_id" {
  description = "DVD Project ID"
  type        = string
  default     = "dvd-rental-project" # Replace with your GCP project ID
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
  default = "dev"
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
  description = "value for the owner of the BigQuery dataset"
  type        = string
  default     = "yangguole@outlook.com"
}

variable "bigquery_analyst_user" {
  description = "Email of the first analyst user"
  type        = string
  default     = "inmoglio@gmail.com"
}

variable "bigquery_contributor_user" {
  description = "Email of the first analyst user"
  type        = string
  default     = "guoleyang@gmail.com"
}

