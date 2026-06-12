# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 William MERI — DSIO, CHU de Guyane
# ============================================================
#  Apply-PULSAR-Light.ps1
#  Installe le theme PULSAR Light (jour, sobre, hospitalier)
#  DSIO - CHU de Guyane | William MERI
#  Version 1.0.0
# ============================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Header {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  PULSAR Light -- Theme Jour" -ForegroundColor Cyan
    Write-Host "  Sobre, clair, hospitalier, rassurant" -ForegroundColor Cyan
    Write-Host "  DSIO -- CHU de Guyane | William MERI" -ForegroundColor DarkCyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step { param([string]$msg) Write-Host "[>>] $msg" -ForegroundColor Cyan }
function Write-OK   { param([string]$msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn { param([string]$msg) Write-Host "[!!] $msg" -ForegroundColor Yellow }

$HermesHome = Join-Path $env:LOCALAPPDATA "hermes"
$SkinsDir   = Join-Path $HermesHome "skins"
$ThemesDir  = Join-Path $HermesHome "dashboard-themes"
$AssetsDir  = Join-Path $HermesHome "pulsar-light-assets"
$ConfigFile = Join-Path $HermesHome "config.yaml"

$BASE_CDN = "https://raw.githubusercontent.com/Tarzzan/PULSAR-CHU/main/chu/branding/pulsar-light"

$Assets = @{
    "pulsar-light-theme.yaml"        = "$BASE_CDN/pulsar-light-theme.yaml"
    "pulsar-light-skin.yaml"         = "$BASE_CDN/pulsar-light-skin.yaml"
    "bg-pulsar-light-main.jpg"       = "https://files.manuscdn.com/user_upload_by_module/session_file/92503813/BqacOZMBRgTDlMur.jpg"
    "bg-pulsar-light-sidebar.jpg"    = "https://files.manuscdn.com/user_upload_by_module/session_file/92503813/OSfaUfDFfXWxLHLi.jpg"
    "logo-pulsar-light-icon.png"     = "https://files.manuscdn.com/user_upload_by_module/session_file/92503813/SdncNYjBufzocSVS.png"
    "logo-pulsar-light-wordmark.png" = "https://files.manuscdn.com/user_upload_by_module/session_file/92503813/gFuQuRsKxozzbaLX.png"
}

Write-Header

# Creer les dossiers
Write-Step "Creation des dossiers..."
foreach ($dir in @($SkinsDir, $ThemesDir, $AssetsDir)) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}
Write-OK "Dossiers prets"

# Telecharger les assets
Write-Step "Telechargement des assets PULSAR Light..."
foreach ($file in $Assets.Keys) {
    $dest = Join-Path $AssetsDir $file
    try {
        Invoke-WebRequest -Uri $Assets[$file] -OutFile $dest -UseBasicParsing
        Write-OK "Telecharge : $file"
    } catch {
        Write-Warn "Echec : $file"
    }
}

# Installer le theme dashboard
Write-Step "Installation du theme dashboard PULSAR Light..."
$src  = Join-Path $AssetsDir "pulsar-light-theme.yaml"
$dest = Join-Path $ThemesDir "pulsar-light.yaml"
if (Test-Path $src) {
    Copy-Item $src $dest -Force
    Write-OK "Theme installe : $dest"
}

# Installer le skin CLI
Write-Step "Installation du skin CLI PULSAR Light..."
$src  = Join-Path $AssetsDir "pulsar-light-skin.yaml"
$dest = Join-Path $SkinsDir "pulsar-light.yaml"
if (Test-Path $src) {
    Copy-Item $src $dest -Force
    Write-OK "Skin installe : $dest"
}

# Mettre a jour config.yaml
Write-Step "Activation du theme PULSAR Light dans config.yaml..."
if (Test-Path $ConfigFile) {
    $config = Get-Content $ConfigFile -Raw -Encoding UTF8

    if ($config -match "(?m)^(\s*theme:\s*)(\S+)") {
        $config = $config -replace "(?m)^(\s*theme:\s*)(\S+)", "`${1}pulsar-light"
    } else {
        if ($config -match "(?m)^dashboard:") {
            $config = $config -replace "(?m)^(dashboard:)", "`$1`n  theme: pulsar-light"
        } else {
            $config += "`ndashboard:`n  theme: pulsar-light`n"
        }
    }

    if ($config -match "(?m)^(\s*skin:\s*)(\S+)") {
        $config = $config -replace "(?m)^(\s*skin:\s*)(\S+)", "`${1}pulsar-light"
    } else {
        if ($config -match "(?m)^display:") {
            $config = $config -replace "(?m)^(display:)", "`$1`n  skin: pulsar-light"
        } else {
            $config += "`ndisplay:`n  skin: pulsar-light`n"
        }
    }

    $config | Out-File -FilePath $ConfigFile -Encoding UTF8 -NoNewline
    Write-OK "config.yaml mis a jour : theme pulsar-light actif"
} else {
    @"
dashboard:
  theme: pulsar-light
display:
  skin: pulsar-light
"@ | Out-File -FilePath $ConfigFile -Encoding UTF8
    Write-OK "config.yaml cree avec theme PULSAR Light"
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  PULSAR Light installe avec succes !" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Theme : Blanc medical, bleu ciel, teal doux" -ForegroundColor Cyan
Write-Host "  Fond  : Atrium hospitalier + jardin tropical guyanais" -ForegroundColor Cyan
Write-Host "  Mode  : Jour, sobre, lisible, rassurant" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Relancez PULSAR : hermes dashboard" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Pour revenir au theme sombre (nuit) :" -ForegroundColor DarkCyan
Write-Host "  Remplacez 'pulsar-light' par 'pulsar' dans config.yaml" -ForegroundColor White
Write-Host "  Fichier : $ConfigFile" -ForegroundColor Gray
Write-Host ""
