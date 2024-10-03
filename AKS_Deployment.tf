provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = "Ewis"
  location = "East US"
}

resource "azurerm_kubernetes_cluster" "example" {
  name                = "example-k8s-cluster"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  dns_prefix          = "examplek8s"  # Add a DNS prefix here

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }
}

data "azurerm_client_config" "example" {}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.example.kube_admin_config[0].host
  token                  = data.azurerm_client_config.example.service_principal_password
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.example.kube_admin_config[0].cluster_ca_certificate)
}

resource "kubernetes_namespace" "prod" {
  metadata {
    name = "prod"
  }
}

resource "kubernetes_namespace" "dev" {
  metadata {
    name = "dev"
  }
}

resource "kubernetes_namespace" "test" {
  metadata {
    name = "test"
  }
}

resource "kubernetes_persistent_volume" "postgres_pv" {
  metadata {
    name = "postgres-pv"
  }
  spec {
    capacity = {
      "storage" = "5Gi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_source {
      host_path {
        path = "/mnt/data"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "postgres_pvc_prod" {
  metadata {
    name      = "postgres-pvc-prod"
    namespace = kubernetes_namespace.prod.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests {
        storage = "5Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "postgres_pvc_dev" {
  metadata {
    name      = "postgres-pvc-dev"
    namespace = kubernetes_namespace.dev.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests {
        storage = "5Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "postgres_pvc_test" {
  metadata {
    name      = "postgres-pvc-test"
    namespace = kubernetes_namespace.test.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests {
        storage = "5Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "postgres_prod" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.prod.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "postgres"
      }
    }
    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }
      spec {
        container {
          name  = "postgres"
          image = "postgres:latest"
          port {
            container_port = 5432
          }
          env {
            name  = "POSTGRES_DB"
            value = "mydb"
          }
          env {
            name  = "POSTGRES_USER"
            value = "user"
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = "password"
          }
          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
          }
        }
        volume {
          name = "postgres-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres_pvc_prod.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "postgres_dev" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.dev.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "postgres"
      }
    }
    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }
      spec {
        container {
          name  = "postgres"
          image = "postgres:latest"
          port {
            container_port = 5432
          }
          env {
            name  = "POSTGRES_DB"
            value = "mydb"
          }
          env {
            name  = "POSTGRES_USER"
            value = "user"
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = "password"
          }
          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
          }
        }
        volume {
          name = "postgres-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres_pvc_dev.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "postgres_test" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.test.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "postgres"
      }
    }
    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }
      spec {
        container {
          name  = "postgres"
          image = "postgres:latest"
          port {
            container_port = 5432
          }
          env {
            name  = "POSTGRES_DB"
            value = "mydb"
          }
          env {
            name  = "POSTGRES_USER"
            value = "user"
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = "password"
          }
          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
          }
        }
        volume {
          name = "postgres-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres_pvc_test.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "postgres_prod" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.prod.metadata[0].name
  }
  spec {
    selector = {
      app = "postgres"
    }
    port {
      port        = 5432
      target_port = 5432
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_service" "postgres_dev" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.dev.metadata[0].name
  }
  spec {
    selector = {
      app = "postgres"
    }
    port {
      port        = 5432
      target_port = 5432
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_service" "postgres_test" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.test.metadata[0].name
  }
  spec {
    selector = {
      app = "postgres"
    }
    port {
      port        = 5432
      target_port = 5432
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress" "app_prod" {
  metadata {
    name      = "app-prod-ingress"
    namespace = kubernetes_namespace.prod.metadata[0].name
  }
  spec {
    rule {
      host = "app.example.com"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.postgres_prod.metadata[0].name
              port {
                number = 5432
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress" "app_dev" {
  metadata {
    name      = "app-dev-ingress"
    namespace = kubernetes_namespace.dev.metadata[0].name
  }
  spec {
    rule {
      host = "app.example.com"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.postgres_dev.metadata[0].name
              port {
                number = 5432
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress" "app_test" {
  metadata {
    name      = "app-test-ingress"
    namespace = kubernetes_namespace.test.metadata[0].name
  }
  spec {
    rule {
      host = "app.example.com"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.postgres_test.metadata[0].name
              port {
                number = 5432
              }
            }
          }
        }
      }
    }
  }
}
