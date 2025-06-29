resource "google_service_account" "datastream_service_account" {
  account_id   = "datastream-service-account"
  display_name = "Datastream Service Account"
  project      = var.project_id
}

resource "google_project_iam_member" "datastream_admin" {
  project = var.project_id
  role    = "roles/datastream.admin"
  member  = "serviceAccount:${google_service_account.datastream_service_account.email}"
}

resource "google_project_iam_member" "bigquery_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.datastream_service_account.email}"
}

resource "google_project_iam_member" "cloud_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.datastream_service_account.email}"
}

resource "google_project_iam_member" "access_secret_manager" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.datastream_service_account.email}"
}

# Crée une connexion privée Datastream
resource "google_datastream_private_connection" "private_connection" {
  display_name        = "Datastream Private Connection"
  project             = var.project_id
  location            = var.region
  private_connection_id = "datastream-connection-${var.environment}"

  vpc_peering_config {
    vpc    = var.datastream_vpc_id
    subnet = var.datastream_private_connection_subnet
  }

  depends_on = [
    var.private_vpc_connection_id 
  ]

  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }
}

data "google_secret_manager_secret_version" "db_password_secret" {
  secret  = var.db_password_secret_name
  project = var.project_id
}


# Create a reverse proxy VM for Cloud SQL access (required for private IP)
resource "google_compute_instance" "datastream_proxy" {
  project      = var.project_id
  name         = "datastream-proxy-${var.environment}"
  machine_type = "e2-micro"
  zone         = "${var.region}-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 10
    }
  }

  network_interface {
    network    = var.datastream_vpc_id
    subnetwork = var.datastream_subnet_id
    
    # No external IP needed
  }

  service_account {
    email  = google_service_account.datastream_service_account.email
    scopes = ["cloud-platform"]
  }

  tags = ["datastream-proxy"]

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y postgresql-client
    
    # Install socat for port forwarding
    apt-get install -y socat
    
    # Create a service to forward connections to Cloud SQL
    cat > /etc/systemd/system/datastream-proxy.service << 'EOL'
[Unit]
Description=SQL Proxy Service
After=network.target

[Service]
Type=simple
User=postgres
ExecStart=/usr/bin/socat TCP4-LISTEN:5432,fork,reuseaddr TCP4:${var.cloud_sql_private_ip}:5432
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

    # Create postgres user and start service
    useradd -m postgres || true
    systemctl enable datastream-proxy.service
    systemctl start datastream-proxy.service
  EOF

  depends_on = [
    google_service_account.datastream_service_account
  ]
}

# Firewall rule for SQL proxy
resource "google_compute_firewall" "allow_datastream_to_proxy" {
  name    = "allow-datastream-to-proxy"
  network = var.datastream_vpc_id
  project = var.project_id
  
  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  direction = "INGRESS"
  source_ranges = [
    var.datastream_private_connection_subnet
  ]

  target_tags = ["datastream-proxy"]
  priority    = 1000
}


resource "google_datastream_connection_profile" "source" {
  display_name        = "PostgreSQL Source Connection Profile"
  project             = var.project_id
  location            = var.region
  connection_profile_id = "postgresql-source-${var.environment}"

  postgresql_profile {
    hostname = var.cloud_sql_private_ip
    port     = 5432
    database = var.database_name
    username = var.database_user_name
    password = data.google_secret_manager_secret_version.db_password_secret.secret_data
  }

  private_connectivity {
    private_connection = google_datastream_private_connection.private_connection.id
  }

  timeouts {
    create = "30m"
    update = "30m"
  }

  depends_on = [
    google_datastream_private_connection.private_connection
  ]
}

resource "google_datastream_connection_profile" "destination" {
  display_name        = "BigQuery Destination Connection Profile"
  project             = var.project_id
  location            = var.region
  connection_profile_id = "bigquery-destination-${var.environment}"

  bigquery_profile {}

  private_connectivity {
    private_connection = google_datastream_private_connection.private_connection.id
  }

  depends_on = [
    var.bigquery_dataset_id,
    google_datastream_private_connection.private_connection
  ]
}
