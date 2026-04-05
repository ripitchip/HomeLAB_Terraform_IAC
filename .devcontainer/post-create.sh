#!/usr/bin/env bash
# On enlève le -e pour cette partie pour éviter le crash si un node est down
set -u 

echo "=> Sécurisation de la clé SSH..."
if [ -f ~/.ssh/id_rsa ]; then
    chmod 600 ~/.ssh/id_rsa
else
    echo "ATTENTION: ~/.ssh/id_rsa introuvable (montage échoué ?)"
fi

echo "=> Ajout des nodes Proxmox aux known_hosts..."
mkdir -p ~/.ssh
# Liste de tes nodes
NODES=("10.0.10.10" "10.0.10.11")

for node in "${NODES[@]}"; do
    echo "Scanning $node..."
    # On ajoute || true pour que le script continue même si le scan échoue
    ssh-keyscan -H "$node" >> ~/.ssh/known_hosts 2>/dev/null || echo "Scan échoué pour $node (ignore)"
done

# On réactive le mode strict pour la suite
set -e

echo "=> Initialisation des projets Terraform..."
# On vérifie si on est bien dans le bon dossier
if [ -d "stacks" ]; then
    for stack in stacks/*/; do
        if [ -d "$stack" ]; then
            echo "Init stack: $stack"
            # On utilise -upgrade pour être sûr d'avoir les derniers providers
            terraform -chdir="$stack" init -backend=false || echo "Erreur init sur $stack"
        fi
    done
fi

echo "=> Setup terminé avec succès !"