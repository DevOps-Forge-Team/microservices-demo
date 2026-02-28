output "grafana_access" {
  value       = module.monitoring.grafana_service
  description = "How to access Grafana"
}

output "namespace" {
  value       = module.monitoring.namespace
  description = "Monitoring namespace"
}
