# ---------------------------------- Project level variables ------------------------------
variable "project_id" {
  description = "Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
}

variable "environment" {
  description = "Environment for the resources (e.g., dev, staging, prod)"
  type        = string
}

# ---------------------- Superset configuration variables ------------------------------
variable "superset_namespace" {
  description = "Superset namespace for GKE"
  type        = string
  default     = "superset"
}

variable "kubernetes_service_account_email" {
  description = "Email of Kubernetes service account"
  type        = string
}

variable "kubernetes_service_account_id" {
  description = "ID of the Kubernetes service account."
  type        = string
}

variable "superset_request_cpu" {
  description = "Superset container requests cpu in Kubernetes"
  type        = string
  default     = "500m"
}

variable "superset_request_memory" {
  description = "Superset container requests memory in Kubernetes"
  type        = string
  default     = "1Gi"
}

variable "superset_limit_cpu" {
  description = "Superset container limits cpu in Kubernetes"
  type        = string
  default     = "1000m"
}

variable "superset_limit_memory" {
  description = "Superset container limits memory in Kubernetes"
  type        = string
  default     = "2Gi"
}

# Superset auth variables
variable "superset_admin_username" {
  description = "Username pour l'administrateur Superset"
  type        = string
  default     = "admin"
}

variable "superset_admin_password" {
  description = "Mot de passe pour l'administrateur Superset"
  type        = string
  sensitive   = true
}

variable "superset_admin_firstname" {
  description = "Prénom de l'administrateur Superset"
  type        = string
  default     = "Admin"
}

variable "superset_admin_lastname" {
  description = "Nom de l'administrateur Superset"
  type        = string
  default     = "User"
}

variable "superset_admin_email" {
  description = "Email de l'administrateur Superset"
  type        = string
}

/*
# PostgreSQL Variables
variable "postgresql_database" {
  description = "Nom de la base de données PostgreSQL"
  type        = string
  default     = "superset"
}

variable "postgresql_username" {
  description = "Username PostgreSQL"
  type        = string
  default     = "superset"
}

variable "postgresql_password" {
  description = "Mot de passe PostgreSQL"
  type        = string
  sensitive   = true
}
*/

variable "superset_service_port" {
  description = "Port du service Superset"
  type        = number
  default     = 8088
}

# Variables générales
variable "superset_namespace" {
  description = "Namespace Kubernetes pour Superset"
  type        = string
  default     = "superset"
}

variable "superset_chart_version" {
  description = "Version du chart Helm Superset"
  type        = string
  default     = "0.15.0"
}
# ---------------------------------- Proxy configuration variables ------------------------------
variable "proxy_request_cpu" {
  description = "Cloud sql proxy container request cpu in Kubernetes"
  type        = string
  default     = "100m"
}

variable "proxy_request_memory" {
  description = "Cloud sql proxy container request memory in Kubernetes"
  type        = string
  default     = "128Mi"
}

variable "proxy_limit_cpu" {
  description = "Cloud sql proxy container request cpu in Kubernetes"
  type        = string
  default     = "200m"
}

variable "proxy_limit_memory" {
  description = "Cloud sql proxy container request cpu in Kubernetes"
  type        = string
  default     = "256Mi"
}

# ------------------------- Cloud SQL variables---------------------------------- 
variable "cloud_sql_instance_name" {
  description = "Name of PostgreSQL Cloud SQL instance"
  type        = string
}

variable "superset_database_user_name" {
  description = "Cloud SQL PostgreSQL database user name for Superset"
  type        = string
}

variable "superset_db_password" {
  description = "Cloud SQL PostgreSQL database password for Superset"
  type        = string
}

variable "superset_database_name" {
  description = "Cloud SQL PostgreSQL database name for Superset"
  type        = string
}

# --------------------------- Memorystore variables -----------------------------------
variable "superset_redis_cache_host" {
  description = "Host of Redis Memorystore"
  type        = string
}

# --------------------------- Artifact Repositoy variables -----------------------------------
variable "repository_id" {
  description = "Artifact repository id"
  type        = string
}

variable "repository_name" {
  description = "Artifact repository name"
  type        = string
}