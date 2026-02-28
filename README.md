<p align="center">
  <img src="/src/frontend/static/icons/Hipster_HeroLogoMaroon.svg" width="260" alt="Online Boutique" />
</p>

<h1 align="center">Online Boutique — Cloud Infrastructure & DevOps</h1>

<p align="center">
  <strong>Production-grade microservices deployment on GCP with Terraform, GitHub Actions CI/CD, and a full observability stack.</strong>
</p>

<p align="center">
  <a href="#architecture"><img src="https://img.shields.io/badge/GCP-Google%20Cloud-4285F4?logo=googlecloud&logoColor=white" alt="GCP" /></a>
  <a href="#infrastructure-as-code"><img src="https://img.shields.io/badge/Terraform-IaC-7B42BC?logo=terraform&logoColor=white" alt="Terraform" /></a>
  <a href="#cicd-pipeline"><img src="https://img.shields.io/badge/GitHub%20Actions-CI%2FCD-2088FF?logo=githubactions&logoColor=white" alt="GitHub Actions" /></a>
  <a href="#monitoring--observability"><img src="https://img.shields.io/badge/Grafana-Dashboards-F46800?logo=grafana&logoColor=white" alt="Grafana" /></a>
  <a href="#monitoring--observability"><img src="https://img.shields.io/badge/VictoriaMetrics-Metrics-621773" alt="VictoriaMetrics" /></a>
  <a href="#kubernetes"><img src="https://img.shields.io/badge/Kubernetes-GKE-326CE5?logo=kubernetes&logoColor=white" alt="Kubernetes" /></a>
</p>

---

## Overview

**Online Boutique** is an 11-service e-commerce microservices application originally created by Google Cloud. This repository extends it with a complete DevOps infrastructure: **Infrastructure as Code**, **CI/CD pipelines**, **multi-environment deployments** (staging + production), and a **full monitoring stack** with custom Grafana dashboards.

| Home Page | Checkout Screen |
| --- | --- |
| [![Screenshot of store homepage](/docs/img/online-boutique-frontend-1.png)](/docs/img/online-boutique-frontend-1.png) | [![Screenshot of checkout screen](/docs/img/online-boutique-frontend-2.png)](/docs/img/online-boutique-frontend-2.png) |

---

## Architecture

The entire platform runs on **Google Cloud Platform** inside a single GKE cluster with namespace-level isolation for staging, production, and monitoring.

<p align="center">
  <img src="/docs/img/infrastructure-diagram.png" alt="Infrastructure Diagram" width="100%" />
</p>

### High-Level Components

```
Google Cloud Platform (forgeteam)
├── GCS Bucket (Terraform Remote State)
│   ├── state/cluster
│   ├── state/monitoring
│   ├── state/staging
│   └── state/production
│
├── Artifact Registry (Docker images)
│
└── GKE Cluster (forgeteam-online-boutique)
    ├── Namespace: staging          ← 11 microservices + LoadBalancer
    ├── Namespace: production       ← 11 microservices + LoadBalancer
    └── Namespace: monitoring       ← VictoriaMetrics + Grafana + Loki
```

### Microservices

The application is composed of 11 microservices written in different languages, communicating over gRPC:

| Service | Language | Description |
| --- | --- | --- |
| **frontend** | Go | HTTP server serving the web UI, generates session IDs automatically |
| **cartservice** | C# | Stores shopping cart items in Redis |
| **productcatalogservice** | Go | Product listing and search from a JSON catalog |
| **currencyservice** | Node.js | Currency conversion using ECB rates (highest QPS service) |
| **paymentservice** | Node.js | Mock credit card payment processing |
| **shippingservice** | Go | Shipping cost estimates and mock shipment |
| **emailservice** | Python | Mock order confirmation emails |
| **checkoutservice** | Go | Orchestrates payment, shipping, and email notification |
| **recommendationservice** | Python | Product recommendations based on cart contents |
| **adservice** | Java | Context-based text advertisements |
| **loadgenerator** | Python/Locust | Simulates realistic user shopping flows |

---

## Technology Choices & Why

### Why GKE (Google Kubernetes Engine)

- **Native GCP integration** — seamless IAM, logging, monitoring, and networking
- **Spot instances support** — up to 60-91% cost savings on compute
- **Autopilot/Standard flexibility** — we use Standard mode with spot node pools for cost control
- **Built-in load balancing** — native L4/L7 integration without extra setup

### Why Terraform

- **Declarative infrastructure** — the entire cluster, monitoring, and application deployment is codified
- **State isolation** — four separate state files (cluster, monitoring, staging, production) prevent blast radius issues
- **Reproducibility** — `terraform apply` provisions everything from zero, `terraform destroy` tears it all down cleanly
- **Module reuse** — custom modules for GKE, monitoring, and application deployment

### Why VictoriaMetrics over Prometheus

