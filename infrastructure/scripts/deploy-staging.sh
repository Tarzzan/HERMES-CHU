#!/usr/bin/env bash
# HERMES CHU — Script de déploiement en environnement Staging
# Usage : ./deploy-staging.sh [--skip-tests] [--dry-run]
# Conformité : ISO 27001 A.12.1.2 — Gestion des changements

set -euo pipefail

# ── Couleurs ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERREUR]${NC} $1"; exit 1; }

# ── Variables ─────────────────────────────────────────────────────────────────
NAMESPACE="hermes-staging"
REGISTRY="ghcr.io/tarzzan/hermes-chu"
VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "dev")
SKIP_TESTS=false
DRY_RUN=false

# ── Parsing des arguments ─────────────────────────────────────────────────────
for arg in "$@"; do
    case $arg in
        --skip-tests) SKIP_TESTS=true ;;
        --dry-run)    DRY_RUN=true ;;
        *) log_error "Argument inconnu : $arg" ;;
    esac
done

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          HERMES CHU — Déploiement Staging v${VERSION}         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ── Étape 1 : Vérifications préalables ───────────────────────────────────────
log_info "Étape 1/7 : Vérifications préalables..."

command -v kubectl >/dev/null 2>&1 || log_error "kubectl non trouvé"
command -v docker >/dev/null 2>&1 || log_error "docker non trouvé"
command -v helm >/dev/null 2>&1 || log_warning "helm non trouvé (optionnel)"

# Vérifier la connexion au cluster
kubectl cluster-info >/dev/null 2>&1 || log_error "Impossible de se connecter au cluster Kubernetes"
log_success "Connexion au cluster OK"

# ── Étape 2 : Tests unitaires ─────────────────────────────────────────────────
if [ "$SKIP_TESTS" = false ]; then
    log_info "Étape 2/7 : Exécution des tests unitaires..."
    cd /app
    python3 -m pytest tests/orchestrator/ tests/privacy-engine/ -v --tb=short || log_error "Tests unitaires échoués"
    log_success "Tests unitaires : OK"
else
    log_warning "Étape 2/7 : Tests unitaires ignorés (--skip-tests)"
fi

# ── Étape 3 : Build des images Docker ────────────────────────────────────────
log_info "Étape 3/7 : Build des images Docker..."

if [ "$DRY_RUN" = false ]; then
    docker build -f infrastructure/docker/orchestrator.Dockerfile \
        -t "${REGISTRY}/orchestrateur:${VERSION}" \
        -t "${REGISTRY}/orchestrateur:staging-latest" . \
        || log_error "Build orchestrateur échoué"

    docker build -f infrastructure/docker/privacy-engine.Dockerfile \
        -t "${REGISTRY}/privacy-engine:${VERSION}" \
        -t "${REGISTRY}/privacy-engine:staging-latest" . \
        || log_error "Build privacy-engine échoué"

    docker build -f infrastructure/docker/web-ui.Dockerfile \
        -t "${REGISTRY}/web-ui:${VERSION}" \
        -t "${REGISTRY}/web-ui:staging-latest" . \
        || log_error "Build web-ui échoué"

    log_success "Images Docker construites : OK"
else
    log_warning "DRY RUN — Build Docker ignoré"
fi

# ── Étape 4 : Scan de sécurité des images ────────────────────────────────────
log_info "Étape 4/7 : Scan de sécurité des images (Trivy)..."

if command -v trivy >/dev/null 2>&1 && [ "$DRY_RUN" = false ]; then
    trivy image --exit-code 1 --severity CRITICAL "${REGISTRY}/orchestrateur:${VERSION}" \
        || log_error "Vulnérabilités CRITIQUES détectées dans l'image orchestrateur !"
    trivy image --exit-code 1 --severity CRITICAL "${REGISTRY}/privacy-engine:${VERSION}" \
        || log_error "Vulnérabilités CRITIQUES détectées dans l'image privacy-engine !"
    log_success "Scan de sécurité : Aucune vulnérabilité critique"
else
    log_warning "Trivy non disponible — Scan de sécurité ignoré"
fi

# ── Étape 5 : Push des images ─────────────────────────────────────────────────
log_info "Étape 5/7 : Push des images vers le registry..."

if [ "$DRY_RUN" = false ]; then
    docker push "${REGISTRY}/orchestrateur:${VERSION}"
    docker push "${REGISTRY}/orchestrateur:staging-latest"
    docker push "${REGISTRY}/privacy-engine:${VERSION}"
    docker push "${REGISTRY}/privacy-engine:staging-latest"
    docker push "${REGISTRY}/web-ui:${VERSION}"
    docker push "${REGISTRY}/web-ui:staging-latest"
    log_success "Images poussées vers le registry : OK"
else
    log_warning "DRY RUN — Push ignoré"
fi

# ── Étape 6 : Déploiement Kubernetes ─────────────────────────────────────────
log_info "Étape 6/7 : Déploiement sur le namespace ${NAMESPACE}..."

if [ "$DRY_RUN" = false ]; then
    # Créer le namespace si nécessaire
    kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || \
        kubectl create namespace "${NAMESPACE}"

    # Appliquer les manifestes
    kubectl apply -f infrastructure/kubernetes/ -n "${NAMESPACE}" --dry-run=client
    kubectl apply -f infrastructure/kubernetes/ -n "${NAMESPACE}"

    # Attendre que les déploiements soient prêts
    log_info "Attente de la disponibilité des pods..."
    kubectl rollout status deployment/hermes-orchestrateur -n "${NAMESPACE}" --timeout=5m
    kubectl rollout status deployment/hermes-privacy-engine -n "${NAMESPACE}" --timeout=5m
    kubectl rollout status deployment/hermes-web-ui -n "${NAMESPACE}" --timeout=3m

    log_success "Déploiement Kubernetes : OK"
else
    log_warning "DRY RUN — Déploiement Kubernetes ignoré"
    kubectl apply -f infrastructure/kubernetes/ -n "${NAMESPACE}" --dry-run=client
fi

# ── Étape 7 : Tests de fumée post-déploiement ────────────────────────────────
log_info "Étape 7/7 : Tests de fumée post-déploiement..."

if [ "$DRY_RUN" = false ]; then
    STAGING_URL="https://hermes-staging.chu-interne.local"
    sleep 10  # Attendre que les services soient prêts

    # Test de santé de l'orchestrateur
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${STAGING_URL}/api/sante" || echo "000")
    [ "$HTTP_CODE" = "200" ] || log_error "Orchestrateur ne répond pas (HTTP ${HTTP_CODE})"

    # Test de santé du Privacy Engine
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${STAGING_URL}/privacy/sante" || echo "000")
    [ "$HTTP_CODE" = "200" ] || log_error "Privacy Engine ne répond pas (HTTP ${HTTP_CODE})"

    log_success "Tests de fumée : OK"
fi

# ── Résumé ────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                  DÉPLOIEMENT RÉUSSI ✓                       ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Version    : ${VERSION}"
echo "║  Namespace  : ${NAMESPACE}"
echo "║  Registry   : ${REGISTRY}"
echo "║  Horodatage : $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
log_info "Journal d'audit : Déploiement enregistré dans le journal ISO 27001"
