# =============================================================================
# Patch-PULSAR-Asar.ps1
# PULSAR CHU — DSIO CHU de Guyane
# Patche le Hermes Desktop installé pour remplacer l'identité Hermes/NousResearch
# par PULSAR / DSIO CHU de Guyane, sans recompiler le binaire Electron.
#
# Usage : Clic droit → Exécuter avec PowerShell
#         ou : powershell -ExecutionPolicy Bypass -File Patch-PULSAR-Asar.ps1
# =============================================================================

$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "PULSAR CHU — Patch Asar Desktop"

# ─── Couleurs console ────────────────────────────────────────────────────────
function Write-Step  { param($msg) Write-Host "  → $msg" -ForegroundColor Cyan }
function Write-OK    { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "  [!]  $msg" -ForegroundColor Yellow }
function Write-Fail  { param($msg) Write-Host "  [X]  $msg" -ForegroundColor Red }

# ─── Bannière ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "  ║       PULSAR CHU — Patch Identité Desktop v2.3.0        ║" -ForegroundColor Blue
Write-Host "  ║       DSIO - CHU de Guyane  |  William MERI              ║" -ForegroundColor Blue
Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""

# ─── Localiser l'installation Hermes Desktop ─────────────────────────────────
$possiblePaths = @(
    "$env:LOCALAPPDATA\hermes\hermes-agent\apps\desktop\release\win-unpacked",
    "$env:LOCALAPPDATA\hermes\apps\desktop\release\win-unpacked",
    "$env:LOCALAPPDATA\Programs\hermes\resources",
    "$env:APPDATA\hermes\apps\desktop\release\win-unpacked",
    "$env:LOCALAPPDATA\hermes-agent\apps\desktop\release\win-unpacked"
)

$desktopRoot = $null
foreach ($p in $possiblePaths) {
    if (Test-Path "$p\resources\app.asar") {
        $desktopRoot = $p
        break
    }
    if (Test-Path "$p\app.asar") {
        $desktopRoot = $p
        break
    }
}

if (-not $desktopRoot) {
    # Recherche étendue
    Write-Step "Recherche de app.asar dans %LOCALAPPDATA%..."
    $found = Get-ChildItem -Path $env:LOCALAPPDATA -Filter "app.asar" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        $desktopRoot = $found.DirectoryName
    }
}

if (-not $desktopRoot) {
    Write-Fail "Hermes Desktop introuvable. Vérifiez que Hermes Desktop est installé."
    Write-Host ""
    Write-Host "  Chemins recherchés :" -ForegroundColor Gray
    $possiblePaths | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    Read-Host "`n  Appuyez sur Entrée pour quitter"
    exit 1
}

# Localiser app.asar
$asarPath = if (Test-Path "$desktopRoot\resources\app.asar") {
    "$desktopRoot\resources\app.asar"
} elseif (Test-Path "$desktopRoot\app.asar") {
    "$desktopRoot\app.asar"
} else {
    $null
}

if (-not $asarPath) {
    Write-Fail "app.asar introuvable dans : $desktopRoot"
    Read-Host "`n  Appuyez sur Entrée pour quitter"
    exit 1
}

Write-OK "Hermes Desktop trouvé : $desktopRoot"
Write-OK "app.asar : $asarPath"
Write-Host ""

# ─── Vérifier Node.js et @electron/asar ──────────────────────────────────────
Write-Step "Vérification de Node.js..."
try {
    $nodeVer = node --version 2>&1
    Write-OK "Node.js $nodeVer"
} catch {
    Write-Fail "Node.js introuvable. Installez Node.js depuis https://nodejs.org"
    Read-Host "`n  Appuyez sur Entrée pour quitter"
    exit 1
}

Write-Step "Vérification de @electron/asar..."
$asarCmd = $null
try {
    $asarCmd = (Get-Command asar -ErrorAction SilentlyContinue)?.Source
    if (-not $asarCmd) {
        # Chercher dans npx
        $null = npx @electron/asar --version 2>&1
        $asarCmd = "npx @electron/asar"
    }
} catch {}

