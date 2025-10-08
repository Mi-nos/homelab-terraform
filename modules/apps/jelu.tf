#ns
resource "kubernetes_namespace" "jelu" {
    metadata {
        name = "jelu"
    }
}

#pv_everything
resource "kubernetes_persistent_volume" "jelu_pv" {
    metadata {
        name = "jelu-pv"
    }
    spec {
        capacity = {
            storage = "10Gi"
        }
        access_modes = ["ReadWriteOnce"]
        persistent_volume_reclaim_policy = "Retain"
        storage_class_name = "manual"

        persistent_volume_source {
            host_path {
                path = "/srv/jelu-data"
                type = "DirectoryOrCreate"
            }
        }
    }
}

#pvc_everything
resource "kubernetes_persistent_volume_claim" "jelu_pvc" {
    metadata {
        name = "jelu-pvc"
        namespace = kubernetes_namespace.jelu.metadata[0].name
    }
    spec {
        access_modes = ["ReadWriteOnce"]
        storage_class_name = "manual"

        resources {
            requests = {
                storage = "10Gi"
            }
        }

        volume_name = kubernetes_persistent_volume.jelu_pv.metadata[0].name
    }
}


resource "kubernetes_config_map" "jelu_config" {
  metadata {
    name      = "jelu-config"
    namespace = kubernetes_namespace.jelu.metadata[0].name
  }

  data = {
    "application.yml" = <<-EOT
      jelu:
        metadataProviders:
          - name: "google"
            is-enabled: true
            apiKey: ${var.google_api_key}
            order: 200000
          - name: "inventaireio"
            is-enabled: true
            order: 200002
            config: "pl"
          - name: "databazeknih"
            is-enabled: true
            order: 200001
        metadata:
          calibre:
            path: /usr/bin/fetch-ebook-metadata
            order: 50000
    EOT
  }
}

#dp
resource "kubernetes_deployment" "jelu_server" {
    metadata {
        name = "jelu"
        namespace = kubernetes_namespace.jelu.metadata[0].name
        labels = { 
            app = "jelu-server"
        }
    }

    spec {
        replicas = 1

        selector {
            match_labels = { 
                app = "jelu-server"
            }
        }

        template {
            metadata {
                labels = { app = "jelu-server" }
            }

            spec {

                image_pull_secrets {
                    name = "dockerhub-secret"
                }
                
                container {
                    name = "jelu-server"
                    image = "docker.io/wabayang/jelu:0.72.8"
                
                    port {
                        container_port = 11111
                    }

                    env {
                        name = "JELU_DATABASE_PATH"
                        value = "/srv/jelu-data/database"
                    }

                    env {
                        name = "JELU_FILES_IMAGES"
                        value = "/srv/jelu-data/files/images"
                    }

                    env {
                        name = "JELU_FILES_IMPORTS"
                        value = "/srv/jelu-data/files/imports"
                    }

                    volume_mount {
                        name = "jelu-data"
                        mount_path = "/srv/jelu-data/database"
                        sub_path = "database"
                    }

                    volume_mount {
                        name = "jelu-data"
                        mount_path = "/srv/jelu-data/files/images"
                        sub_path = "files/images"
                    }
                    
                    volume_mount {
                        name = "jelu-data"
                        mount_path = "/srv/jelu-data/files/imports"
                        sub_path = "files/imports"
                    }

                    volume_mount {
                        name       = "jelu-config"
                        mount_path = "/config/application.yml"
                        sub_path   = "application.yml"
                    }
                }

                volume {
                    name = "jelu-config"
                    config_map {
                    name = kubernetes_config_map.jelu_config.metadata[0].name
                    }
                }
                volume { 
                    name = "jelu-data"
                    persistent_volume_claim {
                        claim_name = kubernetes_persistent_volume_claim.jelu_pvc.metadata[0].name
                    }
                }
            }
        }
    }
}

resource "kubernetes_service" "jelu_server" {
  metadata {
    name      = "jelu-server"
    namespace = kubernetes_namespace.jelu.metadata[0].name
  }

  spec {
    selector = { app = "jelu-server" }
    port {
      name        = "http"
      port        = 11111
      target_port = 11111
      node_port   = 30083
      protocol    = "TCP"
    }
    type = "NodePort"
  }
}
