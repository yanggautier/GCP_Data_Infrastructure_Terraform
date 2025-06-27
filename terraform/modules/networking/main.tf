# Crée un réseau VPC et un sous-réseau pour Datastream
resource "google_compute_network" "datastream_vpc" {
  name                    = "datastream-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Crée un sous-réseau pour Datastream
resource "google_compute_subnetwork" "datastream_subnet" {
  project       = var.project_id
  region        = var.region
  name          = "datastream-subnet"
  ip_cidr_range = var.subnetwork_address
  network       = google_compute_network.datastream_vpc.id
}

# Réserve une plage d'adresses IP pour les services privés (Cloud SQL)
resource "google_compute_global_address" "private_ip_alloc" {
  project       = var.project_id
  name          = "private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.datastream_vpc.id
}

# Crée une connexion de service privée pour Cloud SQL
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.datastream_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
  timeouts {
    create = "10m"
    delete = "10m"
  }
}

# Règles de pare-feu pour la connectivité Datastream
resource "google_compute_firewall" "allow_datastream_to_sql" {
  name    = "allow-datastream-to-sql"
  network = google_compute_network.datastream_vpc.name
  project = var.project_id
  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }
  direction = "INGRESS"
  source_ranges = [
    var.subnetwork_address, # Datastream subnet
    "10.3.0.0/24",        # Private connection subnet for Datastream
    "169.254.0.0/16",     # Google internal networking
    "${google_compute_global_address.private_ip_alloc.address}/${google_compute_global_address.private_ip_alloc.prefix_length}"
  ]
  priority    = 1000
}

# Autorise la communication interne au VPC
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal-vpc"
  network = google_compute_network.datastream_vpc.name
  project = var.project_id
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }
  direction   = "INGRESS"
  source_ranges = ["10.0.0.0/8"]
  priority    = 65534
}