if (-not $asarCmd) {
    Write-Step "Installation de @electron/asar..."
    npm install -g @electron/asar 2>&1 | Out-Null
    $asarCmd = "asar"
}
Write-OK "@electron/asar disponible"

# ─── Sauvegarde ──────────────────────────────────────────────────────────────
$backupPath = "$asarPath.bak_hermes_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Write-Step "Sauvegarde de app.asar → $backupPath"
Copy-Item $asarPath $backupPath -Force
Write-OK "Sauvegarde créée"

# ─── Extraction ──────────────────────────────────────────────────────────────
$extractDir = "$env:TEMP\pulsar-asar-patch-$(Get-Random)"
Write-Step "Extraction de app.asar vers $extractDir..."

if ($asarCmd -eq "npx @electron/asar") {
    npx @electron/asar extract $asarPath $extractDir 2>&1 | Out-Null
} else {
    & $asarCmd extract $asarPath $extractDir 2>&1 | Out-Null
}

if (-not (Test-Path $extractDir)) {
    Write-Fail "Échec de l'extraction de app.asar"
    Read-Host "`n  Appuyez sur Entrée pour quitter"
    exit 1
}
Write-OK "Extraction réussie"

# ─── Dictionnaire de remplacement ────────────────────────────────────────────
$replacements = [ordered]@{
    # Identité principale
    "Hermes Desktop"                          = "PULSAR Desktop"
    "Hermes Agent"                            = "PULSAR"
    "Hermes agent"                            = "PULSAR"
    "hermes agent"                            = "PULSAR"
    # Titres et labels
    "HERMES AGENT"                            = "PULSAR"
    "Hermes is thinking"                      = "PULSAR réfléchit"
    "Hermes is loading a response"            = "PULSAR charge une réponse"
    "Hermes reported an error"                = "PULSAR a signalé une erreur"
    "Hermes error"                            = "Erreur PULSAR"
    "Hermes couldn"                           = "PULSAR n"
    "Starting Hermes Desktop"                 = "Démarrage de PULSAR"
    "Starting Hermes..."                      = "Démarrage de PULSAR..."
    "Hermes Desktop is ready"                 = "PULSAR est prêt"
    "Hermes background process exited"        = "Le processus PULSAR s'est arrêté"
    "Hermes backend did not become ready"     = "Le moteur PULSAR n'a pas démarré"
    "Hermes gateway connection closed"        = "Connexion PULSAR fermée"
    "Hermes gateway is not connected"         = "PULSAR n'est pas connecté"
    "Hermes checks for updates"               = "PULSAR vérifie les mises à jour"
    "Update Hermes"                           = "Mettre à jour PULSAR"
    "Uninstall Hermes"                        = "Désinstaller PULSAR"
    "About Hermes Desktop"                    = "À propos de PULSAR"
    "Hermes Desktop will reconnect"           = "PULSAR va se reconnecter"
    "restarting Hermes Desktop"               = "redémarrant PULSAR"
    "Waiting to start Hermes backend"         = "Démarrage du moteur PULSAR"
    "Launching packaged Hermes Desktop"       = "Lancement de PULSAR Desktop"
    # Auteur / organisation
    "Nous Research"                           = "DSIO - CHU de Guyane"
    "NousResearch"                            = "DSIO-CHU-Guyane"
    "nousresearch.com"                        = "chu-guyane.fr"
    "portal.nousresearch.com"                 = "github.com/Tarzzan/PULSAR-CHU"
    # URLs GitHub
    "github.com/NousResearch/hermes-agent"    = "github.com/Tarzzan/PULSAR-CHU"
    "github.com/NousResearch/hermes-desktop"  = "github.com/Tarzzan/PULSAR-CHU"
    "NousResearch/hermes-agent"               = "Tarzzan/PULSAR-CHU"
    # APP_NAME dans main.cjs
    "const APP_NAME = 'Hermes'"               = "const APP_NAME = 'PULSAR'"
    '"productName": "Hermes"'                 = '"productName": "PULSAR"'
    '"name": "hermes"'                        = '"name": "pulsar-chu"'
    '"appId": "com.nousresearch.hermes"'      = '"appId": "fr.chu-guyane.pulsar"'
    '"author": "Nous Research"'               = '"author": "DSIO - CHU de Guyane"'
    '"description": "Native desktop shell for Hermes Agent."' = '"description": "PULSAR — Systeme Agentique Medical DSIO CHU de Guyane"'
}

