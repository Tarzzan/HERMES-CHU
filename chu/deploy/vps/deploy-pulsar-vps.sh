#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 William MERI — DSIO, CHU de Guyane
# ============================================================
#  PULSAR -- Script de deploiement VPS
#  DSIO -- CHU de Guyane | William MERI
#
#  Ce script deploie PULSAR sur le VPS de production.
#  A executer depuis la machine locale avec acces SSH au VPS.
#
#  Usage :
#    bash deploy-pulsar-vps.sh [--rebuild] [--update-only]
# ============================================================

set -e

VPS_HOST="57.128.241.123"
VPS_USER="ubuntu"
VPS_HERMES_DIR="/home/ubuntu/hermes"
GITHUB_REPO="https://github.com/Tarzzan/PULSAR-CHU.git"
PULSAR_VERSION="2.3.0"

REBUILD=false
UPDATE_ONLY=false

for arg in "$@"; do
    case $arg in
        --rebuild) REBUILD=true ;;
        --update-only) UPDATE_ONLY=true ;;
    esac
done

echo ""
echo "  ============================================================"
echo "  PULSAR v${PULSAR_VERSION} -- Deploiement VPS"
echo "  Cible : ${VPS_USER}@${VPS_HOST}"
echo "  ============================================================"
echo ""

# ── Fonction SSH ─────────────────────────────────────────────
vps_exec() {
    ssh -o StrictHostKeyChecking=no "${VPS_USER}@${VPS_HOST}" "$@"
}

# ── Etape 1 : Verifier la connexion VPS ──────────────────────
echo "  [1/6] Verification de la connexion VPS..."
vps_exec "echo '[OK] Connexion VPS etablie'"

# ── Etape 2 : Mettre a jour le depot HERMES-CHU ──────────────
echo "  [2/6] Mise a jour du depot HERMES-CHU..."
vps_exec "
    if [ -d '/home/ubuntu/HERMES-CHU' ]; then
        cd /home/ubuntu/HERMES-CHU && git pull origin main
        echo '[OK] Depot mis a jour.'
    else
        git clone ${GITHUB_REPO} /home/ubuntu/HERMES-CHU
        echo '[OK] Depot clone.'
    fi
"

# ── Etape 3 : Copier les fichiers PULSAR dans hermes ─────────
echo "  [3/6] Copie des fichiers PULSAR..."
vps_exec "
    # Copier le Dockerfile PULSAR
    cp /home/ubuntu/HERMES-CHU/chu/deploy/vps/Dockerfile.pulsar ${VPS_HERMES_DIR}/Dockerfile.pulsar
    cp /home/ubuntu/HERMES-CHU/chu/deploy/vps/entrypoint-pulsar.sh ${VPS_HERMES_DIR}/entrypoint-pulsar.sh
    chmod +x ${VPS_HERMES_DIR}/entrypoint-pulsar.sh

    # Copier les fichiers CHU
    mkdir -p ${VPS_HERMES_DIR}/chu
    cp -r /home/ubuntu/HERMES-CHU/chu/privacy_engine ${VPS_HERMES_DIR}/chu/
    cp -r /home/ubuntu/HERMES-CHU/chu/api ${VPS_HERMES_DIR}/chu/
    cp -r /home/ubuntu/HERMES-CHU/chu/skills ${VPS_HERMES_DIR}/chu/
    cp /home/ubuntu/HERMES-CHU/chu/config_chu.yaml ${VPS_HERMES_DIR}/chu/

    echo '[OK] Fichiers PULSAR copies.'
"

# ── Etape 4 : Construire l'image Docker PULSAR ───────────────
if [ "$UPDATE_ONLY" = false ]; then
    echo "  [4/6] Construction de l'image Docker PULSAR..."
    if [ "$REBUILD" = true ]; then
        vps_exec "cd ${VPS_HERMES_DIR} && docker build --no-cache -f Dockerfile.pulsar -t pulsar-chu:${PULSAR_VERSION} -t pulsar-chu:latest . 2>&1 | tail -20"
    else
        vps_exec "cd ${VPS_HERMES_DIR} && docker build -f Dockerfile.pulsar -t pulsar-chu:${PULSAR_VERSION} -t pulsar-chu:latest . 2>&1 | tail -20"
    fi
    echo "  [OK] Image Docker construite."
else
    echo "  [4/6] Construction ignoree (--update-only)."
fi

# ── Etape 5 : Arreter l'ancien conteneur hermes-agent ────────
echo "  [5/6] Remplacement du conteneur hermes-agent par pulsar-chu..."
vps_exec "
    # Arreter et supprimer l'ancien conteneur hermes-agent
    docker stop hermes-agent 2>/dev/null || true
    docker rm hermes-agent 2>/dev/null || true

    # Arreter l'ancien conteneur pulsar si existant
    docker stop pulsar-chu 2>/dev/null || true
    docker rm pulsar-chu 2>/dev/null || true

    echo '[OK] Anciens conteneurs supprimes.'
"

# ── Etape 6 : Demarrer PULSAR ────────────────────────────────
echo "  [6/6] Demarrage de PULSAR..."
vps_exec "
    cd ${VPS_HERMES_DIR}
    docker run -d \
        --name pulsar-chu \
        --restart unless-stopped \
        -u 0:0 \
        -e OPENROUTER_API_KEY=\${OPENROUTER_API_KEY} \
        -e NOUS_API_KEY=\${NOUS_API_KEY} \
        -e TELEGRAM_BOT_TOKEN=\${TELEGRAM_BOT_TOKEN} \
        -e TELEGRAM_ALLOWED_USERS=\${TELEGRAM_ALLOWED_USERS} \
        -e FORGEJO_API_URL=\${FORGEJO_API_URL:-https://git.cosmolan.fr} \
        -e FORGEJO_TOKEN=\${FORGEJO_TOKEN} \
        -e CHU_PRIVACY_ENGINE_ACTIF=true \
        -e CHU_AUDIT_LOG_DIR=/home/pulsar/.hermes/audit \
        -e HOME=/home/pulsar \
        -v pulsar-data:/home/pulsar/.hermes \
        -v /home/ubuntu:/home/ubuntu:rw \
        -v /var/run/docker.sock:/var/run/docker.sock:rw \
        -p 9119:9119 \
        -p 8001:8001 \
        --network npm_default \
        pulsar-chu:${PULSAR_VERSION}

    echo '[OK] PULSAR demarre.'
    sleep 3
    docker ps | grep pulsar-chu
"

echo ""
echo "  ============================================================"
echo "  PULSAR v${PULSAR_VERSION} -- Deploiement termine"
echo "  ============================================================"
echo ""
echo "  Dashboard : http://${VPS_HOST}:9119"
echo "  API CHU   : http://${VPS_HOST}:8001/api/chu/docs"
echo ""
echo "  Logs : docker logs -f pulsar-chu"
echo ""
