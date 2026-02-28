variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "name" {
  type        = string
  description = "Name of the GKE cluster"
  default     = "online-boutique"
}

variable "region" {
  type        = string
  description = "Region for the GKE cluster"
  default     = "us-central1"
}

variable "enable_apis" {
  type        = bool
  description = "Enable required Google APIs via Terraform (may be blocked by org policy)"
  default     = false
}

variable "memorystore" {
  type        = bool
  description = "Enable Redis API for optional Memorystore"
  default     = false
}

variable "machine_type" {
  type        = string
  description = "Machine type for spot node pool"
  default     = "e2-standard-2"
}

variable "node_min" {
  type        = number
  description = "Min nodes in spot pool"
  default     = 1
}

variable "node_max" {
  type        = number
  description = "Max nodes in spot pool"
  default     = 3
}
