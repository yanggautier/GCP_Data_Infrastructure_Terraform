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

variable "datastream_subnetwork_address" {
  description = "CIDR range for the subnetwork"
  type        = string
}

variable "gke_subnetwork_address" {
  description = "CIDR range for the dbt gke clustor subnetwork"
  type        = string
}

variable "gke_secondary_pod_range" {
  description = "Secondary IP range for GKE pods"
  type        = string
}

variable "gke_secondary_service_range" {
  description = "Secondary IP range for GKE services"
  type        = string
}
/*
variable "datastream_service_account_email" {
  description = "Email of the Datastream service account."
  type        = string
}
*/