# ─── Patch des fichiers texte ─────────────────────────────────────────────────
Write-Step "Patch des fichiers texte..."
$extensions = @("*.js", "*.cjs", "*.mjs", "*.html", "*.json", "*.css", "*.ts")
$patchedCount = 0

$files = Get-ChildItem -Path $extractDir -Recurse -Include $extensions -File -ErrorAction SilentlyContinue
foreach ($file in $files) {
    try {
        $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
        $original = $content
        foreach ($pair in $replacements.GetEnumerator()) {
            $content = $content.Replace($pair.Key, $pair.Value)
        }
        if ($content -ne $original) {
            [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.Encoding]::UTF8)
            $patchedCount++
        }
    } catch {
        # Ignorer les fichiers binaires
    }
}
Write-OK "$patchedCount fichier(s) patché(s)"

# ─── Remplacer l'icône si disponible ─────────────────────────────────────────
$iconSrc = "$PSScriptRoot\pulsar.ico"
if (-not (Test-Path $iconSrc)) {
    # Chercher dans le dossier assets relatif
    $iconSrc = Join-Path (Split-Path $PSScriptRoot -Parent) "assets\pulsar.ico"
}

if (Test-Path $iconSrc) {
    Write-Step "Remplacement de l'icône..."
    $iconTargets = @(
        "$extractDir\resources\app.ico",
        "$extractDir\resources\icon.ico",
        "$extractDir\build\icon.ico"
    )
    foreach ($t in $iconTargets) {
        if (Test-Path $t) {
            Copy-Item $iconSrc $t -Force
            Write-OK "Icône remplacée : $t"
        }
    }
    # Remplacer aussi l'icône dans le dossier resources de l'app
    $appIco = "$desktopRoot\resources\app.ico"
    if (Test-Path $appIco) {
        Copy-Item $iconSrc $appIco -Force
        Write-OK "Icône principale remplacée"
    }
} else {
    Write-Warn "Icône PULSAR non trouvée ($iconSrc) — icône originale conservée"
}

# ─── Repackage ───────────────────────────────────────────────────────────────
Write-Step "Repackage de app.asar..."

if ($asarCmd -eq "npx @electron/asar") {
    npx @electron/asar pack $extractDir $asarPath 2>&1 | Out-Null
} else {
    & $asarCmd pack $extractDir $asarPath 2>&1 | Out-Null
}

if (-not (Test-Path $asarPath)) {
    Write-Fail "Échec du repackage. Restauration de la sauvegarde..."
    Copy-Item $backupPath $asarPath -Force
    Read-Host "`n  Appuyez sur Entrée pour quitter"
    exit 1
}
Write-OK "app.asar repackagé avec succès"

# ─── Nettoyage ───────────────────────────────────────────────────────────────
Write-Step "Nettoyage des fichiers temporaires..."
Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
Write-OK "Nettoyage terminé"

# ─── Résultat ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║          PULSAR Desktop patché avec succès !             ║" -ForegroundColor Green
Write-Host "  ║                                                          ║" -ForegroundColor Green
Write-Host "  ║  Relancez Hermes Desktop — il affichera PULSAR.         ║" -ForegroundColor Green
Write-Host "  ║  Sauvegarde : $($backupPath | Split-Path -Leaf)" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

$launch = Read-Host "  Lancer PULSAR Desktop maintenant ? (O/N)"
if ($launch -match "^[Oo]") {
    $exePaths = @(
        "$desktopRoot\Hermes.exe",
        "$desktopRoot\PULSAR.exe",
        "$desktopRoot\hermes.exe"
    )
    foreach ($exe in $exePaths) {
        if (Test-Path $exe) {
            Start-Process $exe
            break
        }
    }
}
