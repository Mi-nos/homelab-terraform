resource "kubernetes_namespace" "demo" {
  metadata {
    name = "demo"
  }
}