- **Lower resource usage** — single-binary `vmsingle` handles ingestion and querying with ~3x less memory than Prometheus
- **Full PromQL compatibility** — drop-in replacement, all existing dashboards and queries work
- **Built-in Kubernetes operator** — `VMAgent`, `VMSingle`, service discovery via CRDs
- **Long-term storage** — efficient compression, no need for Thanos/Cortex sidecar architecture

### Why Loki for Logs

- **Label-based indexing** — same label model as Prometheus/VictoriaMetrics, no full-text indexing overhead
- **Lightweight** — doesn't index log content, dramatically cheaper to run than Elasticsearch
- **Native Grafana integration** — first-class datasource, LogQL queries right in the same dashboards
- **Promtail DaemonSet** — automatically collects logs from every node and pod

### Why Kustomize for App Deployment

- **No templating complexity** — patches over plain YAML, easy to understand
- **Built-in overlay model** — `base` + `overlays/staging` + `overlays/production` pattern
- **Kubectl native** — `kubectl apply -k` works out of the box, no extra tooling
- **Component system** — shared components like `without-loadgenerator` for environment-specific config

---

## Infrastructure as Code

The Terraform configuration is split into **four isolated environments**, each with its own state:

```
terraform/
├── deploy.sh                    # One-command orchestrator
├── environments/
│   ├── cluster/                 # GKE cluster + node pools
│   ├── monitoring/              # Observability stack (Helm)
│   ├── staging/                 # App deployment to staging namespace
│   └── production/              # App deployment to production namespace
├── modules/
│   ├── gke/                     # GKE cluster module
│   ├── monitoring/              # Monitoring Helm release module
│   └── onlineboutique/          # Kustomize-based app deployment module
└── scripts/
    └── install-helm.sh
```

### One-Command Deploy & Destroy

```bash
# Deploy everything (cluster → monitoring → staging → production)
./terraform/deploy.sh apply

# Deploy specific environment only
./terraform/deploy.sh apply monitoring

# Tear down everything (reverse order, with CRD cleanup)
./terraform/deploy.sh destroy

# Destroy specific environment
./terraform/deploy.sh destroy monitoring
```

The deploy script handles:
- Automatic Helm dependency building for charts
- Correct apply/destroy ordering
- Terraform init + auto-approve for each environment

### Clean Destroy

The monitoring module includes a custom cleanup provisioner that handles CRD finalizer removal and namespace force-deletion — solving the common Kubernetes problem where `terraform destroy` hangs on VictoriaMetrics CRDs.

---

## CI/CD Pipeline

