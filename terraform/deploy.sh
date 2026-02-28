#!/usr/bin/env bash
set -e

ACTION="${1:-apply}"
ENVS="${2:-all}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENVS_DIR="$SCRIPT_DIR/environments"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ensure_helm() {
  if ! command -v helm &>/dev/null; then
    echo "Helm not found. Installing..."
    "$SCRIPT_DIR/scripts/install-helm.sh"
  fi
}

build_chart_deps() {
  local chart_dir="$1"
  if [ -f "$chart_dir/Chart.yaml" ] && grep -q "dependencies:" "$chart_dir/Chart.yaml"; then
    echo "Building Helm chart dependencies: $chart_dir"
    helm dependency build "$chart_dir" --skip-refresh 2>/dev/null || helm dependency build "$chart_dir"
  fi
}

run_terraform() {
  local env="$1"
  local action="$2"
  echo ""
  echo "========== $env: terraform $action =========="
  cd "$ENVS_DIR/$env"
  terraform init -input=false
  terraform "$action" -auto-approve
}

if [ "$ACTION" = "apply" ]; then
  if [ "$ENVS" = "all" ] || [ "$ENVS" = "cluster" ]; then
    run_terraform cluster apply
  fi
  if [ "$ENVS" = "all" ] || [ "$ENVS" = "monitoring" ]; then
    ensure_helm
    build_chart_deps "$REPO_ROOT/charts/monitoring"
    run_terraform monitoring apply
  fi
  if [ "$ENVS" = "all" ] || [ "$ENVS" = "staging" ]; then
    run_terraform staging apply
  fi
  if [ "$ENVS" = "all" ] || [ "$ENVS" = "production" ]; then
    run_terraform production apply
  fi

  echo ""
  echo "========== Done =========="
  echo "Frontend URLs (may take 1-2 min for IP):"
  echo "  Staging:    kubectl get svc frontend-external -n staging -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
  echo "  Production: kubectl get svc frontend-external -n production -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
  echo "  Grafana:    kubectl port-forward svc/monitoring-vm-grafana -n monitoring 3000:80"

elif [ "$ACTION" = "destroy" ]; then
  if [ "$ENVS" = "all" ] || [ "$ENVS" = "staging" ]; then
    run_terraform staging destroy
  fi
  if [ "$ENVS" = "all" ] || [ "$ENVS" = "production" ]; then
    run_terraform production destroy
  fi
  if [ "$ENVS" = "all" ] || [ "$ENVS" = "monitoring" ]; then
    run_terraform monitoring destroy
  fi
  if [ "$ENVS" = "all" ] || [ "$ENVS" = "cluster" ]; then
    run_terraform cluster destroy
  fi

  echo ""
  echo "========== Destroy complete =========="

else
  echo "Usage: $0 [apply|destroy] [all|cluster|monitoring|staging|production]"
  echo ""
  echo "Examples:"
  echo "  $0 apply              # apply all (cluster -> monitoring -> staging -> production)"
  echo "  $0 apply monitoring   # apply only monitoring"
  echo "  $0 destroy            # destroy all (staging -> production -> monitoring -> cluster)"
  echo "  $0 destroy monitoring # destroy only monitoring"
  exit 1
fi
