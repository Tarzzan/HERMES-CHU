#!/usr/bin/env bash
# =============================================================================
# HERMES CHU Desktop — Script de Build et Packaging
# =============================================================================
# Construit l'application Electron HERMES CHU Desktop à partir du code source
# NousResearch (upstream/hermes-desktop) en y appliquant les patches CHU.
#
# Usage :
#   ./chu-desktop/build-chu-desktop.sh [--linux | --windows | --mac | --all]
#
# Prérequis :
#   - Node.js 22+
#   - npm
#   - Pour Linux : fpm (gem install fpm) pour les packages .deb/.rpm
#   - Pour Windows : wine (cross-compilation depuis Linux)
#   - Pour macOS : Xcode Command Line Tools
# =============================================================================

set -euo pipefail

CIBLE="${1:---linux}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESKTOP_SRC="$REPO_DIR/upstream/hermes-desktop"
CHU_PATCHES="$REPO_DIR/chu-desktop"
BUILD_DIR="$REPO_DIR/build/hermes-chu-desktop"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║       HERMES CHU Desktop — Build & Packaging             ║"
echo "║       Basé sur hermes-desktop (NousResearch)             ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  Cible    : $CIBLE"
echo "  Source   : $DESKTOP_SRC"
echo "  Patches  : $CHU_PATCHES"
echo "  Build    : $BUILD_DIR"
echo ""

# ---------------------------------------------------------------------------
# 1. Préparer le répertoire de build
# ---------------------------------------------------------------------------
echo "📁 Préparation du répertoire de build…"
rm -rf "$BUILD_DIR"
cp -r "$DESKTOP_SRC/." "$BUILD_DIR/"

# ---------------------------------------------------------------------------
# 2. Appliquer les patches CHU
# ---------------------------------------------------------------------------
echo "🔧 Application des patches CHU…"

# 2a. Copier les fichiers CHU dans le build
cp -r "$CHU_PATCHES/src/." "$BUILD_DIR/src/"
cp -r "$CHU_PATCHES/electron/." "$BUILD_DIR/electron/"

# 2b. Patch package.json : renommer l'app en HERMES CHU
node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('$BUILD_DIR/package.json', 'utf8'));
pkg.name = 'hermes-chu';
pkg.productName = 'HERMES CHU';
pkg.description = 'Système Agentique Hospitalier Souverain — CHU';
pkg.version = '1.0.0';
pkg.author = 'CHU — Basé sur hermes-agent (NousResearch)';
// Configuration electron-builder pour CHU
pkg.build = {
  ...pkg.build,
  appId: 'fr.chu.hermes-chu',
  productName: 'HERMES CHU',
  copyright: 'CHU — Basé sur Hermes Agent (NousResearch) — MIT',
  linux: {
    target: ['AppImage', 'deb', 'rpm'],
    category: 'MedicalSoftware',
    icon: 'assets/icon-chu.png',
    desktop: {
      Name: 'HERMES CHU',
      Comment: 'Système Agentique Hospitalier Souverain',
      Categories: 'MedicalSoftware;Healthcare;'
    }
  },
  win: {
    target: ['nsis', 'msi'],
    icon: 'assets/icon-chu.ico',
    publisherName: 'CHU'
  },
  mac: {
    target: ['dmg', 'zip'],
    icon: 'assets/icon-chu.icns',
    category: 'public.app-category.medical',
    hardenedRuntime: true,
    entitlements: 'electron/entitlements.mac.plist',
    entitlementsInherit: 'electron/entitlements.mac.inherit.plist'
  },
  nsis: {
    oneClick: false,
    allowToChangeInstallationDirectory: true,
    installerIcon: 'assets/icon-chu.ico',
    installerHeaderIcon: 'assets/icon-chu.ico',
    createDesktopShortcut: true,
    createStartMenuShortcut: true,
    shortcutName: 'HERMES CHU'
  }
};
fs.writeFileSync('$BUILD_DIR/package.json', JSON.stringify(pkg, null, 2));
console.log('✅ package.json patché pour HERMES CHU');
"

# 2c. Patch i18n : injecter le français comme langue par défaut
cat > "$BUILD_DIR/src/i18n/chu-fr-inject.ts" << 'INJECT'
// HERMES CHU — Injection de la traduction française
// Ce fichier est généré automatiquement par build-chu-desktop.sh
export { fr } from './fr'
INJECT

echo "✅ Patches CHU appliqués"

# ---------------------------------------------------------------------------
# 3. Installer les dépendances depuis la racine du monorepo NousResearch
# ---------------------------------------------------------------------------
echo "📦 Installation des dépendances…"
cd "$REPO_DIR/upstream/hermes-desktop"
if [ ! -d "node_modules" ]; then
    npm install --workspace apps/desktop 2>/dev/null || npm install
fi
echo "✅ Dépendances installées"

# ---------------------------------------------------------------------------
# 4. Build selon la cible
# ---------------------------------------------------------------------------
echo "🔨 Build de l'application…"
cd "$BUILD_DIR"

# Copier node_modules depuis le source
if [ ! -d "node_modules" ]; then
    ln -s "$DESKTOP_SRC/node_modules" "$BUILD_DIR/node_modules" 2>/dev/null || true
fi

case "$CIBLE" in
  --linux)
    echo "  → Build Linux (AppImage + .deb + .rpm)"
    npm run dist:linux 2>/dev/null || npx electron-builder --linux AppImage deb
    echo "✅ Build Linux terminé → dist/"
    ;;
  --windows)
    echo "  → Build Windows (NSIS + MSI)"
    npm run dist:win 2>/dev/null || npx electron-builder --win nsis msi
    echo "✅ Build Windows terminé → dist/"
    ;;
  --mac)
    echo "  → Build macOS (DMG + ZIP)"
    npm run dist:mac 2>/dev/null || npx electron-builder --mac dmg zip
    echo "✅ Build macOS terminé → dist/"
    ;;
  --all)
    echo "  → Build toutes plateformes"
    npm run dist 2>/dev/null || npx electron-builder --linux --win --mac
    echo "✅ Build multi-plateforme terminé → dist/"
    ;;
  --dev)
    echo "  → Mode développement"
    npm run dev
    ;;
  *)
    echo "Usage: $0 [--linux | --windows | --mac | --all | --dev]"
    exit 1
    ;;
esac

# ---------------------------------------------------------------------------
# 5. Résumé
# ---------------------------------------------------------------------------
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║           HERMES CHU Desktop — Build terminé !           ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Artefacts disponibles dans : build/hermes-chu-desktop/dist/"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
ls -la "$BUILD_DIR/dist/" 2>/dev/null || echo "(Aucun artefact — mode dev ou erreur)"
