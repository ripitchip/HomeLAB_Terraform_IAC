locals {
  proxy_int_cloud_init = <<EOT
#cloud-config
hostname: ${var.proxy_config.hostname}

users:
  - name: root
    ssh_authorized_keys:
      - ${trimspace(var.ssh_public_key)}

write_files:
  # 1. Sources APT (Nexus Debian)
  - path: /etc/apt/sources.list
    content: |
      deb [trusted=yes] http://registry.foobarbaz.lan:8081/repository/debian/ trixie main
      deb [trusted=yes] http://registry.foobarbaz.lan:8081/repository/debian-security/ trixie-security main

  # 2. Configuration Vault Agent
  - path: /etc/vault.d/agent.hcl
    content: |
      exit_after_auth = false
      pid_file = "/run/vault-agent.pid"

      vault {
        address = "http://10.0.50.13:8200"
      }

      template {
        contents = <<EOF
        {{- with secret "pki/issue/foobarbaz-wildcard" "common_name=*.foobarbaz.lan" "ttl=720h" -}}
        {{ .Data.certificate }}
        {{ .Data.issuing_ca }}
        {{- end -}}
        EOF
        destination = "/etc/nginx/ssl/wildcard.crt"
      }

      template {
        contents = <<EOF
        {{- with secret "pki/issue/foobarbaz-wildcard" "common_name=*.foobarbaz.lan" -}}
        {{ .Data.private_key }}
        {{- end -}}
        EOF
        destination = "/etc/nginx/ssl/wildcard.key"
        command = "systemctl reload nginx || true"
      }

  # 3. Configuration Nginx pour dns.foobarbaz.lan
  - path: /etc/nginx/sites-available/dns.foobarbaz.lan
    content: |
      server {
          listen 80;
          server_name dns.foobarbaz.lan;
          location / { return 301 https://$host$request_uri; }
      }

      server {
          listen 443 ssl;
          server_name dns.foobarbaz.lan;

          ssl_certificate     /etc/nginx/ssl/wildcard.crt;
          ssl_certificate_key /etc/nginx/ssl/wildcard.key;

          # Resolver interne (ton DNS 10.0.50.11)
          resolver 10.0.50.11 valid=30s;
          set $upstream_dns dns.infra.foobarbaz.lan;

          location / {
              proxy_pass http://$upstream_dns:5380;
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              
              # Support WebSockets
              proxy_http_version 1.1;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "upgrade";
          }
      }

runcmd:
  - exec > /var/log/infra-setup.log 2>&1
  - echo "--- Starting Nginx + Vault Agent Setup ---"
  
  # DNS Setup : On force l'utilisation de ton DNS interne 10.0.50.11
  - echo "nameserver 10.0.50.11" > /etc/resolv.conf
  - echo "search infra.foobarbaz.lan foobarbaz.lan" >> /etc/resolv.conf
  - rm -rf /etc/apt/sources.list.d/*

  # Installation des paquets
  - apt-get update
  - export DEBIAN_FRONTEND=noninteractive
  - apt-get install -y nginx nfs-common curl jq unzip openssl

  # Installation binaire Vault
  - |
    curl -fsSL https://releases.hashicorp.com/vault/1.15.4/vault_1.15.4_linux_amd64.zip -o /tmp/vault.zip
    unzip -o /tmp/vault.zip -d /usr/bin/
    chmod +x /usr/bin/vault

  # Préparation des dossiers et SSL temporaire
  - mkdir -p /etc/nginx/ssl /etc/vault.d /etc/nginx/sites-enabled
  - openssl req -x509 -nodes -days 1 -newkey rsa:2048 -keyout /etc/nginx/ssl/wildcard.key -out /etc/nginx/ssl/wildcard.crt -subj "/CN=temp"

  # Montage NFS
  - mkdir -p /mnt/nas_proxy
  - |
    if ! grep -q "/mnt/nas_proxy" /etc/fstab; then
      echo "10.0.60.10:/mnt/data/infra_storage/proxy_configs /mnt/nas_proxy nfs defaults,nolock,noatime,nfsvers=4.1,_netdev 0 0" >> /etc/fstab
    fi
  - mount -a || true

  # Activation Vhost
  - ln -sf /etc/nginx/sites-available/dns.foobarbaz.lan /etc/nginx/sites-enabled/
  - rm -f /etc/nginx/sites-enabled/default

  # Setup Service Vault Agent avec injection du TOKEN
  - |
    cat <<EOF > /etc/systemd/system/vault-agent.service
    [Unit]
    Description=Vault Agent for Certificate Rotation
    After=network.target
    [Service]
    Environment="VAULT_TOKEN=${var.vault_token}"
    ExecStart=/usr/bin/vault agent -config=/etc/vault.d/agent.hcl
    Restart=always
    [Install]
    WantedBy=multi-user.target
    EOF

  - systemctl daemon-reload
  - systemctl enable --now vault-agent
  - systemctl enable --now nginx
  
  # Délai pour le certificat réel et reload
  - sleep 5
  - systemctl reload nginx
EOT
}