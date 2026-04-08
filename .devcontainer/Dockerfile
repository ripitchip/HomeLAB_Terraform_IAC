FROM mcr.microsoft.com/devcontainers/base:debian-12

ARG TERRAFORM_VERSION=1.8.5

# Installation des outils système
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl unzip git openssh-client python3-pip iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# Installation Terraform
RUN curl -fsSL -o /tmp/terraform.zip \
    "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
    && unzip /tmp/terraform.zip -d /usr/local/bin \
    && rm -f /tmp/terraform.zip

# Préparation du dossier SSH pour l'utilisateur vscode
RUN mkdir -p /home/vscode/.ssh && chown vscode:vscode /home/vscode/.ssh \
    && chmod 700 /home/vscode/.ssh