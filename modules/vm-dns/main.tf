# modules/vm-dns/main.tf

# 1. Génération du fichier Cloud-Init localement dans le dossier du module
resource "local_file" "dns_cloud_init" {
  filename = "${path.module}/infra-dns-setup.yml"
  content  = <<EOF
#cloud-config
package_update: true
packages:
  - nfs-common
  - curl
  - qemu-guest-agent

runcmd:
  - systemctl enable --now qemu-guest-agent
  - mkdir -p /etc/dns/config
  - mount -t nfs ${var.nas_ip}:/mnt/data/infra_storage/dns_data /etc/dns/config
  - echo "${var.nas_ip}:/mnt/data/infra_storage/dns_data /etc/dns/config nfs defaults 0 0" >> /etc/fstab
  - curl -fsSL https://download.technitium.com/dns/install.sh | sudo bash
EOF
}

# 2. Envoi du fichier sur le serveur Proxmox (Node1) via SSH
# Cela remplace le "proxmox_storage_iso" qui plantait
resource "null_resource" "upload_snippet" {
  triggers = {
    file_hash = local_file.dns_cloud_init.id
  }

  provisioner "file" {
    source      = local_file.dns_cloud_init.filename
    destination = "/var/lib/vz/snippets/infra-dns-setup.yml"

    connection {
      type        = "ssh"
      user        = "root"
      # On utilise la clé privée pour s'authentifier sur le serveur physique
      private_key = file("~/.ssh/id_rsa") 
      host        = "10.0.10.10"
    }
  }
}

# 3. Création de la VM
resource "proxmox_vm_qemu" "infra_dns" {
  depends_on = [null_resource.upload_snippet]

  name        = var.vm_name
  vmid        = var.vmid
  target_node = var.target_node
  
  clone       = "debian-13-template"
  full_clone  = true
  agent       = 1

  cpu {
    cores     = 1
    type      = "host"
  }
  
  memory      = 1024

  disks {
    scsi {
      scsi0 {
        disk {
          storage = "local-lvm"
          size    = "8G"
        }
      }
    }
    ide {
      ide2 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
    tag    = 50
  }

  os_type    = "cloud-init"
  ipconfig0  = "ip=10.0.50.11/24,gw=10.0.50.1"
  sshkeys    = var.ssh_public_key
  
  # Le chemin correspond au destination du provisioner "file"
  cicustom   = "vendor=local:snippets/infra-dns-setup.yml"
}