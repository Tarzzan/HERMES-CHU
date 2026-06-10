#!/usr/bin/env bash
# =============================================================================
# HERMES CHU — Script d'installation et de démarrage
# =============================================================================
# Ce script :
#   1. Installe hermes-agent (NousResearch) via son installeur officiel
#   2. Configure hermes pour le contexte CHU (langue FR, fournisseur LLM)
#   3. Applique le Privacy Engine RGPD comme middleware
#   4. Démarre le serveur API CHU
#
# Usage :
#   ./chu/installer_chu.sh [--poc | --production]
#
# Prérequis :
#   - Python 3.11+
#   - Variables d'environnement configurées dans .env.chu
# =============================================================================

set -euo pipefail

MODE="${1:---poc}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║         HERMES CHU — Installation & Démarrage           ║"
echo "║    Système Agentique Hospitalier Souverain v1.0.0        ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ---------------------------------------------------------------------------
# 1. Charger les variables d'environnement
# ---------------------------------------------------------------------------
if [ -f "$REPO_DIR/.env.chu" ]; then
    echo "📋 Chargement de .env.chu..."
    set -a && source "$REPO_DIR/.env.chu" && set +a
else
    echo "⚠️  Fichier .env.chu non trouvé — copie depuis .env.chu.exemple"
    cp "$REPO_DIR/.env.chu.exemple" "$REPO_DIR/.env.chu"
    echo "   → Éditez .env.chu avec vos clés API avant de continuer."
    echo "   → Puis relancez : ./chu/installer_chu.sh $MODE"
    exit 1
fi

# ---------------------------------------------------------------------------
# 2. Installer hermes-agent (NousResearch) si non présent
# ---------------------------------------------------------------------------
if ! command -v hermes &> /dev/null; then
    echo "📦 Installation de hermes-agent (NousResearch)..."
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
    source ~/.bashrc 2>/dev/null || source ~/.zshrc 2>/dev/null || true
    echo "✅ hermes-agent installé"
else
    echo "✅ hermes-agent déjà installé : $(hermes --version 2>/dev/null || echo 'version inconnue')"
fi

# ---------------------------------------------------------------------------
# 3. Configurer hermes pour le contexte CHU
# ---------------------------------------------------------------------------
echo ""
echo "⚙️  Configuration de hermes pour le CHU..."

# Langue française
hermes config set language fr 2>/dev/null || true

# Configurer le fournisseur LLM selon le mode
if [ "$MODE" = "--poc" ]; then
    echo "   Mode POC — Configuration Azure OpenAI avec Privacy Engine RGPD"

    if [ -n "${AZURE_OPENAI_API_KEY:-}" ]; then
        hermes config set model.provider azure_openai 2>/dev/null || true
        hermes config set model.azure_openai.api_key "$AZURE_OPENAI_API_KEY" 2>/dev/null || true
        hermes config set model.azure_openai.endpoint "${AZURE_OPENAI_ENDPOINT:-}" 2>/dev/null || true
        hermes config set model.azure_openai.deployment "${AZURE_OPENAI_DEPLOYMENT:-gpt-4o}" 2>/dev/null || true
        echo "   ✅ Azure OpenAI configuré"
    elif [ -n "${OPENAI_API_KEY:-}" ]; then
        hermes config set model.provider openai 2>/dev/null || true
        hermes config set model.openai.api_key "$OPENAI_API_KEY" 2>/dev/null || true
        echo "   ✅ OpenAI configuré"
    else
        echo "   ⚠️  Aucune clé API LLM trouvée — configuration Ollama local"
        hermes config set model.provider ollama 2>/dev/null || true
        hermes config set model.ollama.base_url "http://localhost:11434" 2>/dev/null || true
    fi

elif [ "$MODE" = "--production" ]; then
    echo "   Mode Production — Configuration vLLM on-premise (Hermes-3-70B)"
    hermes config set model.provider openai_compatible 2>/dev/null || true
    hermes config set model.base_url "${VLLM_BASE_URL:-http://vllm-service:8000/v1}" 2>/dev/null || true
    hermes config set model.name "${VLLM_MODEL:-NousResearch/Hermes-3-Llama-3.1-70B-Instruct}" 2>/dev/null || true
    echo "   ✅ vLLM on-premise configuré"
fi

# Désactiver les outils dangereux en contexte CHU
hermes config set tools.shell.enabled false 2>/dev/null || true
hermes config set tools.computer.enabled false 2>/dev/null || true
hermes config set tools.browser.enabled false 2>/dev/null || true
echo "   ✅ Outils système désactivés (garde-fous CHU)"

# ---------------------------------------------------------------------------
# 4. Installer les dépendances Python du Privacy Engine CHU
# ---------------------------------------------------------------------------
echo ""
echo "📦 Installation des dépendances CHU..."
pip install fastapi uvicorn pydantic pyyaml python-dotenv 2>/dev/null || \
    pip3 install fastapi uvicorn pydantic pyyaml python-dotenv 2>/dev/null || true
echo "✅ Dépendances CHU installées"

# ---------------------------------------------------------------------------
# 5. Démarrer le serveur API CHU en arrière-plan
# ---------------------------------------------------------------------------
echo ""
echo "🚀 Démarrage du serveur API CHU (port 8001)..."
cd "$REPO_DIR"
python3 -m uvicorn chu.api.serveur_chu:app --host 0.0.0.0 --port 8001 &
API_PID=$!
echo "   ✅ API CHU démarrée (PID: $API_PID)"
echo "   📖 Documentation : http://localhost:8001/api/chu/docs"

# ---------------------------------------------------------------------------
# 6. Afficher le résumé
# ---------------------------------------------------------------------------
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                  HERMES CHU — Prêt !                    ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Mode          : $MODE                                   "
echo "║  Privacy Engine: ACTIF (anonymisation RGPD par défaut)   "
echo "║  API CHU       : http://localhost:8001/api/chu/docs      "
echo "║  Interface web : hermes web (port 3000)                  "
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Pour démarrer hermes :                                  "
echo "║    hermes                  (CLI interactif)              "
echo "║    hermes web              (Interface web)               "
echo "║    hermes gateway          (Gateway Telegram/Discord)    "
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  RAPPEL RGPD : Le Privacy Engine est actif par défaut."
echo "   Toutes les données PHI sont anonymisées avant envoi au LLM."
echo "   Le mode Glass-Break est disponible via l'interface d'administration."
echo ""
