# ----------------- Configuration for Superset Deployment ---------------------
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

# Kubernetes creaential for Superset database
resource "kubernetes_secret" "superset_db_credentials" {
  metadata {
    name      = "superset-db-credentials"
    namespace = kubernetes_namespace.superset_namespace.metadata[0].name
  }

  data = {
    username = base64encode(var.superset_database_user_name)
    password = base64encode(var.superset_db_password)
    database = base64encode(var.superset_database_name)
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
      database_name     = var.superset_database_name
      secret_key        = random_string.superset_secret_key.result
    })
  }
}

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
        
        # Init container for database
        init_container {
          name  = "superset-init"
          image = "apache/superset:latest"
          command = ["superset"]
          args = ["db", "upgrade"]
          
          env {
            name = "SUPERSET_CONFIG_PATH"
            value = "/app/superset_config.py"
          }
          
          env_from {
            secret_ref {
              name = kubernetes_secret.superset_db_credentials.metadata[0].name
            }
          }

          volume_mount {
            name       = "superset-config"
            mount_path = "/app"
          }
        }

        container {
          name  = "superset"
          image = "apache/superset:latest"
          
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

          # Health checks
          liveness_probe {
            http_get {
              path = "/health"
              port = 8088
            }
            initial_delay_seconds = 60
            period_seconds        = 30
            timeout_seconds       = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8088
            }
            initial_delay_seconds = 30
            period_seconds        = 15
            timeout_seconds       = 5
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

        # Cloud SQL Auth Proxy Sidecar
        container {
          name  = "cloudsql-proxy"
          image = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.8.0"
          
          args = [
            "--structured-logs",
            "--port=5432",
            "${var.project_id}:${var.region}:${var.cloud_sql_instance_name}"
          ]

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