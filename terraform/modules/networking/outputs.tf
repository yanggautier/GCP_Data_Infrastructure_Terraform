output "datastream_vpc_id" {
  description = "ID of the Datastream VPC network."
  value       = google_compute_network.datastream_vpc.id
}

output "datastream_vpc_name" {
  description = "Name of the Datastream VPC network."
  value       = google_compute_network.datastream_vpc.name
}

output "datastream_subnet_id" {
  description = "ID of the Datastream subnetwork."
  value       = google_compute_subnetwork.datastream_subnet.id
}

output "datastream_subnet_name" {
  description = "Name of the Datastream subnetwork."
  value       = google_compute_subnetwork.datastream_subnet.name
}

output "private_ip_alloc_name" {
  description = "Name of the private IP allocation for VPC peering."
  value       = google_compute_global_address.private_ip_alloc.name
}

output "allow_datastream_to_proxy_id" {
  description = "ID of the firewall rule allowing Datastream to proxy."
  value       = google_compute_firewall.allow_datastream_to_proxy.id
}

output "private_vpc_connection" {
  value = google_service_networking_connection.private_vpc_connection
}