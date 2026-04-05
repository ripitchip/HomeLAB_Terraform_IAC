# --- 1. RESSOURCE IMAGE (Debian 13 Trixie) ---
resource "proxmox_virtual_environment_download_file" "debian_13_trixie" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "node1"
  url          = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
  file_name    = "debian-13-trixie.img"
}

# --- 2. CONFIGURATION CLOUD-INIT (Provisioning) ---
resource "proxmox_virtual_environment_file" "dns_cloud_config" {
  for_each     = var.dns_vms
  content_type = "snippets"
  datastore_id = "local"
  node_name    = each.value.target_node

  source_raw {
    data = <<EOT
#cloud-config
hostname: ${each.key}

# On simplifie au maximum pour le debug
users:
  - name: root
    ssh_authorized_keys:
      - ${var.ssh_public_key}

# Utilisation de la syntaxe liste (plus robuste) pour les packages
packages: [qemu-guest-agent, curl, nfs-common, e2fsprogs]

# On redirige TOUTE la sortie du runcmd vers un fichier de debug
runcmd:
  - exec > /var/log/debug-runcmd.log 2>&1
  - [ systemctl, enable, --now, qemu-guest-agent ]
  
  # 1. Fix de compatibilité ICU pour Debian 13 (Trixie)
  - apt-get install -y libicu-dev
  - ln -s /usr/lib/x86_64-linux-gnu/libicuuc.so.76 /usr/lib/x86_64-linux-gnu/libicuuc.so.72
  - ln -s /usr/lib/x86_64-linux-gnu/libicui18n.so.76 /usr/lib/x86_64-linux-gnu/libicui18n.so.72
  - ln -s /usr/lib/x86_64-linux-gnu/libicudata.so.76 /usr/lib/x86_64-linux-gnu/libicudata.so.72
  
  # 2. Préparation NFS
  - mkdir -p /etc/dns/config
  - echo "${var.nas_ip}:/mnt/data/infra_storage/dns_data /etc/dns/config nfs defaults,_netdev,bg,soft,timeo=100,retrans=2 0 0" >> /etc/fstab
  
  # 3. Installation Technitium
  - curl -fsSL https://download.technitium.com/dns/install.sh | bash
  
  # 4. Forcer la création du service (car l'installateur échoue sur Trixie)
  - |
    cat <<EOF > /etc/systemd/system/dnsserver.service
    [Unit]
    Description=Technitium DNS Server
    After=network.target

    [Service]
    WorkingDirectory=/etc/dns
    ExecStart=/usr/bin/dotnet /etc/dns/DnsServerApp.dll
    Restart=always
    RestartSec=10
    SyslogIdentifier=dnsserver
    User=root

    [Install]
    WantedBy=multi-user.target
    EOF
  
  # 5. Démarrage et Verrouillage DNS
  - systemctl daemon-reload
  - systemctl enable --now dnsserver
  - mount -a || true
  - chattr -i /etc/resolv.conf || true
  - echo "nameserver 10.0.50.1" > /etc/resolv.conf
  - chattr +i /etc/resolv.conf
EOT
    file_name = "cloud-config-${each.key}.yaml"
  }
}

# --- 3. DÉPLOIEMENT DE LA VM ---
resource "proxmox_virtual_environment_vm" "dns_nodes" {
  for_each  = var.dns_vms
  name      = each.key
  node_name = each.value.target_node
  vm_id     = each.value.id
  tags      = ["terraform", "dns", "debian13", "core-service"]

  agent { 
    enabled = true
    timeout = "5m"
  }

  cpu {
    cores = each.value.cpu
    type  = "host"
  }

  memory { dedicated = each.value.ram }

  network_device {
    bridge  = "vmbr0"
    vlan_id = each.value.vlan 
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "virtio0" 
    size         = each.value.disk
    file_id      = proxmox_virtual_environment_download_file.debian_13_trixie.id
    file_format  = "raw"
  }

  initialization {
    datastore_id = "local-lvm"
    user_account {
      keys     = [var.ssh_public_key]
      username = "root"
    }
    user_data_file_id = proxmox_virtual_environment_file.dns_cloud_config[each.key].id

    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = "10.0.50.1"
      }
    }
    # On définit aussi ici pour Proxmox
    dns { servers = ["10.0.50.1"] }
  }
}