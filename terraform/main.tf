# Enable required APIs
resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "container" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "gkehub" {
  service            = "gkehub.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "vpc_network" {
  name                    = "gke-network"
  auto_create_subnetworks = true
  depends_on              = [google_project_service.compute]
}

resource "google_container_cluster" "manager" {
  name     = "manager-cluster"
  location = var.manager_region
  network  = google_compute_network.vpc_network.name

  enable_autopilot = true

  depends_on = [google_project_service.container]
}

resource "google_container_cluster" "workers" {
  for_each = toset(var.worker_regions)
  name     = "worker-cluster-${each.key}"
  location = each.key
  network  = google_compute_network.vpc_network.name

  enable_autopilot = true

  depends_on = [google_project_service.container]
}

# Register clusters to Fleet (Hub)
resource "google_gke_hub_membership" "manager" {
  membership_id = "manager-cluster"
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.manager.id}"
    }
  }
  depends_on = [google_project_service.gkehub]
}

resource "google_gke_hub_membership" "workers" {
  for_each      = google_container_cluster.workers
  membership_id = each.value.name
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${each.value.id}"
    }
  }
  depends_on = [google_project_service.gkehub]
}
