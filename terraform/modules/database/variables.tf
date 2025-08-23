# --------------------- Project configuration Variables ----------------------------
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

# --------------------- VPC configuration variables ----------------------------
variable "vpc_id" {
  description = "ID of the Datastream VPC network."
  type        = string
}

variable "private_vpc_connection_id" {
  description = "ID of the private VPC connection for Cloud SQL."
  type        = string
}

variable "vpc_name" {
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
# --------------------- Cloud SQL instance configuration variables ----------------------------
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

# ----------------------- Business database configuration variables ----------------------------
variable "business_database_name" {
  description = "Name of the Cloud SQL database"
  type        = string
}

variable "business_database_user_name" {
  description = "Cloud SQL user "
  type        = string
}

variable "max_replication_slots" {
  description = "Maximum number of replication slots for PostgreSQL."
  type        = number
}

variable "max_wal_senders" {
  description = "Maximum number of WAL sender processes for PostgreSQL."
  type        = number
}

# --------------------- Supereset database configuration variables ----------------------------
variable "superset_database_name" {
  description = "Name of the Cloud SQL superset database"
  type        = string
}

variable "superset_database_user_name" {
  description = "Cloud SQL user for Superset database"
  type        = string
}

# ------------------------ Memorystore configuration variables -----------------------------
variable "redis_memory_size_gb" {
  description = "Memory size for Memorystore Redis instance (Gb)"
  type        = number
  default     = 1
}

variable "redis_instance_tier" {
  description = "Tier of Memorystore Redis instance"
  type        = string
  default     = "BASIC"
}

# --------------------- Secret Manager configuration variables ----------------------------
variable "business_db_password_secret_name" {
  description = "Name of the Secret Manager secret holding the database password"
  type        = string
}

variable "business_secret_version" {
  description = "Version of secret in Secret Manager"
  type        = number
}

variable "superset_db_password_secret_name" {
  description = "Name of the Secret Manager secret holding the database password"
  type        = string
}

variable "superset_secret_version" {
  description = "Version of secret in Secret Manager"
  type        = number
}