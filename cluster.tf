variable "email" {
  type = string
  description = "Email address of the administrator (also used for letsencrypt certs)"
}

variable "project" {
  type = string
  description = "The name of the GCP project to deploy to."
}

variable "region" {
  type = string
  default = "us-west1"
  description = "The GCP region to deploy the cluster to."
}

variable "zone" {
  type    = string
  default = "us-west1-a"
  description = "The GCP availability zone to deploy the cluster to."
}

variable "domain" {
  type    = string
  description = "The domain to of the mailhost."
}

output "inetaddress" {
  value = "${google_compute_address.mail.address}"
}

output "nameservers" {
  value = "${google_dns_managed_zone.mail.name_servers}"
}

output "certpem" {
  value = "${acme_certificate.certificate.certificate_pem}"
}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

data "google_project" "project" {}

# IP Address for inbound internet traffic to the cluster
resource "google_compute_address" "mail" {
  name = "mail"
  network_tier = "STANDARD"
}

# DNS Zone to hold required entries
resource "google_dns_managed_zone" "mail" {
  name = "zone-${replace(var.domain, ".", "-")}"
  dns_name = "${var.domain}."
  description = "DNS zone for ${var.domain}"
}

# A record for the domain pointing at the cluster inet ip
resource "google_dns_record_set" "maila" {
  name = "${google_dns_managed_zone.mail.dns_name}"
  managed_zone = "${google_dns_managed_zone.mail.name}"
  type = "A"
  ttl  = 300

  rrdatas = ["${google_compute_address.mail.address}"]
}

# CNAME for mail.`domain` to `domain`
resource "google_dns_record_set" "mailcname" {
  name = "mail.${google_dns_managed_zone.mail.dns_name}"
  managed_zone = "${google_dns_managed_zone.mail.name}"
  type = "CNAME"
  ttl  = 300
  rrdatas = ["${var.domain}."]
}

# TXT record to publish spf trust of servers specified in MX
resource "google_dns_record_set" "spf" {
  name = "${google_dns_managed_zone.mail.dns_name}"
  managed_zone = "${google_dns_managed_zone.mail.name}"
  type = "TXT"
  ttl  = 300

  rrdatas = ["\"v=spf1 a mx ptr ~all\""]
}

# DKIM record to publish public DKIM key
resource "google_dns_record_set" "dkim" {
  name = "dkim._domainkey.${google_dns_managed_zone.mail.dns_name}"
  managed_zone = "${google_dns_managed_zone.mail.name}"
  type = "TXT"
  ttl  = 300

  rrdatas = ["\"v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCyMmYS+Az0Y4v1ap8q2t9oGgj2rp9yRJhDB34sIOa6eDc1Oacr2afU50FpHdjgoO1UG8bANDZ7tWrWT3YNnLAiDQYCse8UHaKS8UgHCLurfIrdZmKIhUABP9ev+JMcHujbljDbWhmJloiaXWbjihDtjXdlkNVpFdkNgJCVHfVYowIDAQAB\""]
}

# SRV for client submission autoconfig
resource "google_dns_record_set" "submissionsrv" {
  name = "_submission._tcp.${google_dns_managed_zone.mail.dns_name}"
  managed_zone = "${google_dns_managed_zone.mail.name}"
  type = "SRV"
  ttl  = 300

  rrdatas = ["0 1 587 mail.${var.domain}."]
}

# SRV for imap client autoconfig
resource "google_dns_record_set" "imapsrv" {
  name = "_imap._tcp.${google_dns_managed_zone.mail.dns_name}"
  managed_zone = "${google_dns_managed_zone.mail.name}"
  type = "SRV"
  ttl  = 300

  rrdatas = ["0 1 143 mail.${var.domain}."]
}

# MX record that points to mail.`domain`
resource "google_dns_record_set" "mx" {
  name = "${google_dns_managed_zone.mail.dns_name}"
  managed_zone = "${google_dns_managed_zone.mail.name}"
  type = "MX"
  ttl  = 3600

  rrdatas = [ "5 mail.${var.domain}." ]
}

# Create a certificate for the domain
provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

resource "tls_private_key" "private_key" {
  algorithm = "ECDSA"
  ecdsa_curve = "P256"
}

resource "acme_registration" "reg" {
  account_key_pem = "${tls_private_key.private_key.private_key_pem}"
  email_address   = var.email
}

resource "acme_certificate" "certificate" {
  account_key_pem = "${acme_registration.reg.account_key_pem}"
  common_name = "mail.${var.domain}"

  dns_challenge {
    provider = "gcloud"
    config = {
      GCE_PROJECT = "${data.google_project.project.project_id}"
    }
  }
}

# The service account that the nodes in the node pool will run as
resource "google_service_account" "svcpool" {
  account_id = "node-pools"
}

# Bindings to give only essential permissions to the nodes
resource "google_project_iam_binding" "satokencreator" {
  role = "roles/iam.serviceAccountTokenCreator"

  members = [
    "serviceAccount:${google_service_account.svcpool.email}",
  ]
}

resource "google_project_iam_binding" "logwriter" {
  role = "roles/logging.logWriter"

  members = [
    "serviceAccount:${google_service_account.svcpool.email}",
  ]
}

resource "google_project_iam_binding" "metricwriter" {
  role = "roles/monitoring.metricWriter"

  members = [
    "serviceAccount:${google_service_account.svcpool.email}",
  ]
}

resource "google_project_iam_binding" "monitoringviewer" {
  role = "roles/monitoring.viewer"

  members = [
    "serviceAccount:${google_service_account.svcpool.email}",
  ]
}

resource "google_project_iam_binding" "storageviewer" {
  role = "roles/storage.objectViewer"

  members = [
    "serviceAccount:${google_service_account.svcpool.email}",
  ]
}

# Configures a gke cluster to run the project workloads
resource "google_container_cluster" "alpha" {
  name     = "alpha"
  location = "us-west1-a"
  provider = "google-beta"

  # Squelching these services runs less system pods on the cluster, saving resources
  monitoring_service = "none"
  logging_service = "none"

  addons_config {
    network_policy_config {
      disabled = false
    }

	# Keep the horizontal autoscaler service from taking node resources
    horizontal_pod_autoscaling {
      disabled = true
    }
  }

  network_policy {
    enabled = true
  }

  # Enable VPC-native Networking
  ip_allocation_policy {
    use_ip_aliases = true
  }

  workload_identity_config {
    identity_namespace = "${data.google_project.project.project_id}.svc.id.goog"
  }

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count = 1
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "wading-pool"
  location   = var.zone
  cluster    = google_container_cluster.alpha.name

  management {
    auto_upgrade = true
    auto_repair = true
  }

  # We're not supposed to do this, but without this 0 nodes are created
  initial_node_count = 2
  
  autoscaling {
    min_node_count = 2
    max_node_count = 6
  }

  node_config {
	# since the system is autorepairing, use cheaper preemptible nodes
    preemptible  = true
    machine_type = "g1-small"
    disk_size_gb = 50
    # Run the nodes as the created service account
    service_account = google_service_account.svcpool.email

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/monitoring.write",
    ]
  }
}

# Store the letsencrypt pki material to a kubernetes secret
resource "kubernetes_secret" "tlspki" {
  metadata {
    name = "tlspki"
  }

  data = {
    "cert.pem" = "${acme_certificate.certificate.certificate_pem}"
    "key.pem" = "${acme_certificate.certificate.private_key_pem}"
  }
}
