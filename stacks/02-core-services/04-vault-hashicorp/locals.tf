locals {
  vault_internal_cloud_init = <<EOT
#cloud-config
hostname: ${var.vault_config.hostname}

users:
  - name: root
    ssh_authorized_keys:
      - ${trimspace(var.ssh_public_key)}

runcmd:
  - exec > /var/log/vault-internal-setup.log 2>&1
  - echo "--- Starting Automated HashiCorp Vault Deploy (Senior Version) ---"
  
  # 1. RÉSEAU & DNS
  - systemctl stop systemd-resolved || true
  - systemctl disable systemd-resolved || true
  - echo "nameserver ${var.vault_config.dns}" > /etc/resolv.conf
  - echo "nameserver 1.1.1.1" >> /etc/resolv.conf

  # 2. DÉPENDANCES
  - apt-get update
  - apt-get install -y nfs-common curl jq unzip gnupg lsb-release

  # 3. CONFIGURATION DU DÉPÔT APT VIA NEXUS (Cible .15 en dur pour la sécurité)
  - mkdir -p /usr/share/keyrings
  - curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  - |
    # On utilise l'IP .15 ici car tes logs montrent que ta variable ${var.nexus_ip} renvoie .13
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] http://10.0.50.15:8081/repository/hashicorp-proxy $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list

  # 4. MONTAGE NFS
  - mkdir -p /opt/vault-data
  - |
    if ! grep -q "/opt/vault-data" /etc/fstab; then
      echo "${var.nas_ip}:${var.nas_path_vault} /opt/vault-data nfs defaults,nolock,noatime,nfsvers=4.1,_netdev 0 0" >> /etc/fstab
    fi
  - mount -a

  # 5. INSTALLATION DE VAULT
  - |
    # Création manuelle de l'utilisateur vault avant l'install au cas où
    if ! id vault >/dev/null 2>&1; then
      useradd --system --home /etc/vault.d --shell /bin/false vault
    fi
  - apt-get update
  - DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" vault
  - setcap cap_ipc_lock=+ep /usr/bin/vault

  # 6. CONFIGURATION HCL (Stockage NAS)
  - mkdir -p /etc/vault.d /opt/vault-data/storage
  - |
    cat <<EOF > /etc/vault.d/vault.hcl
    storage "file" {
      path = "/opt/vault-data/storage"
    }
    listener "tcp" {
      address     = "0.0.0.0:8200"
      tls_disable = 1
    }
    ui = true
    api_addr = "http://${var.vault_config.ip}:8200"
    disable_mlock = false
    EOF

  # 7. SERVICE SYSTEMD (Compatible Debian 13 / Trixie)
  - |
    cat <<EOF > /etc/systemd/system/vault.service
    [Unit]
    Description=HashiCorp Vault Service
    After=network.target remote-fs.target
    ConditionFileNotEmpty=/etc/vault.d/vault.hcl

    [Service]
    User=vault
    Group=vault
    ExecStart=/usr/bin/vault server -config=/etc/vault.d/vault.hcl
    ExecReload=/bin/kill --signal HUP $MAINPID
    Restart=always
    LimitMEMLOCK=infinity
    # New syntax for Debian 13
    AmbientCapabilities=CAP_IPC_LOCK
    CapabilityBoundingSet=CAP_IPC_LOCK
    NoNewPrivileges=yes

    [Install]
    WantedBy=multi-user.target
    EOF

  # 8. PERMISSIONS ET LANCEMENT
  - chmod 777 /opt/vault-data/storage || true
  - chown -R vault:vault /etc/vault.d
  - chown -R vault:vault /opt/vault-data || true
  - systemctl daemon-reload
  - systemctl enable --now vault
  - echo "--- Vault Service Deployment Finished ---"
EOT
}