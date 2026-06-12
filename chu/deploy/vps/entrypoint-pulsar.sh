#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 William MERI — DSIO, CHU de Guyane
# ============================================================
#  PULSAR -- Entrypoint Docker
#  DSIO -- CHU de Guyane | William MERI
# ============================================================
set -e

HERMES_DIR="$HOME/.hermes"
CHU_DIR="$HOME/chu"

echo ""
echo "  ============================================================"
echo "  PULSAR -- Systeme Agentique Medical"
echo "  DSIO -- CHU de Guyane | William MERI"
echo "  ============================================================"
echo ""

# ── Init config dir si premier demarrage ─────────────────────
if [ ! -f "$HERMES_DIR/config.yaml" ]; then
    mkdir -p "$HERMES_DIR"/{cron,sessions,logs,memories,skills,pairing,hooks,image_cache,audio_cache,audit,chu}
    if [ -f "$HOME/hermes-agent/cli-config.yaml.example" ]; then
        cp "$HOME/hermes-agent/cli-config.yaml.example" "$HERMES_DIR/config.yaml"
    fi
    echo "  [OK] Configuration initiale creee."
fi

# ── Ecrire les variables d'environnement ─────────────────────
ENV_FILE="$HERMES_DIR/.env"
touch "$ENV_FILE"

set_env_var() {
    local key="$1"
    local value="$2"
    if [ -n "$value" ]; then
        sed -i "/^${key}=/d" "$ENV_FILE"
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}

set_env_var "OPENROUTER_API_KEY" "$OPENROUTER_API_KEY"
set_env_var "TELEGRAM_BOT_TOKEN" "$TELEGRAM_BOT_TOKEN"
set_env_var "TELEGRAM_ALLOWED_USERS" "$TELEGRAM_ALLOWED_USERS"
set_env_var "FORGEJO_API_URL" "$FORGEJO_API_URL"
set_env_var "FORGEJO_TOKEN" "$FORGEJO_TOKEN"
set_env_var "NOUS_API_KEY" "$NOUS_API_KEY"
set_env_var "CHU_PRIVACY_ENGINE_ACTIF" "true"
set_env_var "CHU_AUDIT_LOG_DIR" "$HERMES_DIR/audit"

# ── Restaurer SSH config depuis le volume persistant ─────────
if [ -d "$HERMES_DIR/ssh" ]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ln -sf "$HERMES_DIR/ssh/id_ed25519" "$HOME/.ssh/id_ed25519" 2>/dev/null || true
    ln -sf "$HERMES_DIR/ssh/id_ed25519.pub" "$HOME/.ssh/id_ed25519.pub" 2>/dev/null || true
    chmod 600 "$HOME/.ssh/config" 2>/dev/null || true
    [ -f "$HERMES_DIR/ssh/known_hosts" ] && cp "$HERMES_DIR/ssh/known_hosts" "$HOME/.ssh/known_hosts"
fi

# ── Copier les skills CHU dans hermes ────────────────────────
if [ -d "$CHU_DIR/skills" ]; then
    mkdir -p "$HERMES_DIR/skills/chu"
    cp "$CHU_DIR/skills/"*.md "$HERMES_DIR/skills/chu/" 2>/dev/null || true
    echo "  [OK] Skills CHU charges."
fi

# ── Demarrer l'API CHU en arriere-plan ───────────────────────
if [ -f "$CHU_DIR/api/serveur_chu.py" ]; then
    echo "  [INFO] Demarrage API CHU sur port 8001..."
    CHU_PRIVACY_ENGINE_ACTIF=true \
    CHU_AUDIT_LOG_DIR="$HERMES_DIR/audit" \
    PYTHONPATH="$HOME" \
    python3 "$CHU_DIR/api/serveur_chu.py" --port 8001 --host 0.0.0.0 &
    echo "  [OK] API CHU demarree : http://localhost:8001/api/chu/docs"
fi

# ── Demarrer le dashboard PULSAR ─────────────────────────────
echo "  [INFO] Demarrage PULSAR Dashboard sur port 9119..."
hermes dashboard --host 0.0.0.0 --port 9119 --insecure --no-open &

# ── Demarrer le gateway (Telegram, webhooks) ─────────────────
echo "  [INFO] Demarrage PULSAR Gateway..."
exec hermes gateway
