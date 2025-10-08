terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

module "namespaces" {
  source = "./modules/namespaces"
}

module "apps" {
  source = "./modules/apps"
  google_api_key  = var.google_api_key
}


module "helm" {
  source = "./modules/helm"
}
