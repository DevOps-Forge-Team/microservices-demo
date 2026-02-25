data "google_client_config" "default" {}

data "google_container_cluster" "my_cluster" {
  name     = "forgeteam-online-boutique"
  location = "us-central1"
  project  = "forgeteam"
}

provider "helm" {
  kubernetes = {
    host                   = "https://${data.google_container_cluster.my_cluster.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.my_cluster.master_auth[0].cluster_ca_certificate)
  }
}

resource "helm_release" "prometheus_grafana" {
  name             = "monitoring-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "56.6.2"
}
