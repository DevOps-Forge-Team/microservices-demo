output "grafana_service" {
  value       = var.grafana_expose ? "kubectl get svc monitoring-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}'" : "kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80"
  description = "Command to access Grafana"
}

output "namespace" {
  value       = "monitoring"
  description = "Namespace where monitoring is deployed"
}

output "grafana_credentials" {
  value       = "admin / ${var.grafana_admin_password}"
  description = "Grafana login credentials"
  sensitive   = true
}
