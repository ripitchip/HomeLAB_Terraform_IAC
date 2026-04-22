locals {
  nexus_cloud_init = <<EOT
#cloud-config
hostname: ${var.reg_config.hostname}

users:
  - name: root
    ssh_authorized_keys:
      - ${trimspace(var.ssh_public_key)}

runcmd:
  - exec > /var/log/infra-setup.log 2>&1
  - echo "--- Starting Automated Senior Nexus 3.91.0-07 Deploy ---"
  
  # 1. FIX DNS & SSH
  - systemctl stop systemd-resolved || true
  - systemctl disable systemd-resolved || true
  - echo "nameserver ${var.reg_config.dns}" > /etc/resolv.conf
  - echo "nameserver 1.1.1.1" >> /etc/resolv.conf
  - mkdir -p /root/.ssh && chmod 700 /root/.ssh
  - echo "${trimspace(var.ssh_public_key)}" >> /root/.ssh/authorized_keys

  # 2. INSTALL DEPS (Java 17 est la version stable recommandée pour Nexus 3.x)
  - apt-get update
  - apt-get install -y nfs-common openjdk-17-jre-headless jq tar wget curl

  # 3. PREP & MOUNT NFS
  - mkdir -p /opt/sonatype/nexus-data
  - |
    if ! grep -q "/opt/sonatype/nexus-data" /etc/fstab; then
      echo "${var.nas_ip}:${var.nas_path} /opt/sonatype/nexus-data nfs defaults,nolock,noatime,nfsvers=4.1,_netdev 0 0" >> /etc/fstab
    fi
  - mount -a || (sleep 5 && mount -t nfs -o nolock ${var.nas_ip}:${var.nas_path} /opt/sonatype/nexus-data)

  # 4. SCRIPT DE DEPLOIEMENT
  - |
    cat <<'EOF' > /usr/local/bin/deploy-nexus.sh
    #!/bin/bash
    NX_VER="3.91.0-07"
    INSTALL_DIR="/opt/sonatype"
    DATA_DIR="/opt/sonatype/nexus-data"
    
    # Création utilisateur nexus
    id -u nexus &>/dev/null || useradd -r -d $DATA_DIR -s /sbin/nologin nexus
    
    echo "Downloading Nexus $NX_VER..."
    mkdir -p $INSTALL_DIR
    cd $INSTALL_DIR
    wget -q --no-check-certificate "https://download.sonatype.com/nexus/3/nexus-$NX_VER-linux-x86_64.tar.gz" -O nexus.tar.gz
    
    echo "Extracting..."
    tar -xf nexus.tar.gz
    [ -d "nexus" ] && rm -rf "nexus"
    mv nexus-$NX_VER nexus
    rm nexus.tar.gz

    # Configuration du runtime
    echo 'run_as_user="nexus"' > $INSTALL_DIR/nexus/bin/nexus.rc

    # VMOptions optimisées
    cat <<EOC > $INSTALL_DIR/nexus/bin/nexus.vmoptions
    -Xms4096m
    -Xmx4096m
    -XX:MaxDirectMemorySize=4096m
    -Djava.net.preferIPv4Stack=true
    -Dkaraf.home=.
    -Dkaraf.base=.
    -Dkaraf.etc=etc/karaf
    -Djava.io.tmpdir=$DATA_DIR/nexus3/tmp
    -Dkaraf.data=$DATA_DIR/nexus3
    -Dkaraf.log=$DATA_DIR/nexus3/log
    -Djava.util.logging.config.file=etc/karaf/java.util.logging.properties
    -XX:+UnlockExperimentalVMOptions
    -XX:+UseG1GC
    EOC

    mkdir -p $DATA_DIR/nexus3/tmp
    chown -R nexus:nexus $INSTALL_DIR
    chown -R nexus:nexus $DATA_DIR

    # Systemd Service
    cat <<EOS > /etc/systemd/system/nexus.service
    [Unit]
    Description=Sonatype Nexus Repository Service
    After=network.target remote-fs.target
    [Service]
    Type=forking
    LimitNOFILE=65536
    ExecStart=$INSTALL_DIR/nexus/bin/nexus start
    ExecStop=$INSTALL_DIR/nexus/bin/nexus stop
    User=nexus
    Restart=always
    [Install]
    WantedBy=multi-user.target
    EOS

    systemctl daemon-reload
    systemctl enable --now nexus

    echo "Waiting for Nexus startup..."
    for i in {1..30}; do
      if [ -f $DATA_DIR/nexus3/admin.password ]; then
        cp $DATA_DIR/nexus3/admin.password /root/nexus_init_pass.txt
        echo "--- Nexus Ready (New Install) ---"
        exit 0
      fi
      if curl -s -I http://localhost:8081 | grep -q "200 OK"; then
        echo "--- Nexus Ready (Already Configured) ---"
        exit 0
      fi
      echo "Checking Nexus status ($i/30)..."
      sleep 10
    done
    EOF

  - chmod +x /usr/local/bin/deploy-nexus.sh
  - /usr/local/bin/deploy-nexus.sh
EOT
}