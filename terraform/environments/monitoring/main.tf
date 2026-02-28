data "terraform_remote_state" "cluster" {
  count   = var.use_remote_state ? 1 : 0
  backend = "gcs"

  config = {
    bucket = var.tfstate_bucket
    prefix = "state/cluster"
  }
}

locals {
  cluster_name = var.use_remote_state ? data.terraform_remote_state.cluster[0].outputs.cluster_name : var.cluster_name
  region       = var.use_remote_state ? data.terraform_remote_state.cluster[0].outputs.cluster_location : var.region
}

module "monitoring" {
  source = "../../modules/monitoring"

  project_id             = var.project_id
  cluster_name           = local.cluster_name
  region                 = local.region
  chart_path             = "${path.module}/../../.."
  grafana_admin_password = var.grafana_admin_password
  grafana_expose         = var.grafana_expose
}
