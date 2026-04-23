# --- Image Debian pour Vault ---
resource "proxmox_virtual_environment_download_file" "debian_vault_image" {
  content_type        = "iso"
  datastore_id        = "local"
  node_name           = var.vault_config.node
  url                 = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
  file_name           = "debian-13-vault-internal.img"
}

# --- Génération du snippet Cloud-Init (Cible Vault) ---
resource "proxmox_virtual_environment_file" "vault_init_snippet" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.vault_config.node

  source_raw {
    file_name = "vault-internal-senior-init.yaml"
    data      = local.vault_internal_cloud_init
  }
}

# --- VM HashiCorp Vault ---
resource "proxmox_virtual_environment_vm" "vault_vm" {
  name      = var.vault_config.hostname
  node_name = var.vault_config.node
  vm_id     = var.vault_config.vm_id
  tags      = ["infra", "security", "vault"]

  scsi_hardware = "virtio-scsi-pci"
  boot_order    = ["virtio0"]

  # Indispensable pour que Proxmox remonte l'IP à Terraform
  agent { 
    enabled = true
    timeout = "0s" 
  }

  cpu {
    cores = var.vault_config.cpu
    type  = "host"
  }

  memory {
    dedicated = var.vault_config.ram
    # Senior Tip: On évite le ballooning pour que Vault puisse lock sa RAM
    floating  = 0 
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = var.vault_config.vlan
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "virtio0"
    size         = var.vault_config.disk
    file_id      = proxmox_virtual_environment_download_file.debian_vault_image.id
    file_format  = "raw"
    iothread     = true
    discard      = "on"
  }

  initialization {
    datastore_id      = "local-lvm"
    user_data_file_id = proxmox_virtual_environment_file.vault_init_snippet.id

    ip_config {
      ipv4 {
        address = "${var.vault_config.ip}/24"
        gateway = var.vault_config.gw
      }
    }

    dns {
      servers = [var.vault_config.dns, "1.1.1.1"]
    }

    user_account {
      keys     = [trimspace(var.ssh_public_key)]
      username = "root"
    }
  }

  # Sécurité pour éviter les cycles infinis lors du refresh de l'agent
  lifecycle {
    ignore_changes = [
      network_device,
      ipv4_addresses,
      ipv6_addresses
    ]
  }
}