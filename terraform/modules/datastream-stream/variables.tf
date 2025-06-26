# terraform/modules/datastream-stream/variables.tf

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

# Les objets des profils de connexion sont passés ici
variable "source_connection_profile_object" {
  description = "The Datastream source connection profile object from datastream-core module."
  type        = object({
    id = string
    # Ajoutez d'autres attributs si vous en avez besoin, par exemple 'name', 'location', etc.
    # Assurez-vous que ces attributs sont bien des outputs du module datastream-core
  })
}

variable "destination_connection_profile_object" {
  description = "The Datastream destination connection profile object from datastream-core module."
  type        = object({
    id = string
  })
}

variable "bigquery_dataset_id" {
  description = "ID of the BigQuery dataset where data will be streamed."
  type        = string
}