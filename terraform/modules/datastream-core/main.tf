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
    #subnet = "10.200.0.0/24" 
    subnet = "10.223.100.0/24"
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
