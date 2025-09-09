/*
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "2.23.1"
    }
  }
}
*/
# ----------------- Configuration for Superset Deployment ---------------------
# Add IAM permission to have access Cloud SQL
resource "google_project_iam_member" "superset_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${var.kubernetes_service_account_email}"
}

# Grant Superset the ability to connect to a Cloud SQL instance
resource "google_project_iam_member" "superset_cloudsql_instanceUser" {
  project = var.project_id
  role    = "roles/cloudsql.instanceUser"
  member  = "serviceAccount:${var.kubernetes_service_account_email}"
}

# Grant Superset the ability to access secrets in Secret Manager
resource "google_project_iam_member" "superset_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${var.kubernetes_service_account_email}"
}

# Grant Superset the ability to create and manage databases in Cloud SQL
resource "google_project_iam_member" "superset_cloudsql_editor" {
  project = var.project_id
  role    = "roles/cloudsql.editor"
  member  = "serviceAccount:${var.kubernetes_service_account_email}"
}


resource "google_sql_user" "iam_service_account_user" {
  # Note: for Postgres only, GCP requires omitting the ".gserviceaccount.com" suffix
  # from the service account email due to length limits on database usernames.
  name     = trimsuffix(var.kubernetes_service_account_email, ".gserviceaccount.com")
  instance = var.cloud_sql_instance_name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

# Create a namespace for Superset
resource "kubernetes_namespace" "superset_namespace" {
  metadata {
    name = var.superset_namespace
  }

  timeouts {
    delete = "10m"
  }
}

# Create a Kubernetes service account to connect to GCP service account
resource "kubernetes_service_account" "superset_k8s_sa" {
  metadata {
    name      = "superset-k8s-sa"
    namespace = var.superset_namespace
    annotations = {
      "iam.gke.io/gcp-service-account" = var.kubernetes_service_account_email
    }
  }
  depends_on = [kubernetes_namespace.superset_namespace]

  lifecycle {
    create_before_destroy = true
  }
}

# Verify that the IAM permissions are correctly set
resource "null_resource" "verify_cloudsql_permissions" {
  triggers = {
    service_account = var.kubernetes_service_account_email
    instance_name   = var.cloud_sql_instance_name
  }

  provisioner "local-exec" {
    command = <<EOT
      echo "Verifying Cloud SQL permissions for ${var.kubernetes_service_account_email}"
      
      # Vérifier les permissions du service account
      gcloud projects get-iam-policy ${var.project_id} \
        --flatten="bindings[].members" \
        --format="table(bindings.role)" \
        --filter="bindings.members:${var.kubernetes_service_account_email}"
    EOT
  }

  depends_on = [
    google_project_iam_member.superset_cloudsql_client,
    google_project_iam_member.superset_cloudsql_instanceUser,
    google_service_account_iam_binding.workload_identity_binding
  ]
}

# Bind the Superset service account to the Kubernetes service account
resource "google_service_account_iam_binding" "workload_identity_binding" {
  service_account_id = var.kubernetes_service_account_id
  role               = "roles/iam.workloadIdentityUser"
  members            = ["serviceAccount:${var.project_id}.svc.id.goog[${var.superset_namespace}/${kubernetes_service_account.superset_k8s_sa.metadata[0].name}]"]
}

# Kubernetes creaential for Superset database
resource "kubernetes_secret" "superset_db_credentials" {
  metadata {
    name      = "superset-db-credentials"
    namespace = kubernetes_namespace.superset_namespace.metadata[0].name
  }

  data = {
    username = var.superset_database_user_name
    password = var.superset_db_password
    database = var.superset_database_name
  }

  type = "Opaque"
}

# Generate Superset secret key 
resource "random_string" "superset_secret_key" {
  length           = 42
  special          = true
  override_special = "!#$%^&*()-_=+[]{}|:<>?/."
}

/*
# Build a custom Superset Dockeer image
resource "docker_image" "superset_custom_image" {
  name = "${var.region}-docker.pkg.dev/${var.project_id}/${var.repository_id}/superset-custom:latest"
  build {
    path = "${path.module}/../../superset"
  }
}

# Push image to Artifact Repository
resource "docker_registry_image" "superset_image" {
  name = docker_image.superset_custom_image.name
}

*/
# ConfigMap for Superset configuration
resource "kubernetes_config_map" "superset_config" {
  metadata {
    name      = "superset-config"
    namespace = kubernetes_namespace.superset_namespace.metadata[0].name
  }

  data = {
    "superset_config.py" = templatefile("${path.module}/../../superset/superset_config.py.tpl", {
      redis_host        = var.superset_redis_cache_host
      database_host     = "127.0.0.1"
      database_port     = "5432"
      database_user     = var.superset_database_user_name
      database_password = var.superset_db_password
      database_name     = var.superset_database_name
      secret_key        = random_string.superset_secret_key.result
    })
  }
}


resource "kubernetes_config_map" "superset_requirements" {
  metadata {
    name      = "superset-requirements"
    namespace = kubernetes_namespace.superset_namespace.metadata[0].name
  }


  data = {
    "requirements.txt" = file("${path.module}/../../superset/requirements.txt")
  }
}

locals {
  cloud_sql_instance_connection_name = "${var.project_id}:${var.region}:${var.cloud_sql_instance_name}"
}

resource "helm_release" "superset" {
  name       = "superset"
  repository = "https://apache.github.io/superset"
  chart      = "superset"
  namespace  = kubernetes_namespace.superset_namespace.metadata[0].name
  version    = var.superset_chart_version

  set = [
    # Custom Docker image
    /*{
      name  = "image.repository"
      value = "${var.region}-docker.pkg.dev/${var.project_id}/${var.repository_id}/superset-custom"
    },
    {
      name  = "image.tag"
      value = "latest"
    },*/
    # Superset Admin user
    {
      name  = "init.adminUser.username"
      value = var.superset_admin_username
    },
    {
      name  = "init.adminUser.password"
      value = var.superset_admin_password
    },
    {
      name  = "init.adminUser.firstname"
      value = var.superset_admin_firstname
    },
    {
      name  = "init.adminUser.lastname"
      value = var.superset_admin_lastname
    },
    {
      name  = "init.adminUser.email"
      value = var.superset_admin_email
    },
    # PostgreSQL Configuration
    {
      name  = "postgresql.enabled"
      value = "true"
    },
    {
      name  = "redis.enabled"
      value = "true"
    },
    {
      name  = "service.targetPort"
      value = 8088
    },
    # Load Balancer configuration
    {
      name  = "service.type"
      value = "LoadBalancer"
    },
    /*
    # Configuration Cloud SQL PostgreSQL externe
    # The host is now localhost because of the Cloud SQL Proxy sidecar
    {
      name  = "externalDatabase.host"
      value = "127.0.0.1"
    },
    {
      name  = "externalDatabase.port"
      value = "5432"
    },
    {
      name  = "externalDatabase.database"
      value = var.superset_database_name
    },
    {
      name  = "externalDatabase.user"
      value = var.superset_database_user_name
    },
    {
      name  = "externalDatabase.password"
      value = var.superset_db_password
    },
    {
      name  = "service.port"
      value = var.superset_service_port
    },

    # Disable NodePort
    {
      name  = "service.nodePort.http"
      value = "null"
    },
    {
      name  = "resources.requests.cpu"
      value = "1"
    },
    {
      name  = "resources.requests.memory"
      value = "2Gi"
    },
    {
      name  = "connectionName"
      value = local.cloud_sql_instance_connection_name
    },
    {
      name  = "runAsUser"
      value = "0"
    },
    # Superset's configuration
    {
      name  = "configOverrides.configs"
      value = "SECRET_KEY = '${random_string.superset_secret_key.result}'"
    }*/
  ]
  /*
  values = [
    file("${path.module}/../../superset/superset-values.yaml")
  ]*/

  wait    = true
  timeout = 600

  depends_on = [
    google_project_iam_member.superset_cloudsql_client,
    kubernetes_namespace.superset_namespace,
    kubernetes_secret.superset_db_credentials,
    kubernetes_config_map.superset_config,
    kubernetes_config_map.superset_requirements,
    kubernetes_service_account.superset_k8s_sa,
    google_service_account_iam_binding.workload_identity_binding]
}