provider "azurerm" {
  features {}
  subscription_id = "b1ec803b-00c3-42bb-83ca-d12723a0e6a3"
  resource_provider_registrations = "none"
}

resource "azurerm_resource_group" "aks_rg" {
  name     = "aksResourceGroup"
  location = "East US"
}

resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = "production-aks-cluster"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  dns_prefix          = "prodaks"

  default_node_pool {
    name       = "systempool"
    node_count = 3
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure"
    load_balancer_sku  = "standard"   # Must be lowercase
  }

  oidc_issuer_enabled = true
}

data "azurerm_client_config" "current" {}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks_cluster.kube_admin_config[0].host
  token                  = azurerm_kubernetes_cluster.aks_cluster.kube_admin_config[0].password
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_admin_config[0].cluster_ca_certificate)
}

resource "kubernetes_namespace" "production" {
  metadata {
    name = "production"
  }
}

resource "kubernetes_namespace" "development" {
  metadata {
    name = "development"
  }
}

resource "kubernetes_namespace" "testing" {
  metadata {
    name = "testing"
  }
}

resource "kubernetes_persistent_volume" "postgres_pv" {
  metadata {
    name = "postgres-pv"
  }
  spec {
    capacity = {
      storage = "5Gi"
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
    namespace = kubernetes_namespace.production.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "postgres_pvc_dev" {
  metadata {
    name      = "postgres-pvc-dev"
    namespace = kubernetes_namespace.development.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "postgres_pvc_test" {
  metadata {
    name      = "postgres-pvc-test"
    namespace = kubernetes_namespace.testing.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "postgres_prod" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.production.metadata[0].name
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
            value = "prod_db"
          }
          env {
            name  = "POSTGRES_USER"
            value = "prod_user"
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = "prod_password"
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
    namespace = kubernetes_namespace.development.metadata[0].name
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
            value = "dev_db"
          }
          env {
            name  = "POSTGRES_USER"
            value = "dev_user"
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = "dev_password"
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
    namespace = kubernetes_namespace.testing.metadata[0].name
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
            value = "test_db"
          }
          env {
            name  = "POSTGRES_USER"
            value = "test_user"
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = "test_password"
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
    namespace = kubernetes_namespace.production.metadata[0].name
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
    namespace = kubernetes_namespace.development.metadata[0].name
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
    namespace = kubernetes_namespace.testing.metadata[0].name
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

resource "kubernetes_ingress" "app_prod_ingress" {
  metadata {
    name      = "app-prod-ingress"
    namespace = kubernetes_namespace.production.metadata[0].name
  }
  spec {
    rule {
      host = "prod.example.com"
      http {
        path {
          path = "/"
          backend {
            service_name = kubernetes_service.postgres_prod.metadata[0].name
            service_port = 5432
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress" "app_dev_ingress" {
  metadata {
    name      = "app-dev-ingress"
    namespace = kubernetes_namespace.development.metadata[0].name
  }
  spec {
    rule {
      host = "dev.example.com"
      http {
        path {
          path = "/"
          backend {
            service_name = kubernetes_service.postgres_dev.metadata[0].name
            service_port = 5432
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress" "app_test_ingress" {
  metadata {
    name      = "app-test-ingress"
    namespace = kubernetes_namespace.testing.metadata[0].name
  }
  spec {
    rule {
      host = "test.example.com"
      http {
        path {
          path = "/"
          backend {
            service_name = kubernetes_service.postgres_test.metadata[0].name
            service_port = 5432
          }
        }
      }
    }
  }
}
