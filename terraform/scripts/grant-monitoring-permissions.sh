#!/usr/bin/env bash
# Grant GCP Service Account permissions to install kube-prometheus-stack (ClusterRoles, etc.)
# Run as project owner or IAM admin. Required if terraform apply monitoring fails with:
#   "cannot delete resource clusterroles... requires container.clusterRoles.delete"
#
# Usage: ./grant-monitoring-permissions.sh [SERVICE_ACCOUNT_EMAIL]
# Example: ./grant-monitoring-permissions.sh terraform-sa@forgeteam.iam.gserviceaccount.com

set -e

SA="${1:-terraform-sa@forgeteam.iam.gserviceaccount.com}"
PROJECT="${2:-forgeteam}"

echo "Granting roles/container.admin to $SA on project $PROJECT..."
gcloud projects add-iam-policy-binding "$PROJECT" \
  --member="serviceAccount:${SA}" \
  --role="roles/container.admin" \
  --condition=None

echo "Done. Re-run: terraform apply (monitoring)"
