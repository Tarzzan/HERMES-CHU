# =============================================================================
# Patch-PULSAR-Asar.ps1
# PULSAR CHU - DSIO CHU de Guyane
# Patche le Hermes Desktop installe pour remplacer l'identite Hermes/NousResearch
# par PULSAR / DSIO CHU de Guyane, sans recompiler le binaire Electron.
#
# Usage : powershell -ExecutionPolicy Bypass -File Patch-PULSAR-Asar.ps1
# =============================================================================

$ErrorActionPreference = "Stop"

function Write-Step { param($msg) Write-Host "  -> $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  [!]  $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "  [X]  $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "  +----------------------------------------------------------+" -ForegroundColor Blue
Write-Host "  |      PULSAR CHU - Patch Identite Desktop v2.3.0         |" -ForegroundColor Blue
Write-Host "  |      DSIO - CHU de Guyane  |  William MERI              |" -ForegroundColor Blue
Write-Host "  +----------------------------------------------------------+" -ForegroundColor Blue
Write-Host ""

# --- Localiser l'installation Hermes Desktop ---------------------------------
$possiblePaths = @(
    "$env:LOCALAPPDATA\hermes\hermes-agent\apps\desktop\release\win-unpacked",
    "$env:LOCALAPPDATA\hermes\apps\desktop\release\win-unpacked",
    "$env:LOCALAPPDATA\Programs\hermes\resources",
    "$env:APPDATA\hermes\apps\desktop\release\win-unpacked",
    "$env:LOCALAPPDATA\hermes-agent\apps\desktop\release\win-unpacked"
)

$desktopRoot = $null
foreach ($p in $possiblePaths) {
    if (Test-Path "$p\resources\app.asar") { $desktopRoot = $p; break }
    if (Test-Path "$p\app.asar")           { $desktopRoot = $p; break }
}

if (-not $desktopRoot) {
    Write-Step "Recherche etendue de app.asar dans %LOCALAPPDATA%..."
    $found = Get-ChildItem -Path $env:LOCALAPPDATA -Filter "app.asar" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $desktopRoot = $found.DirectoryName }
}

if (-not $desktopRoot) {
    Write-Fail "Hermes Desktop introuvable. Verifiez que Hermes Desktop est installe."
    Read-Host "`n  Appuyez sur Entree pour quitter"
    exit 1
}

$asarPath = $null
if (Test-Path "$desktopRoot\resources\app.asar") { $asarPath = "$desktopRoot\resources\app.asar" }
elseif (Test-Path "$desktopRoot\app.asar")       { $asarPath = "$desktopRoot\app.asar" }

if (-not $asarPath) {
    Write-Fail "app.asar introuvable dans : $desktopRoot"
    Read-Host "`n  Appuyez sur Entree pour quitter"
    exit 1
}

Write-OK "Hermes Desktop trouve : $desktopRoot"
Write-OK "app.asar : $asarPath"
Write-Host ""

# --- Verifier Node.js --------------------------------------------------------
Write-Step "Verification de Node.js..."
try {
    $nodeVer = node --version 2>&1
    Write-OK "Node.js $nodeVer"
} catch {
    Write-Fail "Node.js introuvable. Installez Node.js depuis https://nodejs.org"
    Read-Host "`n  Appuyez sur Entree pour quitter"
    exit 1
}

# --- Verifier @electron/asar -------------------------------------------------
Write-Step "Verification de @electron/asar..."
$asarAvailable = $false
try {
    $null = asar --version 2>&1
    $asarAvailable = $true
    Write-OK "asar disponible (global)"
} catch {
    Write-Step "Installation de @electron/asar (npm install -g)..."
    try {
        npm install -g @electron/asar 2>&1 | Out-Null
        $asarAvailable = $true
        Write-OK "@electron/asar installe"
    } catch {
        Write-Warn "Installation globale echouee - utilisation via npx"
        $asarAvailable = $false
    }
}

# --- Sauvegarde --------------------------------------------------------------
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$backupPath = "$asarPath.bak_hermes_$ts"
Write-Step "Sauvegarde de app.asar..."
Copy-Item $asarPath $backupPath -Force
Write-OK "Sauvegarde : $backupPath"

