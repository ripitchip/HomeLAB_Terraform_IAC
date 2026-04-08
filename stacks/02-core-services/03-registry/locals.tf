locals {
  harbor_cloud_init = <<EOT
#cloud-config
hostname: ${var.reg_config.hostname}

users:
  - name: root
    ssh_authorized_keys:
      - ${trimspace(var.ssh_public_key)}

runcmd:
  - exec > /var/log/infra-setup.log 2>&1
  - echo "--- Starting Automated Senior Harbor Deploy ---"
  
  # 1. FIX DNS & INSTALL
  - systemctl stop systemd-resolved || true
  - systemctl disable systemd-resolved || true
  - echo "nameserver ${var.reg_config.dns}" > /etc/resolv.conf
  - apt-get update
  - apt-get install -y nfs-common docker.io docker-compose jq tar wget curl openssl
  - systemctl enable --now docker

  # 2. MONTAGE NAS (Sécurisé)
  - mkdir -p /data
  - echo "${var.nas_ip}:/mnt/data/infra_storage/reg_data /data nfs defaults,nolock 0 0" >> /etc/fstab
  - mount -a || echo "NFS Mount failed"
  
  # 3. PREP STRUCTURE & BIND MOUNT (Le secret anti-erreur chown)
  - if mountpoint -q /data; then mkdir -p /data/harbor/registry /data/harbor/database /data/harbor/redis /data/harbor/logs; fi
  - mkdir -p /var/lib/harbor_local/ca_download /data/ca_download
  - mountpoint -q /data/ca_download || mount --bind /var/lib/harbor_local/ca_download /data/ca_download
  - chmod -R 777 /data/harbor
  - chmod 777 /var/lib/harbor_local/ca_download

  # 4. SCRIPT DE DEPLOIEMENT HYBRIDE + AUTO-LDAP
  - |
    cat <<'EOF' > /usr/local/bin/deploy-harbor.sh
    #!/bin/bash
    set -e
    cd /tmp
    VERSION=$(curl -s https://api.github.com/repos/goharbor/harbor/releases/latest | jq -r .tag_name)
    wget -q --show-progress https://github.com/goharbor/harbor/releases/download/$${VERSION}/harbor-offline-installer-$${VERSION}.tgz
    tar zxf harbor-offline-installer-$${VERSION}.tgz
    cd harbor
    
    cp harbor.yml.tmpl harbor.yml
    sed -i "s|hostname: .*|hostname: ${var.reg_config.fqdn}|g" harbor.yml
    sed -i "s|data_volume: .*|data_volume: /var/lib/harbor|g" harbor.yml
    
    # Bypass HTTPS
    sed -i 's/^https:/#https:/' harbor.yml
    sed -i 's/^  port: 443/#  port: 443/' harbor.yml
    sed -i 's/^  certificate:/#  certificate:/' harbor.yml
    sed -i 's/^  private_key:/#  private_key:/' harbor.yml

    ./install.sh

    # Bascule des volumes sur le NAS NFS
    cd /tmp/harbor
    docker compose stop
    [ -d "/var/lib/harbor/registry" ] && rm -rf /var/lib/harbor/registry
    [ -d "/var/lib/harbor/database" ] && rm -rf /var/lib/harbor/database
    ln -sf /data/harbor/registry /var/lib/harbor/registry
    ln -sf /data/harbor/database /var/lib/harbor/database
    docker compose start

    # 5. CONFIGURATION LDAP DYNAMIQUE (FORCED PLAIN)
    echo "Waiting for Harbor API to be operational..."
    until curl -s -u "admin:${var.harbor_admin_password}" http://localhost/api/v2.0/systeminfo > /dev/null; do
        sleep 5
    done

    echo "Injecting LDAP Configuration (TLS Disabled) for user: ${var.lldap_search_user}"
    curl -s -u "admin:${var.harbor_admin_password}" -X PUT -H "Content-Type: application/json" \
      -d '{
        "auth_mode": "ldap_auth",
        "ldap_url": "${var.ldap_config.url}",
        "ldap_base_dn": "ou=people,${var.ldap_config.base_dn}",
        "ldap_uid": "uid",
        "ldap_search_dn": "uid=${var.lldap_search_user},ou=people,${var.ldap_config.base_dn}",
        "ldap_search_password": "${var.lldap_search_password}",
        "ldap_filter": "(objectclass=person)",
        "ldap_scope": 2,
        "ldap_verify_cert": false,
        "ldap_starttls": false,
        "ldap_group_base_dn": "${var.ldap_config.group_base_dn}",
        "ldap_group_filter": "(objectclass=groupOfNames)",
        "ldap_group_gid": "cn",
        "ldap_group_admin_dn": "${var.ldap_config.group_admin_dn}",
        "ldap_group_membership": "memberof"
      }' "http://localhost/api/v2.0/configurations"
    
    echo "--- Setup Harbor + LDAP Ready ---"
    EOF
    
  - chmod +x /usr/local/bin/deploy-harbor.sh
  - /usr/local/bin/deploy-harbor.sh
EOT
}
