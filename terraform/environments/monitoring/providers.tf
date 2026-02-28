terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.16.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "default" {}

data "google_container_cluster" "main" {
  name     = local.cluster_name
  location = local.region
  project  = var.project_id
}

provider "helm" {
  kubernetes = {
    host                   = "https://${data.google_container_cluster.main.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.main.master_auth[0].cluster_ca_certificate)
  }
}
