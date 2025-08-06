output "bigquery_bronze_dataset_id" {
  description = "ID of the BigQuery bronze dataset."
  value       = google_bigquery_dataset.bronze_dataset.id
}

output "bigquery_silver_dataset_id" {
  description = "ID of the BigQuery silver dataset."
  value       = google_bigquery_dataset.silver_dataset.id
}

output "bigquery_gold_dataset_id" {
  description = "ID of the BigQuery gold dataset."
  value       = google_bigquery_dataset.gold_dataset.id
}