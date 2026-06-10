#Requires -Version 5.1
<#
.SYNOPSIS
    HERMES CHU - Demarrage de l'API CHU (Privacy Engine + Configuration)
.DESCRIPTION
    Lance le serveur FastAPI CHU sur le port configure (defaut 8001).
    Peut etre execute manuellement ou comme service Windows via NSSM.
.PARAMETER InstallDir
    Repertoire d'installation de HERMES CHU
.PARAMETER Port
    Port de l'API CHU (defaut : 8001)
.PARAMETER Mode
    Mode de demarrage : "foreground" (terminal) ou "background" (service)
#>

[CmdletBinding()]
param(
    [string]$InstallDir = $env:HERMES_CHU_HOME,
    [int]$Port = 8001,
    [ValidateSet("foreground", "background")]
    [string]$Mode = "foreground"
)

$ErrorActionPreference = "Stop"

# Resoudre le repertoire d'installation
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
        Write-Host " Configuration chargee : $Path" -ForegroundColor Green
    } else {
        Write-Host "  Fichier .env.chu introuvable - utilisation des valeurs par defaut" -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# Verifier que l'API n'est pas deja en cours
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
# Demarrage principal
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "+==========================================================+" -ForegroundColor Blue
Write-Host "|         HERMES CHU - Demarrage de l'API CHU              |" -ForegroundColor Blue
Write-Host "+==========================================================+" -ForegroundColor Blue
Write-Host ""

# Charger la configuration
Import-EnvFile -Path $EnvFile

# Verifier si deja en cours
if (Test-ApiRunning) {
    Write-Host "  L'API CHU est deja en cours d'execution sur le port $Port" -ForegroundColor Cyan
    Write-Host "    http://localhost:$Port/docs" -ForegroundColor Gray
    exit 0
}

# Verifier Python
$pythonCmd = if (Get-Command "python" -ErrorAction SilentlyContinue) { "python" }
             elseif (Get-Command "python3" -ErrorAction SilentlyContinue) { "python3" }
             else {
                 Write-Host " Python introuvable. Executez Install-Prerequisites.ps1 d'abord." -ForegroundColor Red
                 exit 1
             }

# Verifier le script API
if (-not (Test-Path $ApiScript)) {
    Write-Host " Script API introuvable : $ApiScript" -ForegroundColor Red
    Write-Host "   Verifiez que HERMES CHU est correctement installe." -ForegroundColor Yellow
    exit 1
}

# Creer le dossier de logs
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

$logFile = "$LogDir\api-chu-$(Get-Date -Format 'yyyy-MM-dd').log"

Write-Host " Demarrage de l'API CHU" -ForegroundColor Cyan
Write-Host "   Port    : $Port" -ForegroundColor Gray
Write-Host "   Journal : $logFile" -ForegroundColor Gray
Write-Host "   Mode    : $Mode" -ForegroundColor Gray
Write-Host ""

if ($Mode -eq "background") {
    # Demarrage en arriere-plan
    $process = Start-Process -FilePath $pythonCmd `
        -ArgumentList "-m uvicorn chu.api.serveur_chu:app --host 127.0.0.1 --port $Port --log-level info" `
        -WorkingDirectory $InstallDir `
        -RedirectStandardOutput $logFile `
        -RedirectStandardError "$LogDir\api-chu-error.log" `
        -WindowStyle Hidden `
        -PassThru

    $process.Id | Out-File -FilePath $PidFile -Encoding UTF8
    Write-Host " API CHU demarree en arriere-plan (PID : $($process.Id))" -ForegroundColor Green
    Write-Host "    http://localhost:$Port/docs" -ForegroundColor Cyan

    # Attendre que l'API reponde
    $maxWait = 15
    $waited  = 0
    Write-Host "   Attente de la disponibilite" -ForegroundColor Gray -NoNewline
    while (-not (Test-ApiRunning) -and $waited -lt $maxWait) {
        Start-Sleep -Seconds 1
        $waited++
        Write-Host "." -ForegroundColor Gray -NoNewline
    }
    Write-Host ""

    if (Test-ApiRunning) {
        Write-Host " API CHU operationnelle !" -ForegroundColor Green
    } else {
        Write-Host "  L'API n'a pas repondu dans les $maxWait secondes - verifiez $logFile" -ForegroundColor Yellow
    }
} else {
    # Demarrage au premier plan (terminal visible)
    Write-Host "  Appuyez sur Ctrl+C pour arreter l'API CHU" -ForegroundColor Yellow
    Write-Host ""
    & $pythonCmd -m uvicorn chu.api.serveur_chu:app `
        --host 127.0.0.1 `
        --port $Port `
        --log-level info `
        --reload
}
