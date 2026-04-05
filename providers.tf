terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.1-rc1"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  # pm_api_token_id     = var.proxmox_api_id
  # pm_api_token_secret = var.proxmox_api_secret
  pm_user             = var.proxmox_api_user
  pm_password         = var.proxmox_api_password
  pm_tls_insecure     = true
}