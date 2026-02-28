locals {
  base_apis = [
    "container.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
    "cloudprofiler.googleapis.com",
  ]
  memorystore_apis = ["redis.googleapis.com"]
}

module "enable_google_apis" {
  count   = var.enable_apis ? 1 : 0
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 18.0"

  project_id                  = var.project_id
  disable_services_on_destroy = false
  activate_apis               = concat(local.base_apis, var.memorystore ? local.memorystore_apis : [])
}

resource "google_container_cluster" "main" {
  name     = var.name
  location = var.region

  deletion_protection      = false
  remove_default_node_pool = true
  initial_node_count       = 1

  node_config {
    disk_size_gb = 20
    disk_type    = "pd-standard"
  }

  ip_allocation_policy {}

  addons_config {
    http_load_balancing {
      disabled = false
    }
  }

  depends_on = [module.enable_google_apis]
}

resource "google_container_node_pool" "spot" {
  name     = "spot-pool"
  cluster  = google_container_cluster.main.name
  location = var.region

  autoscaling {
    min_node_count = var.node_min
    max_node_count = var.node_max
  }

  node_config {
    machine_type = var.machine_type
    spot         = true
    disk_size_gb = 30
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}
