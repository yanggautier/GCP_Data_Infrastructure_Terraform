output "bigquery_dataset_id" {
  description = "ID of the BigQuery dataset."
  value       = google_bigquery_dataset.dvd_rental_bigquery_dataset.id
}