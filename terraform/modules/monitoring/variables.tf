variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "cluster_name" {
  type        = string
  description = "GKE cluster name"
}

variable "region" {
  type        = string
  description = "GKE cluster region"
}

variable "chart_path" {
  type        = string
  description = "Path to the repository root (where charts/ directory lives)"
}

variable "grafana_admin_password" {
  type        = string
  description = "Grafana admin password"
  sensitive   = true
  default     = "forgeteam"
}

variable "grafana_expose" {
  type        = bool
  description = "Expose Grafana via LoadBalancer (true) or ClusterIP (false)"
  default     = true
}
