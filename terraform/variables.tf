variable "project_id" {
  description = "The project ID to deploy to"
  type        = string
  default     = "YOUR_PROJECT_ID"
}

variable "manager_region" {
  description = "The region for the manager cluster"
  type        = string
  default     = "us-central1"
}

variable "worker_regions" {
  description = "A list of regions for the worker clusters"
  type        = list(string)
  default     = ["us-east1", "europe-west1", "us-central1", "us-west1"]
}
