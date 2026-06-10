# HERMES CHU Desktop

> Application Electron native basée sur [hermes-desktop (NousResearch)](https://github.com/NousResearch/hermes-agent), adaptée pour les Centres Hospitaliers Universitaires.

---

## Architecture

```
upstream/hermes-desktop/     ← Code source NousResearch (INCHANGÉ)
chu-desktop/                 ← Patches et extensions CHU (CE DOSSIER)
├── src/
│   ├── i18n/fr.ts           ← Traduction française complète
│   ├── components/
│   │   └── providers-settings-chu.tsx  ← Panneau config LLM (Azure/OpenAI/Ollama/vLLM)
│   ├── app/
│   │   ├── privacy/
│   │   │   └── privacy-panel.tsx       ← Panneau Privacy Engine RGPD + Glass-Break
│   │   └── agents/
│   │       └── chu-agents.tsx          ← Page des 5 agents CHU spécialisés
│   └── app/settings/
│       └── (injection dans settings NousResearch)
├── electron/
│   ├── chu-ipc.cjs          ← Handlers IPC → API CHU (localhost:8001)
│   └── chu-preload.cjs      ← window.hermeschu.* exposé au renderer
└── build-chu-desktop.sh     ← Script de build multi-plateforme
```

---

## Fonctionnalités ajoutées par la couche CHU

| Fonctionnalité | Fichier | Description |
|----------------|---------|-------------|
| **Traduction française** | `src/i18n/fr.ts` | Interface entièrement en français |
| **Sélection LLM** | `src/components/providers-settings-chu.tsx` | Azure OpenAI, OpenAI, Ollama, vLLM |
| **Privacy Engine** | `src/app/privacy/privacy-panel.tsx` | Toggle RGPD + Glass-Break tracé |
| **Agents CHU** | `src/app/agents/chu-agents.tsx` | 5 agents spécialisés avec capacités |
| **IPC sécurisé** | `electron/chu-ipc.cjs` | Communication renderer ↔ API CHU |
| **Preload** | `electron/chu-preload.cjs` | `window.hermeschu.*` API |

---

## Build

```bash
# Mode développement
./chu-desktop/build-chu-desktop.sh --dev

# Package Linux (AppImage + .deb + .rpm)
./chu-desktop/build-chu-desktop.sh --linux

# Package Windows (NSIS + MSI)
./chu-desktop/build-chu-desktop.sh --windows

# Package macOS (DMG + ZIP)
./chu-desktop/build-chu-desktop.sh --mac

# Toutes les plateformes
./chu-desktop/build-chu-desktop.sh --all
```

---

## Intégration dans hermes-desktop

Les fichiers CHU s'intègrent dans hermes-desktop via le **système de plugins/slots natif** de hermes-agent. Les modifications sont **non-destructives** : aucun fichier NousResearch n'est modifié.

**Points d'injection :**

1. `electron/main.cjs` → ajouter `require('./chu-ipc.cjs').registerCHUIpcHandlers()`
2. `electron/preload.cjs` → merger avec `chu-preload.cjs`
3. `src/i18n/index.ts` → ajouter `import { fr } from './fr'`
4. `src/app/settings/index.tsx` → ajouter les onglets Privacy et Agents CHU
5. `src/app/agents/index.tsx` → remplacer par `ChuAgentsPage`

---

## Prérequis système

| Composant | Version |
|-----------|---------|
| Node.js | 22+ |
| Electron | 34+ (via hermes-desktop) |
| API CHU | `./chu/installer_chu.sh --poc` (port 8001) |
| Privacy Engine | Démarré avec l'API CHU |
