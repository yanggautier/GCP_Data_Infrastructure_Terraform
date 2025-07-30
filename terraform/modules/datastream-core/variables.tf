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

variable "datastream_private_connection_subnet" {
  description = "Subenet of private connection for peering"
  type = string
}

variable "vpc_id" {
  description = "ID of the Datastream VPC network."
  type        = string
}

variable "datastream_subnet_id" {
  description = "Datastream subnet id"
  type = string
}

variable "private_vpc_connection_id" {
  description = "ID of the private VPC connection for Cloud SQL."
  type        = string
}

variable "cloud_sql_private_ip" {
  description = "The private IP address of the Cloud SQL instance."
  type        = string
}


variable "database_name" {
  description = "Name of the Cloud SQL database."
  type        = string
}

variable "database_user_name" {
  description = "Cloud SQL user."
  type        = string
}

variable "bigquery_dataset_id" {
  description = "ID of the BigQuery dataset."
  type        = string
}

variable "wait_for_sql_instance_id" {
  description = "ID of the time_sleep resource waiting for SQL instance readiness."
  type        = string
}

variable "db_password_secret_name" {
  description = "Secret of Secret Manager."
  type        = string
}

