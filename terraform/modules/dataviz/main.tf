# ----------------- Configuration for Superset Deployment ---------------------
# Add IAM permission to have access Cloud SQL
resource "google_project_iam_member" "superset_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${var.kubernetes_service_account_email}"
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
  length           = 16
  special          = true
  override_special = "!@#$%^&*"
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

resource "helm_release" "superset" {
  name       = "superset"
  repository = "https://apache.github.io/superset"
  chart      = "superset"
  namespace  = var.superset_namespace
  version    = "0.15.0" # Vérifie la dernière version sur ArtifactHub

  set = [
   {
      name  = "postgresql.enabled"
      value = "true"
    },
    {
      name  = "redis.enabled"
      value = "true"
    }
  ]

  /*
  set = [
    {
      name  = "autoscaling.enabled"
      value = "true"
    },
    {
      name  = "autoscaling.minReplicas"
      value = "1"
    },
    {
      name  = "autoscaling.maxReplicas"
      value = "3"
    },
    {
      name  = "postgresql.enabled"
      value = "false"
    },
    {
      name  = "redis.enabled"
      value = "false"
    },
    {
      name  = "externalDatabase.host"
      value = var.cloud_sql_instance_name
    },
    {
      name  = "externalDatabase.database"
      value = var.superset_database_name
    },
    {
      name  = "externalDatabase.port"
      value = "5432"
    },
    {
      name  = "externalDatabase.user"
      value = var.superset_database_user_name
    },
    {
      name  = "externalDatabase.passwordSecret"
      value = kubernetes_secret.superset_db_credentials.metadata[0].name
    },
    {
      name  = "cloudsql.enabled"
      value = "true"
    },
    {
      name  = "cloudsql.instances"
      value = var.cloud_sql_instance_name
    },
    {
      name  = "externalRedis.host"
      value = var.superset_redis_cache_host
    },
    {
      name  = "externalRedis.port"
      value = "6379"
    },
    {
      name  = "serviceAccount.name"
      value = kubernetes_service_account.superset_k8s_sa.metadata[0].name
    },
    {
      name  = "initContainer.env.DB_HOST"
      value = var.cloud_sql_instance_name
    },
    {
      name  = "initContainer.env.REDIS_HOST"
      value = var.superset_redis_cache_host
    }
  ]
  */
}

/*
# Create a Superset Kubernetes deployment with Cloud SQL proxy as sidecar
resource "kubernetes_deployment" "superset" {
  metadata {
    name      = "superset"
    namespace = kubernetes_namespace.superset_namespace.metadata[0].name
    labels = {
      app = "superset"
    }
  }

  spec {
    replicas = 1
    
    selector {
      match_labels = {
        app = "superset"
      }
    }

    template {
      metadata {
        labels = {
          app = "superset"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.superset_k8s_sa.metadata[0].name

        container {
          name  = "superset"
          image = "apache/superset:3.1.0"
          # Add the init logic to the command/args of the main container
          command = ["/bin/sh", "-c"]
          args = [
            <<-EOT
            echo "Starting Superset pre-launch tasks..."
            
            # Wait for Cloud SQL proxy using a Python script
            until python -c "import socket; s = socket.socket(socket.AF_INET, socket.SOCK_STREAM); s.settimeout(1); s.connect(('127.0.0.1', 5432)); s.close()" >/dev/null 2>&1; do
                echo "Waiting for Cloud SQL proxy to start..."
                sleep 2
            done
            echo "Cloud SQL proxy is ready! Starting database initialization..."

            # Initialize Superset database
            /usr/local/bin/superset db upgrade
            /usr/local/bin/superset init

            echo "Superset database initialization completed. Starting web server..."
            
            # Start the main Superset webserver process
            /usr/local/bin/superset run -p 8088 --with-threads --reload --workers 4
            EOT
          ]
          port {
            container_port = 8088
          }

          env {
            name  = "SUPERSET_CONFIG_PATH"
            value = "/app/superset_config.py"
          }
          
          env {
            name = "DATABASE_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.superset_db_credentials.metadata[0].name
                key  = "username"
              }
            }
          }
          
          env {
            name = "DATABASE_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.superset_db_credentials.metadata[0].name
                key  = "password"
              }
            }
          }
          
          env {
            name = "DATABASE_NAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.superset_db_credentials.metadata[0].name
                key  = "database"
              }
            }
          }

          env {
            name  = "DATABASE_HOST"
            value = "127.0.0.1"
          }

          env {
            name  = "DATABASE_PORT"
            value = "5432"
          }

          env {
            name  = "REDIS_HOST"
            value = var.superset_redis_cache_host
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8088
            }
            initial_delay_seconds = 180 
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 5
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8088
            }
            initial_delay_seconds = 120 
            period_seconds        = 15
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          volume_mount {
            name       = "superset-config"
            mount_path = "/app"
          }

          resources {
            requests = {
              cpu    = var.superset_request_cpu
              memory = var.superset_request_memory
            }
            limits = {
              cpu    = var.superset_limit_cpu
              memory = var.superset_limit_memory
            }
          }
        }

        container {
          name  = "cloudsql-proxy"
          image = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.8.0"
          
          args = [
            "--structured-logs",
            "--port=5432",
            "${var.project_id}:${var.region}:${var.cloud_sql_instance_name}"
          ]

          readiness_probe {
            tcp_socket {
              port = 5432
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            timeout_seconds       = 3
          }

          security_context {
            run_as_non_root = true
          }

          resources {
            requests = {
              cpu    = var.proxy_request_cpu
              memory = var.proxy_request_memory
            }
            limits = {
              cpu    = var.proxy_limit_cpu
              memory = var.proxy_limit_memory
            }
          }
        }

        volume {
          name = "superset-config"
          config_map {
            name = kubernetes_config_map.superset_config.metadata[0].name
          }
        }
      }
    }
  }

  timeouts {
    create = "5m"
    update = "5m"
    delete = "3m"
  }

  depends_on = [
    kubernetes_secret.superset_db_credentials,
    kubernetes_config_map.superset_config
  ]
}


# Kubernetes service to expose Superset
resource "kubernetes_service" "superset_service" {
  metadata {
    name      = "superset-service"
    namespace = kubernetes_namespace.superset_namespace.metadata[0].name
  }

  spec {
    selector = {
      app = "superset"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 8088
      protocol    = "TCP"
    }

    type = "LoadBalancer"  # Or "ClusterIP" if you use a ingress
  }
}
*/
/*
# Optionnel : if you want to expose Superset to a domain name with static IP 
resource "kubernetes_ingress_v1" "superset_ingress" {
  count = var.enable_ingress ? 1 : 0

  metadata {
    name      = "superset-ingress"
    namespace = kubernetes_namespace.superset_namespace.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                = "gce"
      "kubernetes.io/ingress.global-static-ip-name" = var.static_ip_name  # if you have a static ip
    }
  }

  spec {
    rule {
      host = var.superset_domain  # ex: superset.yourdomain.com
      http {
        path {
          path      = "/*"
          path_type = "ImplementationSpecific"
          backend {
            service {
              name = kubernetes_service.superset_service.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
*/