# --- Extraction --------------------------------------------------------------
$extractDir = "$env:TEMP\pulsar-asar-$ts"
Write-Step "Extraction de app.asar..."

if ($asarAvailable) {
    asar extract $asarPath $extractDir 2>&1 | Out-Null
} else {
    npx --yes @electron/asar extract $asarPath $extractDir 2>&1 | Out-Null
}

if (-not (Test-Path $extractDir)) {
    Write-Fail "Echec de l'extraction. Restauration de la sauvegarde..."
    Copy-Item $backupPath $asarPath -Force
    Read-Host "`n  Appuyez sur Entree pour quitter"
    exit 1
}
Write-OK "Extraction reussie dans $extractDir"

# --- Remplacements -----------------------------------------------------------
# IMPORTANT : les cles doivent etre uniques (casse differente = cle differente)
$replacements = @(
    @{ From = "HERMES AGENT";                              To = "PULSAR" },
    @{ From = "Hermes Desktop";                            To = "PULSAR Desktop" },
    @{ From = "Hermes Agent";                              To = "PULSAR" },
    @{ From = "Hermes agent";                              To = "PULSAR" },
    @{ From = "hermes agent";                              To = "PULSAR" },
    @{ From = "Hermes is thinking";                        To = "PULSAR reflechit" },
    @{ From = "Hermes is loading a response";              To = "PULSAR charge une reponse" },
    @{ From = "Hermes reported an error";                  To = "PULSAR a signale une erreur" },
    @{ From = "Hermes error";                              To = "Erreur PULSAR" },
    @{ From = "Starting Hermes Desktop";                   To = "Demarrage de PULSAR" },
    @{ From = "Starting Hermes...";                        To = "Demarrage de PULSAR..." },
    @{ From = "Hermes Desktop is ready";                   To = "PULSAR est pret" },
    @{ From = "Hermes background process exited";          To = "Le processus PULSAR s'est arrete" },
    @{ From = "Hermes backend did not become ready";       To = "Le moteur PULSAR n'a pas demarre" },
    @{ From = "Hermes gateway connection closed";          To = "Connexion PULSAR fermee" },
    @{ From = "Hermes gateway is not connected";           To = "PULSAR n'est pas connecte" },
    @{ From = "Hermes checks for updates";                 To = "PULSAR verifie les mises a jour" },
    @{ From = "Update Hermes";                             To = "Mettre a jour PULSAR" },
    @{ From = "Uninstall Hermes";                          To = "Desinstaller PULSAR" },
    @{ From = "About Hermes Desktop";                      To = "A propos de PULSAR" },
    @{ From = "Hermes Desktop will reconnect";             To = "PULSAR va se reconnecter" },
    @{ From = "restarting Hermes Desktop";                 To = "redemarrant PULSAR" },
    @{ From = "Waiting to start Hermes backend";           To = "Demarrage du moteur PULSAR" },
    @{ From = "Launching packaged Hermes Desktop";         To = "Lancement de PULSAR Desktop" },
    @{ From = "Nous Research";                             To = "DSIO - CHU de Guyane" },
    @{ From = "NousResearch";                              To = "DSIO-CHU-Guyane" },
    @{ From = "nousresearch.com";                          To = "chu-guyane.fr" },
    @{ From = "portal.nousresearch.com";                   To = "github.com/Tarzzan/PULSAR-CHU" },
    @{ From = "github.com/NousResearch/hermes-agent";      To = "github.com/Tarzzan/PULSAR-CHU" },
    @{ From = "github.com/NousResearch/hermes-desktop";    To = "github.com/Tarzzan/PULSAR-CHU" },
    @{ From = "NousResearch/hermes-agent";                 To = "Tarzzan/PULSAR-CHU" },
    @{ From = "const APP_NAME = 'Hermes'";                 To = "const APP_NAME = 'PULSAR'" },
    @{ From = '"productName": "Hermes"';                   To = '"productName": "PULSAR"' },
    @{ From = '"name": "hermes"';                          To = '"name": "pulsar-chu"' },
    @{ From = '"appId": "com.nousresearch.hermes"';        To = '"appId": "fr.chu-guyane.pulsar"' },
    @{ From = '"author": "Nous Research"';                 To = '"author": "DSIO - CHU de Guyane"' }
)

