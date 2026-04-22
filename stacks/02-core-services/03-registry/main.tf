# --- Téléchargement de l'Image ---
resource "proxmox_virtual_environment_download_file" "debian_base_image" {
  content_type        = "iso"
  datastore_id        = "local"
  node_name           = var.reg_config.node
  url                 = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
  file_name           = "debian-13-trixie.img"
  overwrite           = true
  overwrite_unmanaged = true
}

# --- Génération du snippet Cloud-Init ---
resource "proxmox_virtual_environment_file" "nexus_init_snippet" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.reg_config.node

  source_raw {
    file_name = "nexus-senior-init.yaml"
    data      = local.nexus_cloud_init
  }
}

# --- VM Nexus ---
resource "proxmox_virtual_environment_vm" "registry_vm" {
  name      = var.reg_config.hostname
  node_name = var.reg_config.node
  vm_id     = var.reg_config.vm_id
  tags      = ["infra", "nexus", "senior"]

  scsi_hardware = "virtio-scsi-pci"
  boot_order    = ["virtio0"]

  cpu {
    cores = var.reg_config.cpu
    type  = "host"
  }

  memory {
    dedicated = var.reg_config.ram
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = var.reg_config.vlan
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "virtio0"
    size         = var.reg_config.disk
    file_id      = proxmox_virtual_environment_download_file.debian_base_image.id
    file_format  = "raw"
    iothread     = true
    discard      = "on"
  }

  initialization {
    datastore_id      = "local-lvm"
    user_data_file_id = proxmox_virtual_environment_file.nexus_init_snippet.id

    ip_config {
      ipv4 {
        address = "${var.reg_config.ip}/24"
        gateway = var.reg_config.gw
      }
    }

    dns {
      servers = [var.reg_config.dns, "1.1.1.1"]
    }

    user_account {
      keys     = [trimspace(var.ssh_public_key)]
      username = "root"
    }
  }
}
