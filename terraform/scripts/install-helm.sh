#!/usr/bin/env bash
# Install Helm 3 (required for Terraform helm_release)
set -e

if command -v helm &>/dev/null; then
  echo "Helm already installed: $(helm version --short)"
  exit 0
fi

echo "Installing Helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "Helm installed: $(helm version --short)"
