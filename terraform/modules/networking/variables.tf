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

variable "subnetwork_address" {
  description = "CIDR range for the subnetwork"
  type        = string
}

variable "datastream_service_account_email" {
  description = "Email of the Datastream service account."
  type        = string
}
