terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.70"
    }
  }

  backend "local" {
    path = "../../tmp/opentofu/posse.tfstate"
  }
}

provider "hcloud" {}

variable "primary_ipv4" {
  description = "Existing unassigned Hetzner Primary IPv4 address in the selected location."
  type        = string

  validation {
    condition     = can(cidrhost("${var.primary_ipv4}/32", 0)) && !strcontains(var.primary_ipv4, ":")
    error_message = "Provide a valid IPv4 address without a CIDR prefix."
  }
}

variable "location" {
  description = "Hetzner location compatible with the reserved Primary IP."
  type        = string
}

variable "server_type" {
  description = "Hetzner server type selected for the single-node K3s proof of concept."
  type        = string
}

variable "ssh_public_key" {
  description = "Operator's public SSH key to register with Hetzner."
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "Trusted operator's public IPv4 CIDR allowed to connect to SSH."
  type        = string

  validation {
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0)) && !strcontains(var.ssh_allowed_cidr, ":") && !endswith(var.ssh_allowed_cidr, "/0")
    error_message = "Provide a restricted IPv4 CIDR, such as your public address with /32."
  }
}

data "hcloud_primary_ip" "reserved" {
  ip_address = var.primary_ipv4
}

resource "hcloud_ssh_key" "operator" {
  name       = "posse-poc-operator"
  public_key = var.ssh_public_key
}

resource "hcloud_firewall" "server" {
  name = "posse-poc"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = [var.ssh_allowed_cidr]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0"]
  }
}

resource "hcloud_server" "posse" {
  name        = "posse-poc"
  server_type = var.server_type
  image       = "ubuntu-24.04"
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.operator.name]
  firewall_ids = [
    hcloud_firewall.server.id,
  ]

  public_net {
    ipv4         = data.hcloud_primary_ip.reserved.id
    ipv4_enabled = true
    ipv6_enabled = false
  }

  labels = {
    purpose    = "posse-poc"
    managed-by = "opentofu"
  }
}

output "server_ipv4" {
  description = "Reserved IPv4 assigned to the POSSE server."
  value       = data.hcloud_primary_ip.reserved.ip_address
}