# Namespace
resource "kubernetes_namespace" "pihole" {
  metadata {
    name = "pihole"
  }
}

# PersistentVolume
resource "kubernetes_persistent_volume" "pihole_pv" {
  metadata {
    name = "pihole-pv"
  }

  spec {
    capacity = {
      storage = "1Gi"   
    }

    access_modes = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name = "manual"  

    persistent_volume_source {
      host_path {
        path = "/srv/pihole-data"
        type = "DirectoryOrCreate"
      }
    }
  }
}

# PersistentVolumeClaim
resource "kubernetes_persistent_volume_claim" "pihole_pvc" {
  metadata {
    name      = "pihole-pvc"
    namespace = kubernetes_namespace.pihole.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = "manual"  

    resources {
      requests = {
        storage = "1Gi"
      }
    }

    volume_name = kubernetes_persistent_volume.pihole_pv.metadata[0].name
  }
}

# ConfigMap dla Pi-hole
resource "kubernetes_config_map" "pihole_config" {
  metadata {
    name      = "pihole-cm0"
    namespace = kubernetes_namespace.pihole.metadata[0].name
  }

  data = {
    "setupVars.conf" = "WEBPASSWORD=minos\nDNSMASQ_LISTENING=all"
  }
}

# Deployment Pi-hole
resource "kubernetes_deployment" "pihole" {
  metadata {
    name      = "pihole"
    namespace = kubernetes_namespace.pihole.metadata[0].name
    labels = {
      "io.kompose.service" = "pihole"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "io.kompose.service" = "pihole"
      }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          "io.kompose.service" = "pihole"
        }
      }

      spec {
        host_network = true
        dns_policy   = "ClusterFirstWithHostNet"

        container {
          name  = "pihole"
          image = "pihole/pihole:latest"

          # DNS porty
          port {
            container_port = 53
            protocol       = "TCP"
          }
          port {
            container_port = 53
            protocol       = "UDP"
          }

          env {
            name  = "FTLCONF_dns_listeningMode"
            value = "all"
          }
          env {
            name  = "FTLCONF_webserver_api_password"
            value = "minos"
          }
          env {
            name  = "TZ"
            value = "Europe/London"
          }

          security_context {
            capabilities {
              add = ["NET_ADMIN"]
            }
          }

          volume_mount {
            mount_path = "/etc/pihole"
            name       = "pihole-data"
          }
        }

        volume {
          name = "pihole-data"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.pihole_pvc.metadata[0].name
          }
        }

        restart_policy = "Always"
      }
    }
  }
}

resource "kubernetes_service" "pihole_web" {
  metadata {
    name      = "pihole-web"
    namespace = kubernetes_namespace.pihole.metadata[0].name
    labels = {
      "io.kompose.service" = "pihole"
    }
  }

  spec {
    selector = {
      "io.kompose.service" = "pihole"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
    }

    type = "NodePort"
  }
}
