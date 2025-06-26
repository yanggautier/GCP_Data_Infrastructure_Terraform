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

variable "database_name" {
  description = "Name of the Cloud SQL database"
  type        = string
}

variable "database_user_name" {
  description = "Cloud SQL user "
  type        = string
}

variable "datastream_vpc_id" {
  description = "ID of the Datastream VPC network."
  type        = string
}

variable "private_vpc_connection_id" {
  description = "ID of the private VPC connection for Cloud SQL."
  type        = string
}

variable "instance_tier" {
  description = "The machine type for the Cloud SQL instance."
  type        = string
}

variable "disk_size" {
  description = "The disk size for the Cloud SQL instance in GB."
  type        = number
}

variable "backup_enabled" {
  description = "Whether automatic backups are enabled."
  type        = bool
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled for the Cloud SQL instance."
  type        = bool
}

variable "max_replication_slots" {
  description = "Maximum number of replication slots for PostgreSQL."
  type        = number
}

variable "max_wal_senders" {
  description = "Maximum number of WAL sender processes for PostgreSQL."
  type        = number
}

variable "allow_datastream_to_proxy_id" {
  description = "ID of the firewall rule allowing Datastream to proxy for explicit dependency."
  type        = string
  default     = ""
}

variable "db_password_secret_name" {
  description = "Name of the Secret Manager secret holding the database password"
  type        = string
}

variable "datastream_vpc_name" {
  description = "Datastream VPC name"
  type        = string
}

variable "datastream_subset_name" {
  description = "Datastream VPC subset name"
  type        = string
}

variable "private_vpc_connection" {
  description = "The google_service_networking_connection resource."
  type        = any 
}