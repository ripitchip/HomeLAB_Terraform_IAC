# --- Téléchargement de l'Image Debian ---
resource "proxmox_virtual_environment_download_file" "debian_base_image" {
  content_type        = "iso"
  datastore_id        = "local"
  node_name           = var.proxy_config.node
  url                 = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
  file_name           = "debian-13-proxy-int.img"
  overwrite           = true
  overwrite_unmanaged = true
}

# --- Génération du snippet Cloud-Init ---
resource "proxmox_virtual_environment_file" "proxy_int_init_snippet" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxy_config.node

  source_raw {
    file_name = "proxy-int-senior-init.yaml"
    data      = local.proxy_int_cloud_init
  }
}

# --- VM Internal Proxy ---
resource "proxmox_virtual_environment_vm" "proxy_int_vm" {
  name      = var.proxy_config.hostname
  node_name = var.proxy_config.node
  vm_id     = var.proxy_config.vm_id
  tags      = ["infra", "proxy", "senior"]

  scsi_hardware = "virtio-scsi-pci"
  boot_order    = ["virtio0"]

  # FIX: On désactive le timeout de l'agent pour éviter le deadlock au refresh
  agent { 
    enabled = true
    timeout = "0s" 
  }

  cpu {
    cores = var.proxy_config.cpu
    type  = "host"
  }

  memory {
    dedicated = var.proxy_config.ram
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = var.proxy_config.vlan
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "virtio0"
    size         = var.proxy_config.disk
    file_id      = proxmox_virtual_environment_download_file.debian_base_image.id
    file_format  = "raw"
    iothread     = true
    discard      = "on"
  }

  initialization {
    datastore_id      = "local-lvm"
    user_data_file_id = proxmox_virtual_environment_file.proxy_int_init_snippet.id

    ip_config {
      ipv4 {
        address = "${var.proxy_config.ip}/24"
        gateway = var.proxy_config.gw
      }
    }

    dns {
      servers = [var.proxy_config.dns, "1.1.1.1"]
    }

    user_account {
      keys     = [trimspace(var.ssh_public_key)]
      username = "root"
    }
  }

  # FIX: On ignore les changements d'IP qui font boucler le provider
  lifecycle {
    ignore_changes = [
      network_device,
      ipv4_addresses,
      ipv6_addresses
    ]
  }
}