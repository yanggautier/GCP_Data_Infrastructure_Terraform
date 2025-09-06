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

# Create an IAM user for Superset to connect to Cloud SQL
resource "google_sql_user" "superset_iam_user" {
  name     = var.kubernetes_service_account_email
  instance = var.cloud_sql_instance_name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
  
  depends_on = [var.cloud_sql_instance_name]
}

# Grant IAM user permissions to  Superset  db
resource "google_sql_user" "superset_iam_db_user" {
  name     = "superset-k8s-sa"
  instance = var.cloud_sql_instance_name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
  
  depends_on = [var.cloud_sql_instance_name]
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

/*
resource "kubernetes_config_map" "superset_requirements" {
  metadata {
    name      = "superset-requirements"
    namespace = var.superset_namespace
  }


  data = {
    "requirements.txt" = file("${path.module}/../../superset/requirements.txt")
  }
}*/

locals {
  cloud_sql_instance_connection_name = "${var.project_id}:${var.region}:${var.cloud_sql_instance_name}"
}
resource "helm_release" "superset" {
  name       = "superset"
  repository = "https://apache.github.io/superset"
  chart      = "superset"
  namespace  = var.superset_namespace
  version    = var.superset_chart_version

  values = [
    file("${path.module}/../../superset/superset-values.yaml"),
    yamlencode({
      # Service Account Configuration
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.superset_k8s_sa.metadata[0].name
      }

      # Admin User Configuration
      init = {
        adminUser = {
          username  = var.superset_admin_username
          password  = var.superset_admin_password
          firstname = var.superset_admin_firstname
          lastname  = var.superset_admin_lastname
          email     = var.superset_admin_email
        }
      }

      # External Database Configuration avec authentification IAM
      externalDatabase = {
        host     = "127.0.0.1"
        port     = "5432"
        database = var.superset_database_name
        # Utilisation de l'authentification IAM ou mot de passe traditionnel
        user     = var.use_iam_auth ? var.kubernetes_service_account_email : var.superset_database_user_name
        password = var.use_iam_auth ? "" : var.superset_db_password
      }

      # Service Configuration
      service = {
        type       = "LoadBalancer"
        port       = var.superset_service_port
        targetPort = 8088
      }

      # Cloud SQL Proxy Sidecar avec configuration IAM
      extraContainers = [
        {
          name  = "cloudsql-proxy"
          image = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.8.0"
          args = [
            "--port=5432",
            "--address=127.0.0.1",
            # Utiliser l'authentification IAM si configurée
            var.use_iam_auth ? "--auto-iam-authn" : "",
            # Activer le logging pour debug
            "--structured-logs",
            "--verbose",
            local.cloud_sql_instance_connection_name
          ]
          securityContext = {
            runAsNonRoot = true
            runAsUser    = 65532
            allowPrivilegeEscalation = false
            capabilities = {
              drop = ["ALL"]
            }
          }
          resources = {
            requests = {
              memory = "256Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "512Mi"
              cpu    = "200m"
            }
          }
          # Variables d'environnement pour le proxy
          env = [
            {
              name  = "GOOGLE_APPLICATION_CREDENTIALS"
              value = "/var/secrets/google/key.json"
            },
            {
              name  = "CLOUDSQL_INSTANCE_CONNECTION_NAME"
              value = local.cloud_sql_instance_connection_name
            }
          ]
          # Health checks pour le proxy
          readinessProbe = {
            tcpSocket = {
              port = 5432
            }
            initialDelaySeconds = 10
            periodSeconds       = 5
            timeoutSeconds      = 3
            failureThreshold    = 3
          }
          livenessProbe = {
            tcpSocket = {
              port = 5432
            }
            initialDelaySeconds = 30
            periodSeconds       = 10
            timeoutSeconds      = 5
            failureThreshold    = 3
          }
        }
      ]

      # Init container pour attendre que le proxy soit prêt
      initContainers = [
        {
          name  = "wait-for-cloudsql-proxy"
          image = "busybox:1.35"
          command = [
            "sh",
            "-c",
            <<-EOT
              echo "Waiting for Cloud SQL Proxy to be ready..."
              until nc -z 127.0.0.1 5432; do
                echo "Cloud SQL Proxy is not ready yet..."
                sleep 2
              done
              echo "Cloud SQL Proxy is ready!"
            EOT
          ]
        }
      ]

      # Configuration Superset avec structure correcte
      configOverrides = {
        # Secret key
        secret = random_string.superset_secret_key.result
        
        # Configuration sous forme de texte Python (pas de map)
        configs = <<-EOF
          # Configuration Redis Cache
          CACHE_CONFIG = {
              'CACHE_TYPE': 'RedisCache',
              'CACHE_DEFAULT_TIMEOUT': 300,
              'CACHE_KEY_PREFIX': 'superset_',
              'CACHE_REDIS_HOST': '${var.superset_redis_cache_host}',
              'CACHE_REDIS_PORT': 6379,
              'CACHE_REDIS_DB': 1,
          }
          
          # Database URI
          SQLALCHEMY_DATABASE_URI = '${var.use_iam_auth ? 
            "postgresql://superset-k8s-sa@127.0.0.1:5432/${var.superset_database_name}" :
            "postgresql://${var.superset_database_user_name}:${var.superset_db_password}@127.0.0.1:5432/${var.superset_database_name}"}'
          
          # Autres configurations
          SUPERSET_LOAD_EXAMPLES = False
          WTF_CSRF_ENABLED = True
          SECRET_KEY = '${random_string.superset_secret_key.result}'
        EOF
      }

      # Variables d'environnement pour Superset
      extraEnv = {
        SUPERSET_LOAD_EXAMPLES = "no"
        CACHE_REDIS_HOST      = var.superset_redis_cache_host
        CACHE_REDIS_PORT      = "6379"
        CACHE_REDIS_DB        = "1"
        # Variable pour indiquer l'utilisation de l'auth IAM
        USE_IAM_AUTH          = var.use_iam_auth ? "true" : "false"
      }

      # Annotations pour la Workload Identity
      podAnnotations = {
        "iam.gke.io/gcp-service-account" = var.kubernetes_service_account_email
      }
    })
  ]

  wait          = true
  wait_for_jobs = true  
  timeout       = 1800

  depends_on = [
    google_project_iam_member.superset_cloudsql_client,
    google_project_iam_member.superset_cloudsql_instanceUser,
    google_service_account_iam_binding.workload_identity_binding,
    kubernetes_service_account.superset_k8s_sa,
    kubernetes_secret.superset_db_credentials
  ]
}

# Variable pour contrôler le type d'authentification
variable "use_iam_auth" {
  description = "Use IAM authentication for Cloud SQL instead of password"
  type        = bool
  default     = true
}