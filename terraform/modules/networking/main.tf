# Create a VPC network for Datastream and dbt GKE cluster
resource "google_compute_network" "vpc" {
  name                    = "datastream-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Create a subnetwork for Datastream
resource "google_compute_subnetwork" "datastream_subnet" {
  project       = var.project_id
  region        = var.region
  name          = "datastream-subnet"
  ip_cidr_range = var.datastream_subnetwork_address
  network       = google_compute_network.vpc.id
}

# Create a subnetwork for the dbt GKE cluster
resource "google_compute_subnetwork" "gke_subnet" {
  project       = var.project_id
  region        = var.region
  name          = "dbt-cluster-subnet"
  ip_cidr_range = var.gke_subnetwork_address
  network       = google_compute_network.vpc.id
  # Enable private IP Google access for GKE
  private_ip_google_access = true
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.gke_secondary_pod_range
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.gke_secondary_service_range
  }
}

# Create a global address for private IP allocation
resource "google_compute_global_address" "private_ip_alloc" {
  project       = var.project_id
  name          = "private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

# Authorise Datastream to acces Cloud SQL
resource "google_compute_firewall" "allow_datastream_to_sql" {
  name    = "allow-datastream-to-sql"
  network = google_compute_network.vpc.name
  project = var.project_id
  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }
  direction = "INGRESS"
  source_ranges = [
    var.datastream_subnetwork_address, # Datastream subnet
    "10.3.0.0/24",                     # Private connection subnet for Datastream
    "169.254.0.0/16",                  # Google internal networking
    "${google_compute_global_address.private_ip_alloc.address}/${google_compute_global_address.private_ip_alloc.prefix_length}",
  ]
  priority = 500
}

# Autorise tout le range interne (10.0.0.0/8) vers Cloud SQL (port 5432)
resource "google_compute_firewall" "allow_all_internal_to_sql" {
  name    = "allow-all-internal-to-sql"
  network = google_compute_network.vpc.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  direction     = "INGRESS"
  source_ranges = ["10.0.0.0/8"]

  priority = 400
}

# Authorise GKE cluster to access Cloud SQL
resource "google_compute_firewall" "allow_gke_to_sql" {
  name    = "allow-gke-to-sql"
  network = google_compute_network.vpc.name
  project = var.project_id
  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }
  direction = "INGRESS"
  source_ranges = [
    var.gke_subnetwork_address, # GKE subnet
  ]
  priority = 501
}

# Authorise services to access vpc subnetworks
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal-vpc"
  network = google_compute_network.vpc.name
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
  direction = "INGRESS"
  // source_ranges = ["10.0.0.0/8"]
  source_ranges = [
    var.gke_subnetwork_address,        # GKE subnet
    var.datastream_subnetwork_address, # Datastream subnet
  ]
  priority = 65534
}

# Add a second private IP allocation for Cloud Build Private Pool
resource "google_compute_global_address" "private_ip_alloc_cb" {
  project       = var.project_id
  name          = "private-ip-alloc-cb" # Distinct name for Cloud Build
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16 # A /16 block is recommended for expandability
  network       = google_compute_network.vpc.id
}

# Pricate VPC connection for Cloud SQL
resource "google_service_networking_connection" "private_vpc_connection" {
  network = google_compute_network.vpc.id
  service = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name,
  google_compute_global_address.private_ip_alloc_cb.name]
  timeouts {
    create = "10m"
    delete = "10m"
  }
}
