# Crée un compte de service pour Datastream
resource "google_service_account" "datastream_service_account" {
  account_id   = "datastream-service-account"
  display_name = "Datastream Service Account"
  project      = var.project_id
}

# Attribue les rôles au compte de service Datastream
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
    subnet = "10.3.0.0/24" # Ce CIDR doit être unique et ne pas chevaucher le subnet Datastream VPC
  }

  depends_on = [
    var.private_vpc_connection_id # Dépend de la connexion VPC privée pour Cloud SQL
  ]

  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }
}

# Récupère le mot de passe de la base de données depuis Secret Manager
data "google_secret_manager_secret_version" "db_password_secret" {
  secret  = var.db_password_secret_name
  project = var.project_id
}


# Crée un profil de connexion Datastream pour la source PostgreSQL (via proxy)
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

# Crée un profil de connexion Datastream pour la destination BigQuery
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
