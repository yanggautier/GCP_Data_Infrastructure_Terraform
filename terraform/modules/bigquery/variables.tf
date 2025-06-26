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

variable "datastream_service_account_email" {
  description = "Email of the Datastream service account."
  type        = string
}