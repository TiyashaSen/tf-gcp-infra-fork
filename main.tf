terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials)
  project     = var.project
  region      = var.region
  zone        = var.zone

}


resource "google_compute_network" "vpc_network" {
  for_each                        = { for idx, name in var.vpc_names : name => idx }
  name                            = each.key
  auto_create_subnetworks         = false
  routing_mode                    = var.routing_mode
  delete_default_routes_on_create = true
}


resource "google_compute_subnetwork" "subnet_webapp" {
  for_each      = google_compute_network.vpc_network
  name          = "${var.subnetwebapp-name}-${each.value.name}"
  network       = each.value.name
  ip_cidr_range = var.ip-cidr-range-subnetwebapp
  region        = var.region
}

resource "google_compute_subnetwork" "subnet_db" {
  for_each      = google_compute_network.vpc_network
  name          = "${var.subnetdb-name}-${each.value.name}"
  network       = each.value.name
  ip_cidr_range = var.ip-cidr-range-subnetdb
  region        = var.region
}

resource "google_compute_route" "webapp-route" {
  for_each         = google_compute_network.vpc_network
  name             = "${var.webapp-route-name}-${each.value.name}"
  dest_range       = var.dest-range
  network          = each.value.name
  next_hop_gateway = var.hop_gateway
  priority         = var.webapp-route-priority

}


resource "google_compute_firewall" "rules" {
  for_each      = google_compute_network.vpc_network
  name          = "${var.firewall-name}-${each.value.name}"
  network       = each.value.name
  source_ranges = ["0.0.0.0/0"]
  description   = "Creates firewall rule"

  allow {
    protocol = "tcp"
    ports    = [var.port-number]
  }

  target_tags = [var.target-tag]
}

resource "google_compute_instance" "devinstance" {
  for_each     = google_compute_subnetwork.subnet_webapp
  name         = var.instancename
  machine_type = var.machine_type
  zone         = var.zone
  tags         = [var.target-tag]

  boot_disk {
    auto_delete = true
    initialize_params {
      image = var.imagename
      size  = var.initialize_params_size
      type  = var.initialize_params_type
    }

    mode = var.mode
  }
  network_interface {
    access_config {
      network_tier = var.network_tier
    }

    queue_count = var.queuecount
    stack_type  = var.stack_type
    subnetwork  = each.value.name
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = var.on_host_maintenance
    preemptible         = false
    provisioning_model  = var.provisioning_model
  }

}
