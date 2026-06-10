#Requires -Version 5.1
<#
.SYNOPSIS
    HERMES CHU — Démarrage de l'API CHU (Privacy Engine + Configuration)
.DESCRIPTION
    Lance le serveur FastAPI CHU sur le port configuré (défaut 8001).
    Peut être exécuté manuellement ou comme service Windows via NSSM.
.PARAMETER InstallDir
    Répertoire d'installation de HERMES CHU
.PARAMETER Port
    Port de l'API CHU (défaut : 8001)
.PARAMETER Mode
    Mode de démarrage : "foreground" (terminal) ou "background" (service)
#>

[CmdletBinding()]
param(
    [string]$InstallDir = $env:HERMES_CHU_HOME,
    [int]$Port = 8001,
    [ValidateSet("foreground", "background")]
    [string]$Mode = "foreground"
)

$ErrorActionPreference = "Stop"

# Résoudre le répertoire d'installation
if (-not $InstallDir) {
    $InstallDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

$EnvFile   = "$InstallDir\chu\.env.chu"
$ApiScript = "$InstallDir\chu\api\serveur_chu.py"
$LogDir    = "$InstallDir\chu\logs"
$PidFile   = "$InstallDir\chu\api.pid"

# ---------------------------------------------------------------------------
# Charger la configuration depuis .env.chu
# ---------------------------------------------------------------------------
function Import-EnvFile {
    param([string]$Path)
    if (Test-Path $Path) {
        Get-Content $Path | Where-Object { $_ -match '^\s*[^#]' -and $_ -match '=' } | ForEach-Object {
            $parts = $_ -split '=', 2
            $key   = $parts[0].Trim()
            $value = $parts[1].Trim().Trim('"').Trim("'")
            [System.Environment]::SetEnvironmentVariable($key, $value, "Process")
        }
        Write-Host "✅ Configuration chargée : $Path" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Fichier .env.chu introuvable — utilisation des valeurs par défaut" -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# Vérifier que l'API n'est pas déjà en cours
# ---------------------------------------------------------------------------
function Test-ApiRunning {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$Port/api/chu/sante" `
            -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
}

# ---------------------------------------------------------------------------
# Démarrage principal
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║         HERMES CHU — Démarrage de l'API CHU              ║" -ForegroundColor Blue
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""

# Charger la configuration
Import-EnvFile -Path $EnvFile

# Vérifier si déjà en cours
if (Test-ApiRunning) {
    Write-Host "ℹ️  L'API CHU est déjà en cours d'exécution sur le port $Port" -ForegroundColor Cyan
    Write-Host "   → http://localhost:$Port/docs" -ForegroundColor Gray
    exit 0
}

# Vérifier Python
$pythonCmd = if (Get-Command "python" -ErrorAction SilentlyContinue) { "python" }
             elseif (Get-Command "python3" -ErrorAction SilentlyContinue) { "python3" }
             else {
                 Write-Host "❌ Python introuvable. Exécutez Install-Prerequisites.ps1 d'abord." -ForegroundColor Red
                 exit 1
             }

# Vérifier le script API
if (-not (Test-Path $ApiScript)) {
    Write-Host "❌ Script API introuvable : $ApiScript" -ForegroundColor Red
    Write-Host "   Vérifiez que HERMES CHU est correctement installé." -ForegroundColor Yellow
    exit 1
}

# Créer le dossier de logs
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

$logFile = "$LogDir\api-chu-$(Get-Date -Format 'yyyy-MM-dd').log"

Write-Host "🔧 Démarrage de l'API CHU…" -ForegroundColor Cyan
Write-Host "   Port    : $Port" -ForegroundColor Gray
Write-Host "   Journal : $logFile" -ForegroundColor Gray
Write-Host "   Mode    : $Mode" -ForegroundColor Gray
Write-Host ""

if ($Mode -eq "background") {
    # Démarrage en arrière-plan
    $process = Start-Process -FilePath $pythonCmd `
        -ArgumentList "-m uvicorn chu.api.serveur_chu:app --host 127.0.0.1 --port $Port --log-level info" `
        -WorkingDirectory $InstallDir `
        -RedirectStandardOutput $logFile `
        -RedirectStandardError "$LogDir\api-chu-error.log" `
        -WindowStyle Hidden `
        -PassThru

    $process.Id | Out-File -FilePath $PidFile -Encoding UTF8
    Write-Host "✅ API CHU démarrée en arrière-plan (PID : $($process.Id))" -ForegroundColor Green
    Write-Host "   → http://localhost:$Port/docs" -ForegroundColor Cyan

    # Attendre que l'API réponde
    $maxWait = 15
    $waited  = 0
    Write-Host "   Attente de la disponibilité…" -ForegroundColor Gray -NoNewline
    while (-not (Test-ApiRunning) -and $waited -lt $maxWait) {
        Start-Sleep -Seconds 1
        $waited++
        Write-Host "." -ForegroundColor Gray -NoNewline
    }
    Write-Host ""

    if (Test-ApiRunning) {
        Write-Host "✅ API CHU opérationnelle !" -ForegroundColor Green
    } else {
        Write-Host "⚠️  L'API n'a pas répondu dans les $maxWait secondes — vérifiez $logFile" -ForegroundColor Yellow
    }
} else {
    # Démarrage au premier plan (terminal visible)
    Write-Host "▶  Appuyez sur Ctrl+C pour arrêter l'API CHU" -ForegroundColor Yellow
    Write-Host ""
    & $pythonCmd -m uvicorn chu.api.serveur_chu:app `
        --host 127.0.0.1 `
        --port $Port `
        --log-level info `
        --reload
}
