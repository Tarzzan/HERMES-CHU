# ============================================================
#  Apply-PULSAR-Identity.ps1
#  Installe l'identite visuelle complete PULSAR
#  DSIO - CHU de Guyane | William MERI
#  Version 1.0.0
# ============================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ── Couleurs console ─────────────────────────────────────────
function Write-Header {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  PULSAR -- Identite Visuelle" -ForegroundColor Cyan
    Write-Host "  Plateforme Unifiee de Liaison, de Surveillance" -ForegroundColor Cyan
    Write-Host "  et d'Assistance en temps Reel" -ForegroundColor Cyan
    Write-Host "  DSIO -- CHU de Guyane | William MERI" -ForegroundColor DarkCyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step { param([string]$msg) Write-Host "[>>] $msg" -ForegroundColor Cyan }
function Write-OK   { param([string]$msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn { param([string]$msg) Write-Host "[!!] $msg" -ForegroundColor Yellow }
function Write-Fail { param([string]$msg) Write-Host "[XX] $msg" -ForegroundColor Red }

# ── Chemins ──────────────────────────────────────────────────
$HermesHome   = Join-Path $env:LOCALAPPDATA "hermes"
$SkinsDir     = Join-Path $HermesHome "skins"
$ThemesDir    = Join-Path $HermesHome "dashboard-themes"
$AssetsDir    = Join-Path $HermesHome "pulsar-assets"
$ConfigFile   = Join-Path $HermesHome "config.yaml"

# ── URLs des assets PULSAR (CDN) ─────────────────────────────
$BASE_CDN = "https://raw.githubusercontent.com/Tarzzan/PULSAR-CHU/main/chu/branding/pulsar-assets"

$Assets = @{
    "pulsar-theme.yaml"        = "$BASE_CDN/pulsar-theme.yaml"
    "pulsar-skin.yaml"         = "$BASE_CDN/pulsar-skin.yaml"
    "bg-pulsar-main.jpg"       = "https://files.manuscdn.com/user_upload_by_module/session_file/92503813/vwRkMpgKaxLVlAAE.jpg"
    "bg-pulsar-sidebar.jpg"    = "https://files.manuscdn.com/user_upload_by_module/session_file/92503813/oceBISFudUvOruRl.jpg"
    "logo-pulsar-icon.png"     = "https://files.manuscdn.com/user_upload_by_module/session_file/92503813/LYiVeVRiRiXDKawh.png"
    "logo-pulsar-wordmark.png" = "https://files.manuscdn.com/user_upload_by_module/session_file/92503813/wZJFpHyWRhIhOTbQ.png"
}

Write-Header

# ── 1. Creer les dossiers ─────────────────────────────────────
Write-Step "Creation des dossiers PULSAR..."
foreach ($dir in @($SkinsDir, $ThemesDir, $AssetsDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-OK "Cree : $dir"
    } else {
        Write-OK "Existe deja : $dir"
    }
}

# ── 2. Telecharger les assets ─────────────────────────────────
Write-Step "Telechargement des assets PULSAR..."
foreach ($file in $Assets.Keys) {
    $url  = $Assets[$file]
    $dest = Join-Path $AssetsDir $file
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
        Write-OK "Telecharge : $file"
    } catch {
        Write-Warn "Echec telechargement : $file (continuer sans)"
    }
}

# ── 3. Installer le theme dashboard ──────────────────────────
Write-Step "Installation du theme dashboard PULSAR..."
$themeSrc  = Join-Path $AssetsDir "pulsar-theme.yaml"
$themeDest = Join-Path $ThemesDir "pulsar.yaml"
if (Test-Path $themeSrc) {
    Copy-Item $themeSrc $themeDest -Force
    Write-OK "Theme dashboard installe : $themeDest"
} else {
    Write-Warn "Fichier theme non trouve, creation inline..."
    # Fallback : theme minimal inline si le fichier n'a pas pu etre telecharge
    $minimalTheme = @"
name: pulsar
label: PULSAR -- CHU de Guyane
description: Identite visuelle officielle PULSAR
palette:
  background:
    hex: "#050f1e"
    alpha: 1.0
  midground:
    hex: "#00d4ff"
    alpha: 1.0
  foreground:
    hex: "#ffffff"
    alpha: 0.0
  warmGlow: "rgba(0, 180, 255, 0.18)"
colorOverrides:
  primary: "#00d4ff"
  primaryForeground: "#050f1e"
  accent: "#00b4d8"
  success: "#00e5a0"
  destructive: "#ff4d6d"
  ring: "#00d4ff"
"@
    $minimalTheme | Out-File -FilePath $themeDest -Encoding UTF8
    Write-OK "Theme minimal cree : $themeDest"
}

# ── 4. Installer le skin CLI ──────────────────────────────────
Write-Step "Installation du skin CLI PULSAR..."
$skinSrc  = Join-Path $AssetsDir "pulsar-skin.yaml"
$skinDest = Join-Path $SkinsDir "pulsar.yaml"
if (Test-Path $skinSrc) {
    Copy-Item $skinSrc $skinDest -Force
    Write-OK "Skin CLI installe : $skinDest"
} else {
    Write-Warn "Fichier skin non trouve, ignoré"
}

# ── 5. Mettre a jour config.yaml ──────────────────────────────
Write-Step "Application du theme PULSAR dans config.yaml..."
if (Test-Path $ConfigFile) {
    $config = Get-Content $ConfigFile -Raw -Encoding UTF8

    # Appliquer le theme dashboard PULSAR
    if ($config -match "(?m)^(\s*theme:\s*)(\S+)") {
        $config = $config -replace "(?m)^(\s*theme:\s*)(\S+)", "`${1}pulsar"
        Write-OK "Theme dashboard mis a jour : pulsar"
    } else {
        # Ajouter la section dashboard si absente
        if ($config -match "(?m)^dashboard:") {
            $config = $config -replace "(?m)^(dashboard:)", "`$1`n  theme: pulsar"
        } else {
            $config += "`ndashboard:`n  theme: pulsar`n"
        }
        Write-OK "Section dashboard ajoutee avec theme: pulsar"
    }

    # Appliquer le skin CLI PULSAR
    if ($config -match "(?m)^(\s*skin:\s*)(\S+)") {
        $config = $config -replace "(?m)^(\s*skin:\s*)(\S+)", "`${1}pulsar"
        Write-OK "Skin CLI mis a jour : pulsar"
    } else {
        if ($config -match "(?m)^display:") {
            $config = $config -replace "(?m)^(display:)", "`$1`n  skin: pulsar"
        } else {
            $config += "`ndisplay:`n  skin: pulsar`n"
        }
        Write-OK "Section display ajoutee avec skin: pulsar"
    }

    $config | Out-File -FilePath $ConfigFile -Encoding UTF8 -NoNewline
    Write-OK "config.yaml mis a jour"
} else {
    Write-Warn "config.yaml non trouve, creation..."
    @"
dashboard:
  theme: pulsar
display:
  skin: pulsar
"@ | Out-File -FilePath $ConfigFile -Encoding UTF8
    Write-OK "config.yaml cree avec theme PULSAR"
}

# ── 6. Patcher les fichiers web_dist (textes visibles) ────────
Write-Step "Recherche des fichiers web compiles hermes..."
$VenvBase = Join-Path $env:LOCALAPPDATA "hermes\hermes-agent\venv"
$WebDist  = $null

# Chercher le dossier web_dist dans le venv
$candidates = @(
    (Join-Path $VenvBase "Lib\site-packages\hermes_cli\web_dist"),
    (Join-Path $VenvBase "Lib\site-packages\hermes\web_dist"),
    (Join-Path $env:LOCALAPPDATA "hermes\web_dist")
)
foreach ($c in $candidates) {
    if (Test-Path $c) { $WebDist = $c; break }
}

if ($WebDist) {
    Write-OK "web_dist trouve : $WebDist"
    Write-Step "Patch des textes NousResearch -> PULSAR dans les JS compiles..."

    $jsFiles = Get-ChildItem -Path $WebDist -Recurse -Include "*.js" -ErrorAction SilentlyContinue
    $patched = 0
    foreach ($f in $jsFiles) {
        $content = Get-Content $f.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($null -eq $content) { continue }
        $original = $content

        # Remplacements textuels
        $content = $content -replace "Nous Research",         "DSIO CHU de Guyane"
        $content = $content -replace "nousresearch\.com",     "github.com/Tarzzan/PULSAR-CHU"
        $content = $content -replace "Messenger of the Digital Gods", "Systeme Agentique Medical"
        $content = $content -replace "Hermes Agent",          "PULSAR"
        $content = $content -replace "HERMES-AGENT",          "PULSAR"
        $content = $content -replace "Hermes Teal",           "PULSAR Medical"
        $content = $content -replace "hermes-agent",          "pulsar"
        $content = $content -replace '"brand":"Hermes Agent"', '"brand":"PULSAR"'
        $content = $content -replace '"brandShort":"HA"',     '"brandShort":"PS"'
        $content = $content -replace "footer\.org.*?Nous Research", 'footer.org":"DSIO CHU de Guyane'

        if ($content -ne $original) {
            $content | Out-File -FilePath $f.FullName -Encoding UTF8 -NoNewline
            $patched++
        }
    }
    Write-OK "$patched fichier(s) JS patche(s)"

    # Patcher index.html (titre de l'onglet)
    $indexHtml = Join-Path $WebDist "index.html"
    if (Test-Path $indexHtml) {
        $html = Get-Content $indexHtml -Raw -Encoding UTF8
        $html = $html -replace "<title>.*?</title>", "<title>PULSAR -- Systeme Agentique Medical | CHU de Guyane</title>"
        $html | Out-File -FilePath $indexHtml -Encoding UTF8 -NoNewline
        Write-OK "Titre de page mis a jour : PULSAR -- Systeme Agentique Medical | CHU de Guyane"
    }
} else {
    Write-Warn "web_dist non trouve -- les textes NousResearch resteront dans le JS compile"
    Write-Warn "Le theme visuel (couleurs, fond, skin CLI) est quand meme actif"
}

# ── 7. Recapitulatif ──────────────────────────────────────────
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  PULSAR -- Installation terminee !" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Theme dashboard : PULSAR (bleu medical, fond immersif)" -ForegroundColor Cyan
Write-Host "  Skin CLI        : PULSAR (banner ASCII, couleurs cyan)" -ForegroundColor Cyan
Write-Host "  Logo            : ECG + etoile pulsar" -ForegroundColor Cyan
Write-Host "  Image de fond   : Centre de commande medical + jungle" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Relancez PULSAR pour voir les changements :" -ForegroundColor Yellow
Write-Host "  > hermes dashboard" -ForegroundColor White
Write-Host ""
Write-Host "  Ou via le raccourci Bureau : PULSAR" -ForegroundColor White
Write-Host ""