Write-Step "Patch des fichiers texte..."
$extensions = @("*.js", "*.cjs", "*.mjs", "*.html", "*.json", "*.css")
$patchedCount = 0

$files = Get-ChildItem -Path $extractDir -Recurse -Include $extensions -File -ErrorAction SilentlyContinue
foreach ($file in $files) {
    try {
        $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
        $original = $content
        foreach ($r in $replacements) {
            $content = $content.Replace($r.From, $r.To)
        }
        if ($content -ne $original) {
            [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.Encoding]::UTF8)
            $patchedCount++
        }
    } catch { }
}
Write-OK "$patchedCount fichier(s) patche(s)"

# --- Desactiver l'auto-update NousResearch ----------------------------------
Write-Step "Desactivation de l'auto-update NousResearch..."
$updateFiles = Get-ChildItem -Path $extractDir -Recurse -Include "*.js","*.cjs" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "update|autoUpdate|electron-updater" }
foreach ($f in $updateFiles) {
    try {
        $c = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
        # Neutraliser les URLs de mise a jour NousResearch
        $c = $c -replace 'https://[^"''\s]*nousresearch[^"''\s]*', 'https://github.com/Tarzzan/PULSAR-CHU/releases'
        $c = $c -replace 'https://[^"''\s]*hermes-desktop[^"''\s]*releases[^"''\s]*', 'https://github.com/Tarzzan/PULSAR-CHU/releases'
        # Desactiver la verification automatique au demarrage
        $c = $c.Replace('autoUpdater.checkForUpdatesAndNotify()', '/* auto-update disabled */ void 0')
        $c = $c.Replace('autoUpdater.checkForUpdates()', '/* auto-update disabled */ void 0')
        $c = $c.Replace('checkForUpdatesAndNotify()', '/* auto-update disabled */ void 0')
        [System.IO.File]::WriteAllText($f.FullName, $c, [System.Text.Encoding]::UTF8)
    } catch { }
}
Write-OK "Auto-update NousResearch desactive"

# --- Remplacer l'icone si disponible -----------------------------------------
$iconSrc = Join-Path $PSScriptRoot "pulsar.ico"
if (Test-Path $iconSrc) {
    Write-Step "Remplacement de l'icone..."
    $iconTargets = @(
        "$extractDir\resources\app.ico",
        "$extractDir\resources\icon.ico",
        "$extractDir\build\icon.ico",
        "$desktopRoot\resources\app.ico"
    )
    foreach ($t in $iconTargets) {
        if (Test-Path $t) {
            Copy-Item $iconSrc $t -Force
            Write-OK "Icone remplacee : $(Split-Path $t -Leaf)"
        }
    }
} else {
    Write-Warn "pulsar.ico non trouve a cote du script - icone originale conservee"
}

# --- Repackage ---------------------------------------------------------------
Write-Step "Repackage de app.asar..."

if ($asarAvailable) {
    asar pack $extractDir $asarPath 2>&1 | Out-Null
} else {
    npx --yes @electron/asar pack $extractDir $asarPath 2>&1 | Out-Null
}

if (-not (Test-Path $asarPath)) {
    Write-Fail "Echec du repackage. Restauration de la sauvegarde..."
    Copy-Item $backupPath $asarPath -Force
    Read-Host "`n  Appuyez sur Entree pour quitter"
    exit 1
}
Write-OK "app.asar repackage avec succes"

# --- Nettoyage ---------------------------------------------------------------
Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
Write-OK "Fichiers temporaires nettoyes"

# --- Resultat ----------------------------------------------------------------
Write-Host ""
Write-Host "  +----------------------------------------------------------+" -ForegroundColor Green
Write-Host "  |         PULSAR Desktop patche avec succes !              |" -ForegroundColor Green
Write-Host "  |                                                          |" -ForegroundColor Green
Write-Host "  |  Relancez Hermes Desktop - il affichera PULSAR.         |" -ForegroundColor Green
Write-Host "  +----------------------------------------------------------+" -ForegroundColor Green
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
            Write-OK "PULSAR Desktop lance : $exe"
            break
        }
    }
}