GitHub Actions automates the build-push-deploy cycle with a multi-stage pipeline:

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐     ┌────────────────────┐
│  Push to     │────▶│  Detect      │────▶│  Build & Push   │────▶│  Deploy to         │
│  main branch │     │  Changes     │     │  to Artifact    │     │  Staging           │
│              │     │  (frontend/  │     │  Registry       │     │  (kubectl apply -k)│
│              │     │   cartservice│     │                 │     │                    │
└─────────────┘     └──────────────┘     └─────────────────┘     └────────┬───────────┘
                                                                          │
                                                                          ▼
                                                                ┌────────────────────┐
                                                                │  Deploy to         │
                                                                │  Production        │
                                                                │  (manual approval) │
                                                                └────────────────────┘
```

### Pipeline Features

| Feature | Details |
| --- | --- |
| **Change detection** | Only builds services that changed (`dorny/paths-filter`) |
| **Matrix builds** | Parallel builds for `frontend` and `cartservice` |
| **Image tagging** | Tags with commit SHA (`${GITHUB_SHA::8}`) + `latest` |
| **Registry** | Google Artifact Registry (`us-central1-docker.pkg.dev`) |
| **Staging deploy** | Automatic on push to `main` |
| **Production deploy** | Sequential after staging, requires environment approval |
| **Auth** | GCP Service Account key via GitHub Secrets (`GCP_SA_KEY`) |

### Trigger Paths

The pipeline triggers only when relevant code changes:

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'src/frontend/**'
      - 'src/cartservice/**'
      - '.github/workflows/ci-cd-deploy.yaml'
  workflow_dispatch:  # Manual trigger
```

---

## Monitoring & Observability

The monitoring stack deploys into the `monitoring` namespace via a custom Helm chart that bundles:

| Component | Role |
| --- | --- |
| **VictoriaMetrics Operator** | Manages VMAgent, VMSingle via CRDs |
| **VMSingle** | Time-series database (metrics storage) |
| **VMAgent** | Scrapes metrics from all pods and nodes |
| **Grafana** | Dashboard UI, exposed via LoadBalancer |
| **Loki** | Log aggregation (label-indexed) |
| **Promtail** | DaemonSet log collector on every node |
| **kube-state-metrics** | Kubernetes object state metrics |
| **Prometheus Node Exporter** | Node hardware/OS metrics |

<p align="center">
  <img src="/docs/img/gke-monitoring-stack.png" alt="GKE Monitoring Stack" width="100%" />
</p>

### Grafana Dashboards

Three custom dashboards are provisioned automatically as Kubernetes ConfigMaps:

#### 1. Reliability Dashboard

Tracks deployment availability (available/desired replicas) per namespace, pod restart counts, and OOM-killed containers. Namespace selector allows switching between staging and production.

<p align="center">
  <img src="/docs/img/dashboard-reliability.png" alt="Reliability Dashboard — 100% Availability" width="100%" />
</p>

#### 2. Logs Explorer

Aggregates container logs from Loki with namespace and pod selectors. Supports filtering by specific pod or viewing all pods across a namespace.

#### 3. HPA (Horizontal Pod Autoscaler) Dashboard

Visualizes autoscaler status: desired vs current replicas, min/max bounds, metric targets, and utilization thresholds.

### Built-in Kubernetes Dashboards

Additionally, the following dashboards from the VictoriaMetrics stack are enabled:

- **Kubernetes / Views / Global** — cluster-wide overview
- **Kubernetes / Views / Namespaces** — per-namespace resource usage
- **Kubernetes / Views / Nodes** — node CPU, memory, disk
- **Kubernetes / Views / Pods** — pod-level resource consumption
- **Kubernetes / Kubelet** — kubelet performance
- **Kubernetes / API Server** — API server latency and error rates
- **Node Exporter Full** — detailed node hardware metrics

---

## Deployed System

The GKE cluster runs all workloads across three namespaces:

<p align="center">
  <img src="/docs/img/gke-workloads.png" alt="GKE Workloads" width="100%" />
</p>

### Access Points

| Endpoint | How to Get IP |
| --- | --- |
| **Staging Frontend** | `kubectl get svc frontend-external -n staging -o jsonpath='{.status.loadBalancer.ingress[0].ip}'` |
| **Production Frontend** | `kubectl get svc frontend-external -n production -o jsonpath='{.status.loadBalancer.ingress[0].ip}'` |
| **Grafana** | `kubectl get svc monitoring-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}'` |

---

## Quick Start

### Prerequisites

- GCP project with billing enabled
- `gcloud`, `terraform`, `kubectl`, `helm` installed
- GCP Service Account with permissions for GKE, GCS, Artifact Registry

### Deploy Everything

```bash
# 1. Clone the repo
git clone https://github.com/<your-org>/microservices-demo.git
cd microservices-demo

# 2. Authenticate with GCP
gcloud auth login
gcloud config set project <PROJECT_ID>

# 3. Deploy all infrastructure
./terraform/deploy.sh apply

# 4. Get frontend IPs
kubectl get svc frontend-external -n staging -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
kubectl get svc frontend-external -n production -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# 5. Access Grafana
kubectl get svc monitoring-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
# Default credentials: admin / forgeteam
```

### Tear Down

```bash
./terraform/deploy.sh destroy
```

---

## Repository Structure

```
.
├── .github/workflows/
│   └── ci-cd-deploy.yaml          # GitHub Actions CI/CD pipeline
├── charts/
│   └── monitoring/                 # Custom Helm chart for observability stack
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           └── grafana/dashboards/ # Custom Grafana dashboards (ConfigMaps)
├── kustomize/
│   ├── base/                       # Base Kubernetes manifests (11 services)
│   ├── components/                 # Shared Kustomize components
│   └── overlays/
│       ├── staging/                # Staging overlay (namespace: staging)
│       └── production/             # Production overlay (namespace: production)
├── src/                            # Microservice source code (11 services)
├── terraform/
│   ├── deploy.sh                   # One-command deploy/destroy orchestrator
│   ├── environments/               # Per-environment Terraform configs
│   └── modules/                    # Reusable Terraform modules
└── README.md
```

---

## Architecture Decisions Record

| Decision | Choice | Rationale |
| --- | --- | --- |
| Cloud Provider | GCP | Native GKE support, Artifact Registry, free tier credits |
| IaC Tool | Terraform | Multi-provider, state management, module system |
| Cluster Type | GKE Standard + Spot | Cost optimization with spot node pools (60-91% savings) |
| App Deployment | Kustomize | Native kubectl support, overlay model for multi-env |
| CI/CD | GitHub Actions | Integrated with repo, matrix builds, environment approvals |
| Metrics Backend | VictoriaMetrics | 3x less memory than Prometheus, full PromQL compatible |
| Log Backend | Loki + Promtail | Lightweight, label-based, native Grafana integration |
| Dashboards | Grafana | Industry standard, supports VM + Loki datasources |
| State Management | GCS (4 isolated states) | Prevents blast radius, per-environment lifecycle |
| Container Registry | Artifact Registry | Regional, GCP-native, IAM-integrated |

---

<p align="center">
  <sub>Based on <a href="https://github.com/GoogleCloudPlatform/microservices-demo">Google Cloud microservices-demo</a> — extended with production-grade DevOps infrastructure.</sub>
</p>
