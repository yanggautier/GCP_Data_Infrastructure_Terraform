output "vpc_id" {
  description = "ID of the Datastream VPC network."
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "Name of the Datastream VPC network."
  value       = google_compute_network.vpc.name
}

output "vpc_self_link" {
  description = "VPC self link"
  value       = google_compute_network.vpc.self_link
}

# Réseau VPC pour Datastream
output "datastream_subnet_id" {
  description = "ID of the Datastream subnetwork."
  value       = google_compute_subnetwork.datastream_subnet.id
}

output "datastream_subnet_name" {
  description = "Name of the Datastream subnetwork."
  value       = google_compute_subnetwork.datastream_subnet.name
}

# Outputs for Datastream VPC and subnetwork for DBT orchestration
output "gke_subnet_id" {
  description = "ID of the Datastream subnetwork."
  value       = google_compute_subnetwork.gke_subnet.id
}

output "gke_subnet_name" {
  description = "Name of the Datastream subnetwork."
  value       = google_compute_subnetwork.datastream_subnet.name
}

output "private_ip_alloc_name" {
  description = "Name of the private IP allocation for VPC peering."
  value       = google_compute_global_address.private_ip_alloc.name
}

output "private_vpc_connection" {
  value = google_service_networking_connection.private_vpc_connection
}