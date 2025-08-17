output "data_bucket_name" {
  description = "Name of the data GCS bucket."
  value       = google_storage_bucket.data-bucket.name
}

output "data_bucket_self_link" {
  description = "Self link of the data GCS bucket."
  value       = google_storage_bucket.data-bucket.self_link
}

output "dbt_bucket_name" {
  description = "Name of the DBT GCS bucket."
  value       = google_storage_bucket.dbt-bucket.name
}

output "dbt_doc_bucket_name" {
  description = "Name of the DBT Docs GCS bucket."
  value       = google_storage_bucket.dbt-doc-bucket.name
}

output "dbt_doc_bucket_self_link" {
  description = "Self link of the DVD rental GCS bucket."
  value       = google_storage_bucket.dbt-doc-bucket.self_link
}