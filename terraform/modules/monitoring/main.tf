resource "null_resource" "helm_deps" {
  triggers = {
    chart_yaml = filemd5("${var.chart_path}/charts/monitoring/Chart.yaml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      helm repo add victoriametrics https://victoriametrics.github.io/helm-charts 2>/dev/null || true
      helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
      helm repo update
      helm dependency build "${var.chart_path}/charts/monitoring"
    EOT
  }
}

resource "helm_release" "monitoring" {
  depends_on = [null_resource.helm_deps]

  name              = "monitoring"
  namespace         = "monitoring"
  create_namespace  = true
  chart             = "${var.chart_path}/charts/monitoring"
  timeout           = 900
  wait              = true
  wait_for_jobs     = false
  cleanup_on_fail   = true
  upgrade_install   = true
  dependency_update = true
  disable_crd_hooks = true

  values = [
    file(abspath("${var.chart_path}/charts/monitoring/values.yaml")),
    yamlencode({
      victoria-metrics-k8s-stack = {
        grafana = {
          adminPassword = var.grafana_admin_password
          service = {
            type = var.grafana_expose ? "LoadBalancer" : "ClusterIP"
          }
        }
        victoria-metrics-operator = {
          cleanupCRD = false
        }
      }
    })
  ]
}

resource "null_resource" "monitoring_cleanup" {
  depends_on = [helm_release.monitoring]

  triggers = {
    namespace = "monitoring"
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Cleaning up monitoring namespace..."

      for resource in vmsingles vmagents vmalertmanagers vmalerts vmrules vmservicescrapes vmpodscrapes vmnodescrapes vmprobes vmauths vmclusters vmscrapeconfigs vmstaticscrapes vmusers vlsingles vlogs vlagents vlclusters vtsingles vtclusters; do
        for item in $(kubectl get $resource -n ${self.triggers.namespace} -o name 2>/dev/null); do
          kubectl patch $item -n ${self.triggers.namespace} --type merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
        done
      done

      for crd in $(kubectl get crd -o name 2>/dev/null | grep victoriametrics); do
        kubectl patch $crd --type merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
        kubectl delete $crd --timeout=30s 2>/dev/null || true
      done

      kubectl delete ns ${self.triggers.namespace} --timeout=60s 2>/dev/null || true
      echo "Monitoring cleanup complete."
    EOT
  }
}
