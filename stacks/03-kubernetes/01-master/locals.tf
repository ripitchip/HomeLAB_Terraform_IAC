locals {
  all_k8s_vms = merge(var.k8s_masters, var.k8s_workers)
  k8s_nodes   = distinct([for v in local.all_k8s_vms : v.node])

  k8s_config = <<EOT
#cloud-config
hostname: $${hostname}
users:
  - name: root
    ssh_authorized_keys:
      - ${trimspace(var.ssh_public_key)}

write_files:
  # 1. On ne met que les sources Debian officielles (qui ont déjà leurs clés dans l'image)
  - path: /etc/apt/sources.list
    content: |
      deb [trusted=yes] https://registry.foobarbaz.lan/repository/debian/ trixie main
      deb [trusted=yes] https://registry.foobarbaz.lan/repository/debian-security/ trixie-security main

  # 2. Bypass SSL pour le proxy HTTPS auto-signé
  - path: /etc/apt/apt.conf.d/99-insecure
    content: |
      Acquire::https::registry.foobarbaz.lan::Verify-Peer "false";
      Acquire::https::registry.foobarbaz.lan::Verify-Host "false";

runcmd:
  - exec > /var/log/infra-setup.log 2>&1
  - echo "--- Starting K8S Infrastructure Setup ---"
  
  # DNS & Hosts Setup
  - echo "nameserver 10.0.50.11" > /etc/resolv.conf
  - echo "search infra.foobarbaz.lan foobarbaz.lan" >> /etc/resolv.conf
  - echo "10.0.50.14 registry.foobarbaz.lan" >> /etc/hosts

  - rm -rf /etc/apt/sources.list.d/*

  # PRÉREQUIS SYSTÈME
  - swapoff -a
  - sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
  - modprobe overlay && modprobe br_netfilter
  - |
    cat <<EOF > /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
    EOF
  - |
    cat <<EOF > /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    EOF
  - sysctl --system

  # GESTION DES CLÉS ET DÉPÔTS (SÉQUENTIEL)
  - mkdir -p /etc/apt/keyrings
  - export DEBIAN_FRONTEND=noninteractive
  
  # 1. Update initial (uniquement sur les dépôts Debian OK) pour installer curl
  - apt-get update
  - apt-get install -y gnupg2 curl

  # 2. Téléchargement des clés AVANT d'ajouter les dépôts
  - |
    curl -fsSL --insecure https://registry.foobarbaz.lan/repository/certs/gpg/K8S-Release.key | \
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
  - |
    curl -fsSL --insecure https://registry.foobarbaz.lan/repository/certs/gpg/Helm-Release.key | \
    gpg --dearmor -o /etc/apt/keyrings/helm-archive-keyring.gpg

  # 3. Ajout des dépôts spécifiques avec liaison explicite aux clés (évite les erreurs de signature)
  - echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://registry.foobarbaz.lan/repository/debian-kubeadm/ /" > /etc/apt/sources.list.d/kubernetes.list
  - echo "deb [signed-by=/etc/apt/keyrings/helm-archive-keyring.gpg] https://registry.foobarbaz.lan/repository/debian-helm/ any main" > /etc/apt/sources.list.d/helm.list

  # INSTALLATION DES COMPOSANTS
  - apt-get update
  - apt-get install -y jq unzip containerd kubelet kubeadm kubectl helm
  - apt-mark hold kubelet kubeadm kubectl

  # CONFIGURATION CONTAINERD
  - mkdir -p /etc/containerd
  - containerd config default > /etc/containerd/config.toml
  - sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
  - systemctl restart containerd

  # LANCEMENT
  - systemctl daemon-reload
  - systemctl enable --now kubelet
EOT
}