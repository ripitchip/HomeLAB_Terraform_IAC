# 1. Téléchargement de l'image (une seule fois par nœud Proxmox)
resource "proxmox_virtual_environment_download_file" "debian_image" {
  for_each     = toset(local.k8s_nodes)
  content_type = "iso"
  datastore_id = "local"
  node_name    = each.value
  url          = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
  file_name    = "debian-13-k8s.img"
}

# 2. Génération des Snippets Cloud-init (un par VM)
resource "proxmox_virtual_environment_file" "k8s_snippets" {
  for_each     = local.all_k8s_vms
  content_type = "snippets"
  datastore_id = "local"
  node_name    = each.value.node

  source_raw {
    file_name = "init-${each.key}.yaml"
    data      = replace(local.k8s_config, "$${hostname}", each.key)
  }
}

# 3. Déploiement des VMs (Masters + Workers)
resource "proxmox_virtual_environment_vm" "k8s_vms" {
  for_each  = local.all_k8s_vms
  name      = each.key
  node_name = each.value.node
  vm_id     = each.value.vm_id
  tags      = length(regexall("master", each.key)) > 0 ? ["k8s", "master"] : ["k8s", "worker"]

  scsi_hardware = "virtio-scsi-pci"
  boot_order    = ["virtio0"]

  agent {
    enabled = true
    timeout = "0s"
  }
  cpu {
    cores = each.value.cpu
    type = "host"
  }
  memory { dedicated = each.value.ram }

  network_device {
    bridge  = "vmbr0"
    vlan_id = var.k8s_network.vlan
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "virtio0"
    size         = each.value.disk
    file_id      = proxmox_virtual_environment_download_file.debian_image[each.value.node].id
    file_format  = "raw"
    iothread     = true
    discard      = "on"
  }

  initialization {
    datastore_id      = "local-lvm"
    user_data_file_id = proxmox_virtual_environment_file.k8s_snippets[each.key].id
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.k8s_network.gateway
      }
    }
    dns { servers = [var.k8s_network.dns] }
    user_account {
      keys     = [trimspace(var.ssh_public_key)]
      username = "root"
    }
  }

  lifecycle {
    ignore_changes = [network_device, initialization]
  }
}