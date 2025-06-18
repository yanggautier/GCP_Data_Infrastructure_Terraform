variable "cloud_sql_user_name" {
  description = "Cloud SQL user "
  type        = string
  default     = "dvd_rental_user"  
}

variable "bigquery_owner_user" {
    description = "value for the owner of the BigQuery dataset"
    type = string
    default = "yangguole@outlook.com"
}