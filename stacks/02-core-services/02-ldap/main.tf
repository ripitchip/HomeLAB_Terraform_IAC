# 1. Image Debian 13 (Trixie)
resource "proxmox_virtual_environment_download_file" "debian_13_trixie" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = var.vm_config.node
  url          = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
  file_name    = "debian-13-trixie-ldap.img"
}

# 2. Snippet Cloud-Init
resource "proxmox_virtual_environment_file" "ldap_cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.vm_config.node

  source_raw {
    file_name = "cloud-config-ldap.yaml"
    data = <<EOT
#cloud-config
hostname: ${var.vm_config.name}
manage_resolv_conf: true

users:
  - name: root
    ssh_authorized_keys:
      - ${var.ssh_public_key}

packages: [qemu-guest-agent, curl, nfs-common, podman, podman-compose]

runcmd:
  - exec > /var/log/debug-runcmd.log 2>&1
  - [ systemctl, enable, --now, qemu-guest-agent ]

  # DNS Fix
  - chattr -i /etc/resolv.conf || true
  - echo "nameserver ${var.vm_config.dns_node}" > /etc/resolv.conf
  - echo "search foobarbaz.lan" >> /etc/resolv.conf
  - chattr +i /etc/resolv.conf

  # Mount NAS
  - mkdir -p /mnt/data/ldap
  - echo "${var.nas_ip}:/mnt/data/infra_storage/ldap_data /mnt/data/ldap nfs defaults,_netdev,nofail,nolock 0 0" >> /etc/fstab
  - mount -a || true

  # Déploiement LLDAP
  - mkdir -p /opt/lldap
  - |
    cat <<EOF > /opt/lldap/docker-compose.yml
    services:
      lldap:
        image: docker.io/lldap/lldap:latest
        container_name: lldap
        user: "0:0"
        # Bypass obligatoire pour éviter le bug chown sur NFS
        entrypoint: ["/app/lldap"]
        command: ["run", "--config-file", "/data/lldap_config.toml"]
        environment:
          - LLDAP_LDAP_BASE_DN=dc=foobarbaz,dc=lan
          - LLDAP_LDAP_USER_PASS=admin123
          - LLDAP_JWT_SECRET=quelquechosedetreslongetaleatoire123!
          - LLDAP_KEY_SEED=seed-de-secours-pour-le-reassure
          - LLDAP_DATABASE_URL=sqlite:///data/users.db?mode=rwc
        volumes:
          - /mnt/data/ldap:/data
        ports:
          - "17170:17170"
          - "3890:3890"
        restart: always
    EOF
  - cd /opt/lldap && podman-compose up -d
EOT
  }
}

# 3. VM LDAP
resource "proxmox_virtual_environment_vm" "ldap_vm" {
  name      = var.vm_config.name
  node_name = var.vm_config.node
  vm_id     = 5010
  tags      = ["terraform", "infra", "ldap", "debian13"]

  agent { 
    enabled = true 
    timeout = "10m"
  }

  cpu { 
    cores = var.vm_config.cpu 
    type  = "host" 
  }
  
  memory { dedicated = var.vm_config.ram }

  network_device {
    bridge  = "vmbr0"
    vlan_id = var.vm_config.vlan
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "virtio0"
    size         = var.vm_config.disk
    file_id      = proxmox_virtual_environment_download_file.debian_13_trixie.id
    file_format  = "raw"
  }

  initialization {
    datastore_id = "local-lvm"
    user_account {
      keys     = [var.ssh_public_key]
      username = "root"
    }
    
    user_data_file_id = proxmox_virtual_environment_file.ldap_cloud_config.id

    ip_config {
      ipv4 {
        address = "${var.vm_config.ip}/24"
        gateway = var.vm_config.gw
      }
    }
    dns { servers = [var.vm_config.dns_node] }
  }
}