# Namespace
resource "kubernetes_namespace" "immich" {
  metadata {
    name = "immich"
  }
}

# dla zewnętrznej biblioteki zdjęć
resource "kubernetes_persistent_volume" "immich_library_ext_pv" {
  metadata {
    name = "immich-library-ext-pv"
  }

  spec {
    storage_class_name = "manual"
    capacity           = { storage = "500Gi" }
    access_modes       = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"

    persistent_volume_source {
      host_path {
        path = "/srv/samba/sambashare"  # Twój istniejący share Samba
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "immich_library_ext_pvc" {
  metadata {
    name      = "immich-library-ext-pvc"
    namespace = kubernetes_namespace.immich.metadata[0].name
  }

  spec {
    storage_class_name = "manual"
    access_modes       = ["ReadWriteMany"]
    resources {
      requests = { storage = "500Gi" }
    }
    volume_name = kubernetes_persistent_volume.immich_library_ext_pv.metadata[0].name
  }
}


# PersistentVolume dla bazy danych
resource "kubernetes_persistent_volume" "immich_db_pv" {
  metadata {
    name = "immich-db-pv"
  }

  spec {
    storage_class_name = "manual"
    capacity           = { storage = "10Gi" }
    access_modes       = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"

    persistent_volume_source {
      host_path {
        path = "/srv/immich/db"
        type = "DirectoryOrCreate"
      }
    }
  }
}

# PersistentVolumeClaim dla bazy danych
resource "kubernetes_persistent_volume_claim" "immich_db_pvc" {
  metadata {
    name      = "immich-db-pvc"
    namespace = kubernetes_namespace.immich.metadata[0].name
  }

  spec {
    storage_class_name = "manual"
    access_modes       = ["ReadWriteOnce"]
    resources {
      requests = { storage = "10Gi" }
    }
    volume_name = kubernetes_persistent_volume.immich_db_pv.metadata[0].name
  }
}

# PersistentVolume dla biblioteki zdjęć wewnętrznej
resource "kubernetes_persistent_volume" "immich_library_pv" {
  metadata {
    name = "immich-library-pv"
  }

  spec {
    storage_class_name = "manual"
    capacity           = { storage = "500Gi" }
    access_modes       = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"

    persistent_volume_source {
      host_path {
        path = "/srv/immich/internal"
        type = "DirectoryOrCreate"
      }
    }
  }
}

# PersistentVolumeClaim dla biblioteki zdjęć
resource "kubernetes_persistent_volume_claim" "immich_library_pvc" {
  metadata {
    name      = "immich-library-pvc"
    namespace = kubernetes_namespace.immich.metadata[0].name
  }

  spec {
    storage_class_name = "manual"
    access_modes       = ["ReadWriteMany"]
    resources {
      requests = { storage = "500Gi" }
    }
    volume_name = kubernetes_persistent_volume.immich_library_pv.metadata[0].name
  }
}

# Deployment PostgreSQL
resource "kubernetes_deployment" "database" {
  metadata {
    name      = "database"
    namespace = kubernetes_namespace.immich.metadata[0].name
    labels    = { app = "database" }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "database" }
    }

    template {
      metadata {
        labels = { app = "database" }
      }

      spec {
        container {
          name  = "postgres"
          image = "docker.io/tensorchord/pgvecto-rs:pg14-v0.2.0@sha256:90724186f0a3517cf6914295b5ab410db9ce23190a2d9d0b9dd6463e3fa298f0"

          env {
            name  = "POSTGRES_USER"
            value = "postgres"
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = "immichpass"
          }
          env {
            name  = "POSTGRES_DB"
            value = "immich"
          }

          volume_mount {
            name       = "pgdata"
            mount_path = "/var/lib/postgresql/data"
          }
        }

        volume {
          name = "pgdata"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.immich_db_pvc.metadata[0].name
          }
        }
      }
    }
  }
}

# Deployment Redis
resource "kubernetes_deployment" "redis" {
  metadata {
    name      = "redis"
    namespace = kubernetes_namespace.immich.metadata[0].name
    labels    = { app = "redis" }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "redis" }
    }

    template {
      metadata {
        labels = { app = "redis" }
      }

      spec {
        container {
          name  = "redis"
          image = "redis:latest"
        }
      }
    }
  }
}

# Deployment Immich server
resource "kubernetes_deployment" "immich_server" {
  metadata {
    name      = "immich-server"
    namespace = kubernetes_namespace.immich.metadata[0].name
    labels    = { app = "immich-server" }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "immich-server" }
    }

    template {
      metadata {
        labels = { app = "immich-server" }
      }

      spec {

        container {
          name  = "immich-server"
          image = "ghcr.io/immich-app/immich-server:release"

          port {
            container_port = 3001
          }

          # ENV variables
          env {
            name  = "DB_HOST"
            value = "immich-db"
          }
          env {
            name  = "DB_PORT"
            value = "5432"
          }
          env {
            name  = "DB_USERNAME"
            value = "postgres"
          }
          env {
            name  = "DB_PASSWORD"
            value = "immichpass"
          }
          env {
            name  = "DB_DATABASE_NAME"
            value = "immich"
          }
          env {
            name  = "REDIS_HOST"
            value = "immich-redis"
          }
          env {
            name  = "REDIS_PORT"
            value = "6379"
          }
          env {
            name  = "UPLOAD_LOCATION"
            value = "/usr/src/app/upload"
          }

          # VolumeMounts
          volume_mount {
            name       = "library-internal"
            mount_path = "/usr/src/app/upload"
          }

          volume_mount {
            name       = "library-external"
            mount_path = "/usr/src/app/library"
          }
        }

        # Volumes
        volume {
          name = "library-internal"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.immich_library_pvc.metadata[0].name
          }
        }

        volume {
          name = "library-external"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.immich_library_ext_pvc.metadata[0].name
          }
        }
      }
    }
  }
}

# Services
resource "kubernetes_service" "database" {
  metadata {
    name      = "database"
    namespace = kubernetes_namespace.immich.metadata[0].name
  }

  spec {
    selector = { app = "database" }
    port {
      port        = 5432
      target_port = 5432
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_service" "redis" {
  metadata {
    name      = "redis"
    namespace = kubernetes_namespace.immich.metadata[0].name
  }

  spec {
    selector = { app = "redis" }
    port {
      port        = 6379
      target_port = 6379
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_service" "immich_server" {
  metadata {
    name      = "immich-server"
    namespace = kubernetes_namespace.immich.metadata[0].name
  }

  spec {
    selector = { app = "immich-server" }
    port {
      name        = "http"
      port        = 3001
      target_port = 2283
      node_port   = 30082
      protocol    = "TCP"
    }
    type = "NodePort"
  }
}
