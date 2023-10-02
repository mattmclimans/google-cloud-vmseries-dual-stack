# -----------------------------------------------------------------------------
# Provider configuration
# -----------------------------------------------------------------------------

provider "google" {
  project = local.project_id
  region  = local.region
}

terraform {}

# -----------------------------------------------------------------------------
# Local variables
# -----------------------------------------------------------------------------

locals {
  project_id      = var.project_id
  region          = var.region
  zone            = var.zone
  vmseries_image  = var.vmseries_image // View public images: `gcloud compute images list --project paloaltonetworksgcp-public --no-standard-images --uri`
  public_key_path = var.public_key_path
  mgmt_allow_ips  = var.mgmt_allow_ips
  prefix          = var.prefix
}

# -----------------------------------------------------------------------------
# Create VPC networks
# -----------------------------------------------------------------------------

resource "google_compute_network" "mgmt" {
  name                     = "${local.prefix}mgmt-vpc"
  routing_mode             = "GLOBAL"
  auto_create_subnetworks  = false
  enable_ula_internal_ipv6 = true

}

resource "google_compute_network" "untrust" {
  name                     = "${local.prefix}untrust-vpc"
  routing_mode             = "GLOBAL"
  auto_create_subnetworks  = false
  enable_ula_internal_ipv6 = true
}

resource "google_compute_network" "trust" {
  name                            = "${local.prefix}trust-vpc"
  routing_mode                    = "GLOBAL"
  auto_create_subnetworks         = false
  enable_ula_internal_ipv6        = true
  delete_default_routes_on_create = true
}

resource "google_compute_network" "external" {
  name                     = "${local.prefix}external-vpc"
  routing_mode             = "GLOBAL"
  auto_create_subnetworks  = false
  enable_ula_internal_ipv6 = true
}

# -----------------------------------------------------------------------------
# Create subnets
# -----------------------------------------------------------------------------

resource "google_compute_subnetwork" "mgmt" {
  name             = "${local.prefix}mgmt-subnet"
  ip_cidr_range    = "10.0.0.0/24"
  region           = local.region
  stack_type       = "IPV4_IPV6"
  ipv6_access_type = "INTERNAL"
  network          = google_compute_network.mgmt.id
}

resource "google_compute_subnetwork" "untrust" {
  name             = "${local.prefix}untrust-subnet"
  ip_cidr_range    = "10.0.1.0/24"
  region           = local.region
  stack_type       = "IPV4_IPV6"
  ipv6_access_type = "EXTERNAL"
  network          = google_compute_network.untrust.id
}

resource "google_compute_subnetwork" "trust" {
  name             = "${local.prefix}trust-subnet"
  ip_cidr_range    = "10.0.2.0/24"
  region           = local.region
  stack_type       = "IPV4_IPV6"
  ipv6_access_type = "INTERNAL"
  network          = google_compute_network.trust.id
}

resource "google_compute_subnetwork" "external" {
  name             = "${local.prefix}external-subnet"
  ip_cidr_range    = "10.0.3.0/24"
  region           = local.region
  stack_type       = "IPV4_IPV6"
  ipv6_access_type = "EXTERNAL"
  network          = google_compute_network.external.id
}

# -----------------------------------------------------------------------------
# Create ingress firewall rules
# -----------------------------------------------------------------------------

resource "google_compute_firewall" "mgmt_ipv4" {
  name          = "${local.prefix}all-ingress-mgmt"
  network       = google_compute_network.mgmt.id
  source_ranges = var.mgmt_allow_ips

  allow {
    protocol = "tcp"
    ports    = ["443", "22"]
  }
}

resource "google_compute_firewall" "untrust_ipv4" {
  name          = "${local.prefix}all-ingress-untrust"
  network       = google_compute_network.untrust.id
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "all"
  }
}

resource "google_compute_firewall" "trust_ipv4" {
  name          = "${local.prefix}all-ingress-trust"
  network       = google_compute_network.trust.id
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "all"
  }
}


resource "google_compute_firewall" "external_ipv6" {
  name          = "${local.prefix}all-ingress-external-ipv6"
  network       = google_compute_network.external.id
  source_ranges = ["::/0"]
  direction     = "INGRESS"

  allow {
    protocol = "all"
  }
}

resource "google_compute_firewall" "untrust_ipv6" {
  name          = "${local.prefix}all-ingress-untrust-ipv6"
  network       = google_compute_network.untrust.id
  source_ranges = ["::/0"]
  direction     = "INGRESS"

  allow {
    protocol = "all"
  }
}

resource "google_compute_firewall" "trust_ipv6" {
  name          = "${local.prefix}all-ingress-trust-ipv6"
  network       = google_compute_network.trust.id
  source_ranges = ["::/0"]
  direction     = "INGRESS"

  allow {
    protocol = "all"
  }
}

# -----------------------------------------------------------------------------
# Create VM-Series
# -----------------------------------------------------------------------------

# Deploy VM-Series
resource "google_compute_instance" "vmseries" {
  name                      = "${local.prefix}vmseries"
  machine_type              = "n2-standard-4"
  zone                      = local.zone
  can_ip_forward            = true
  allow_stopping_for_update = true

  metadata = {
    serial-port-enable = true
    ssh-keys           = "admin:${file(local.public_key_path)}"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.mgmt.id
    stack_type = "IPV4_IPV6"
    access_config {
      network_tier = "PREMIUM"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.untrust.id
    stack_type = "IPV4_IPV6"
    access_config {
      network_tier = "PREMIUM"
    }
    ipv6_access_config {
      network_tier = "PREMIUM"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.trust.id
    stack_type = "IPV4_IPV6"
  }

  boot_disk {
    initialize_params {
      image = local.vmseries_image
      type  = "pd-standard"
    }
  }

  service_account {
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly",
      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write"
    ]
  }

  depends_on = [
  ]
}

# -----------------------------------------------------------------------------
# Internal VM
# -----------------------------------------------------------------------------

resource "google_compute_instance" "internal_vm" {
  name                      = "${local.prefix}internal-vm"
  project                   = local.project_id
  zone                      = local.zone
  machine_type              = "f1-micro"
  allow_stopping_for_update = true

  metadata = {
    serial-port-enable = true
  }

  boot_disk {
    initialize_params {
      image = "https://www.googleapis.com/compute/v1/projects/panw-gcp-team-testing/global/images/ubuntu-2004-lts-apache"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.trust.id
    stack_type = "IPV4_IPV6"
  }
}
