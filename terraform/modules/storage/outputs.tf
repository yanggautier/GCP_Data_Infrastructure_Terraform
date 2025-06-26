output "dvd_rental_bucket_name" {
  description = "Name of the DVD rental GCS bucket."
  value       = google_storage_bucket.dvd-rental-bucket.name
}

output "dvd_rental_bucket_self_link" {
  description = "Self link of the DVD rental GCS bucket."
  value       = google_storage_bucket.dvd-rental-bucket.self_link
}

output "dbt_bucket_name" {
  description = "Name of the DBT GCS bucket."
  value       = google_storage_bucket.dbt-bucket.name
}