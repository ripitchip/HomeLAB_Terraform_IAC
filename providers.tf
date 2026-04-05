terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.100.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "${var.proxmox_api_id}=${var.proxmox_api_secret}"
  insecure  = true

  ssh {
    agent       = false
    username    = "root"
    private_key = file("/home/vscode/.ssh/id_rsa")

    node {
      name    = "node1"
      address = "10.0.10.10" # L'IP de ton Proxmox
    }
  }
}