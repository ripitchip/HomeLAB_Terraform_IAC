locals {
  proxy_int_cloud_init = <<EOT
#cloud-config
hostname: ${var.proxy_config.hostname}

users:
  - name: root
    ssh_authorized_keys:
      - ${trimspace(var.ssh_public_key)}

write_files:
  # 1. Configuration APT (Via ton miroir Nexus)
  - path: /etc/apt/sources.list
    content: |
      deb [trusted=yes] http://registry.foobarbaz.lan:8081/repository/debian/ trixie main
      deb [trusted=yes] http://registry.foobarbaz.lan:8081/repository/debian-security/ trixie-security main
      deb [trusted=yes] http://registry.foobarbaz.lan:8081/repository/debian-docker/ trixie stable

  # 2. Politique de sécurité Podman
  - path: /etc/containers/policy.json
    content: |
      {
          "default": [{"type": "insecureAcceptAnything"}],
          "transports": {
              "docker-daemon": { "": [{"type": "insecureAcceptAnything"}] }
          }
      }

  # 3. Miroir Podman (Nexus Port 8082)
  - path: /etc/containers/registries.conf
    content: |
      unqualified-search-registries = ["docker.io"]
      [[registry]]
      location = "docker.io"
      [[registry.mirror]]
      location = "registry.foobarbaz.lan:8082"
      insecure = true
      [[registry]]
      location = "registry.foobarbaz.lan:8082"
      insecure = true

runcmd:
  - exec > /var/log/infra-setup.log 2>&1
  - echo "--- Starting Nginx Proxy Manager (NPM) Bootstrap ---"
  
  # DNS Setup
  - systemctl enable --now qemu-guest-agent
  - echo "nameserver ${var.proxy_config.dns}" > /etc/resolv.conf
  - echo "nameserver 1.1.1.1" >> /etc/resolv.conf
  - rm -rf /etc/apt/sources.list.d/*

  # Installation des dépendances
  - apt-get update
  - apt-get install -y podman podman-compose nfs-common curl wget

  # Montage NAS pour la persistance de NPM (Data + Certificats)
  - mkdir -p /opt/nginx-proxy-manager
  - |
    if ! grep -q "/opt/nginx-proxy-manager" /etc/fstab; then
      echo "${var.nas_ip}:${var.nas_path_proxy} /opt/nginx-proxy-manager nfs defaults,nolock,noatime,nfsvers=4.1,_netdev 0 0" >> /etc/fstab
    fi
  - mount -a
  - until mountpoint -q /opt/nginx-proxy-manager; do sleep 1; done
  - mkdir -p /opt/nginx-proxy-manager/data /opt/nginx-proxy-manager/letsencrypt

  # Création du Podman Compose pour NPM
  - |
    cat <<EOF > /opt/nginx-proxy-manager/podman-compose.yml
    services:
      app:
        image: 'jc21/nginx-proxy-manager:latest'
        container_name: nginx-proxy-manager
        restart: always
        network_mode: host
        volumes:
          - /opt/nginx-proxy-manager/data:/data:Z
          - /opt/nginx-proxy-manager/letsencrypt:/etc/letsencrypt:Z
        environment:
          - TZ=Europe/Paris
          - DISABLE_IPV6=true
    EOF

  # Lancement
  - systemctl enable --now podman.socket
  - cd /opt/nginx-proxy-manager && podman-compose up -d
EOT
}