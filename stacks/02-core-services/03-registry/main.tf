# --- Téléchargement de l'Image Cloud-Image ---
resource "proxmox_virtual_environment_download_file" "debian_base_image" {
  content_type        = "iso"
  datastore_id        = "local"
  node_name           = var.reg_config.node
  url                 = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
  file_name           = "debian-13-senior-base.img"
  overwrite           = true
  overwrite_unmanaged = true
}

# --- Génération du snippet Cloud-Init ---
resource "proxmox_virtual_environment_file" "harbor_init_snippet" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.reg_config.node

  source_raw {
    file_name = "harbor-senior-init.yaml"
    data      = local.harbor_cloud_init
  }
}

# --- VM Harbor Registry ---
resource "proxmox_virtual_environment_vm" "registry_vm" {
  name      = var.reg_config.hostname
  node_name = var.reg_config.node
  vm_id     = var.reg_config.vm_id
  tags      = ["infra", "registry", "harbor", "senior"]

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
  }

  initialization {
    datastore_id      = "local-lvm"
    user_data_file_id = proxmox_virtual_environment_file.harbor_init_snippet.id

    ip_config {
      ipv4 {
        address = "${var.reg_config.ip}/24"
        gateway = var.reg_config.gw
      }
    }
  }
}
