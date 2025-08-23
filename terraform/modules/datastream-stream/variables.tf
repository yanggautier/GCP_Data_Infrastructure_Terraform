# ---------------------------------- Project level variables ------------------------------
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

# ---------------------------------- Datastream configuration variables ------------------------------
variable "source_connection_profile_object" {
  description = "The Datastream source connection profile object from datastream-core module."
  type = object({
    id = string
  })
}

variable "destination_connection_profile_object" {
  description = "The Datastream destination connection profile object from datastream-core module."
  type = object({
    id = string
  })
}

# ---------------------------------- BigQuey variables ------------------------------
variable "bigquery_bronze_dataset_id" {
  description = "ID of the BigQuery dataset where data will be streamed."
  type        = string
}