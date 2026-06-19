locals {
  regions = {
    manager = "us-central1"
    worker1 = "us-east1"
    worker2 = "europe-west1"
  }
}

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
  location = local.regions.manager
  network  = google_compute_network.vpc_network.name

  enable_autopilot = true

  depends_on = [google_project_service.container]
}

resource "google_container_cluster" "worker1" {
  name     = "worker-cluster-us"
  location = local.regions.worker1
  network  = google_compute_network.vpc_network.name

  enable_autopilot = true

  depends_on = [google_project_service.container]
}

resource "google_container_cluster" "worker2" {
  name     = "worker-cluster-eu"
  location = local.regions.worker2
  network  = google_compute_network.vpc_network.name

  enable_autopilot = true

  depends_on = [google_project_service.container]
}

resource "google_container_cluster" "worker3" {
  name     = "worker-cluster-us-central"
  location = "us-central1"
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

resource "google_gke_hub_membership" "worker1" {
  membership_id = "worker-cluster-us"
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.worker1.id}"
    }
  }
  depends_on = [google_project_service.gkehub]
}

resource "google_gke_hub_membership" "worker2" {
  membership_id = "worker-cluster-eu"
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.worker2.id}"
    }
  }
  depends_on = [google_project_service.gkehub]
}

resource "google_gke_hub_membership" "worker3" {
  membership_id = "worker-cluster-us-central"
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.worker3.id}"
    }
  }
  depends_on = [google_project_service.gkehub]
}

resource "google_container_cluster" "worker4" {
  name     = "worker-cluster-us-west"
  location = "us-west1"
  network  = google_compute_network.vpc_network.name

  enable_autopilot = true

  depends_on = [google_project_service.container]
}

resource "google_gke_hub_membership" "worker4" {
  membership_id = "worker-cluster-us-west"
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.worker4.id}"
    }
  }
  depends_on = [google_project_service.gkehub]
}
