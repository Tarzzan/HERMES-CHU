# HERMES CHU — Installateur Windows

> Installateur complet pour Windows 10/11 (64 bits) du système agentique hospitalier HERMES CHU.

---

## Contenu du dossier

| Fichier | Description |
|---------|-------------|
| `HERMES-CHU-Setup-1.0.0.exe` | Installateur principal (généré par `makensis`) |
| `nsis/HERMES-CHU-Setup.nsi` | Script NSIS source de l'installateur |
| `scripts/Install-Prerequisites.ps1` | Installation automatique de Node.js, Python, Git |
| `scripts/Configure-CHU.ps1` | Assistant de configuration (premier démarrage) |
| `scripts/Start-API-CHU.ps1` | Démarrage de l'API CHU (Privacy Engine) |
| `assets/` | Icônes, bitmaps et licence pour l'installateur |

---

## Prérequis pour compiler l'installateur

```
NSIS 3.09+          https://nsis.sourceforge.io/Download
Plugin inetc        https://nsis.sourceforge.io/Inetc_plug-in
Plugin nsProcess    https://nsis.sourceforge.io/NsProcess_plugin
Plugin nsDialogs    (inclus dans NSIS)
```

### Compilation

```bat
cd installer\windows\nsis
makensis HERMES-CHU-Setup.nsi
```

L'exécutable `HERMES-CHU-Setup-1.0.0.exe` est généré dans `installer\windows\`.

---

## Utilisation de l'installateur

### Installation standard (recommandée)

1. Double-cliquer sur `HERMES-CHU-Setup-1.0.0.exe`
2. Accepter l'élévation UAC (droits administrateur requis)
3. Suivre l'assistant :
   - **Page Prérequis** : vérification automatique de Node.js, Python, Git
   - **Page Configuration CHU** : saisir l'endpoint Azure OpenAI et la clé API
   - **Page Répertoire** : choisir le dossier d'installation
   - **Installation** : copie des fichiers + configuration automatique
4. À la fin, lancer HERMES CHU depuis le bureau ou le menu Démarrer

### Installation silencieuse (déploiement DSI)

```bat
HERMES-CHU-Setup-1.0.0.exe /S /D=C:\HERMES-CHU
```

### Installation avec configuration Azure pré-renseignée

```bat
HERMES-CHU-Setup-1.0.0.exe /S /AZURE_ENDPOINT=https://chu.openai.azure.com/ /AZURE_KEY=sk-xxx
```

---

## Scripts PowerShell autonomes

Ces scripts peuvent être utilisés indépendamment de l'installateur NSIS.

### Installer les prérequis

```powershell
# En tant qu'Administrateur
Set-ExecutionPolicy Bypass -Scope Process
.\scripts\Install-Prerequisites.ps1
```

Options disponibles :

| Paramètre | Description |
|-----------|-------------|
| `-InstallDir` | Répertoire d'installation (défaut : `C:\Program Files\HERMES CHU`) |
| `-SkipNodejs` | Ne pas installer Node.js |
| `-SkipPython` | Ne pas installer Python |
| `-SkipNlpModel` | Ne pas télécharger le modèle NLP (560 Mo) |
| `-Quiet` | Mode silencieux |

### Configurer HERMES CHU (premier démarrage)

```powershell
.\scripts\Configure-CHU.ps1
```

L'assistant guide la configuration de :
- Le fournisseur LLM (Azure OpenAI, OpenAI, Ollama, vLLM)
- Le Privacy Engine RGPD (activation/désactivation)
- Le port de l'API CHU
- Le service Windows (optionnel)

### Démarrer l'API CHU

```powershell
# Mode terminal (visible)
.\scripts\Start-API-CHU.ps1

# Mode arrière-plan
.\scripts\Start-API-CHU.ps1 -Mode background

# Port personnalisé
.\scripts\Start-API-CHU.ps1 -Port 9001
```

---

## Après installation

| Action | Commande / Raccourci |
|--------|---------------------|
| Lancer HERMES CHU | Raccourci Bureau ou `C:\Program Files\HERMES CHU\hermes-chu.exe` |
| Démarrer l'API CHU | Menu Démarrer → HERMES CHU → Démarrer l'API CHU |
| Configurer les LLM | Interface HERMES CHU → Paramètres → Fournisseurs IA |
| Consulter les logs | `C:\Program Files\HERMES CHU\chu\logs\` |
| Modifier la config | `C:\Program Files\HERMES CHU\chu\.env.chu` |
| Documentation | [Wiki GitHub](https://github.com/Tarzzan/PULSAR-CHU/wiki) |

---

## Désinstallation

**Via le Panneau de configuration** : Programmes → HERMES CHU → Désinstaller

**Silencieuse** :
```bat
"C:\Program Files\HERMES CHU\Uninstall.exe" /S
```

> Les données utilisateur (`logs`, `.env.chu`) sont conservées dans `%APPDATA%\HERMES-CHU` après désinstallation.

---

## Conformité et sécurité

- L'installateur ne collecte aucune donnée télémétriquement.
- Les clés API sont stockées localement dans `.env.chu` (non chiffrées — sécurisez l'accès au poste).
- Pour un déploiement en production, utilisez Windows DPAPI ou un coffre-fort (Azure Key Vault).
- Conforme aux exigences de déploiement ISO 27001 (journalisation, séparation des rôles).
