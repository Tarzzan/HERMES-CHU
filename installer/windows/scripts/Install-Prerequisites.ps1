#Requires -Version 5.1
<#
.SYNOPSIS
    HERMES CHU - Installation des prerequis Windows
.DESCRIPTION
    Installe et configure automatiquement tous les prerequis necessaires
    au fonctionnement de HERMES CHU Desktop sur Windows 10/11 :
    - Node.js 22 LTS
    - Python 3.11
    - Git
    - Dependances Python (FastAPI, spaCy, Redis, etc.)
    - Modele NLP francais (fr_core_news_lg)
    - Redis Windows (Memurai ou WSL2)
.PARAMETER InstallDir
    Repertoire d'installation de HERMES CHU (defaut : C:\Program Files\HERMES CHU)
.PARAMETER SkipNodejs
    Ignorer l'installation de Node.js
.PARAMETER SkipPython
    Ignorer l'installation de Python
.PARAMETER SkipNlpModel
    Ignorer le telechargement du modele NLP (recommande si connexion lente)
.PARAMETER Quiet
    Mode silencieux (pas d'invite interactive)
.EXAMPLE
    .\Install-Prerequisites.ps1 -InstallDir "C:\HERMES-CHU"
    .\Install-Prerequisites.ps1 -Quiet -SkipNlpModel
#>

[CmdletBinding()]
param(
    [string]$InstallDir = "$env:ProgramFiles\HERMES CHU",
    [switch]$SkipNodejs,
    [switch]$SkipPython,
    [switch]$SkipNlpModel,
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
$Script:Config = @{
    NodeVersion    = "22.13.0"
    NodeUrl        = "https://nodejs.org/dist/v22.13.0/node-v22.13.0-x64.msi"
    PythonVersion  = "3.11.9"
    PythonUrl      = "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe"
    GitUrl         = "https://github.com/git-for-windows/git/releases/download/v2.47.0.windows.1/Git-2.47.0-64-bit.exe"
    MemuraiUrl     = "https://www.memurai.com/get-memurai"
    TempDir        = "$env:TEMP\hermes-chu-install"
    LogFile        = "$env:TEMP\hermes-chu-install.log"
    PythonPackages = @(
        "fastapi>=0.115.0",
        "uvicorn[standard]>=0.32.0",
        "spacy>=3.7.0",
        "redis>=5.0.0",
        "sqlalchemy>=2.0.0",
        "python-jose[cryptography]>=3.3.0",
        "cryptography>=43.0.0",
        "httpx>=0.27.0",
        "pydantic>=2.9.0",
        "python-multipart>=0.0.12",
        "aiofiles>=24.1.0",
        "structlog>=24.4.0"
    )
}

# ---------------------------------------------------------------------------
# Utilitaires
# ---------------------------------------------------------------------------
function Write-CHULog {
    param([string]$Message, [string]$Level = "INFO", [ConsoleColor]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    Add-Content -Path $Script:Config.LogFile -Value $logLine -Encoding UTF8
    $prefix = switch ($Level) {
        "OK"      { "" }
        "WARN"    { " " }
        "ERROR"   { "" }
        "INFO"    { " " }
        "STEP"    { "" }
        default   { "  " }
    }
    Write-Host "$prefix $Message" -ForegroundColor $Color
}

function Test-CommandExists {
    param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Get-VersionNumber {
    param([string]$Command, [string]$Args = "--version")
    try {
        $output = & $Command $Args 2>&1 | Select-Object -First 1
        return ($output -replace '[^\d\.]', '').Trim()
    } catch { return $null }
}

function Invoke-Download {
    param([string]$Url, [string]$Destination, [string]$Description)
    Write-CHULog "Telechargement : $Description" -Level "STEP" -Color Cyan
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "HERMES-CHU-Installer/1.0")
        $webClient.DownloadFile($Url, $Destination)
        Write-CHULog "$Description telecharge" -Level "OK" -Color Green
        return $true
    } catch {
        Write-CHULog "Echec du telechargement : $_" -Level "ERROR" -Color Red
        return $false
    }
}

function Show-Banner {
    Write-Host ""
    Write-Host "+==========================================================+" -ForegroundColor Blue
    Write-Host "|                                                          |" -ForegroundColor Blue
    Write-Host "|         HERMES CHU - Installation des prerequis         |" -ForegroundColor Blue
    Write-Host "|         Systeme Agentique Hospitalier Souverain          |" -ForegroundColor Blue
    Write-Host "|                                                          |" -ForegroundColor Blue
    Write-Host "+==========================================================+" -ForegroundColor Blue
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Verifications initiales
# ---------------------------------------------------------------------------
function Test-Prerequisites {
    Write-CHULog "Verification de l'environnement systeme" -Level "STEP" -Color Cyan

    # Windows 10+
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10) {
        Write-CHULog "Windows 10 ou superieur requis (version actuelle : $osVersion)" -Level "ERROR" -Color Red
        exit 1
    }
    Write-CHULog "Windows $($osVersion.Major).$($osVersion.Minor) - OK" -Level "OK" -Color Green

    # Architecture 64 bits
    if (-not [Environment]::Is64BitOperatingSystem) {
        Write-CHULog "Architecture 64 bits requise" -Level "ERROR" -Color Red
        exit 1
    }
    Write-CHULog "Architecture 64 bits - OK" -Level "OK" -Color Green

    # Droits administrateur
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-CHULog "Ce script doit etre execute en tant qu'Administrateur" -Level "ERROR" -Color Red
        Write-Host "   Clic droit sur PowerShell  'Executer en tant qu'administrateur'" -ForegroundColor Yellow
        exit 1
    }
    Write-CHULog "Droits administrateur - OK" -Level "OK" -Color Green

    # Connexion Internet
    try {
        $null = Invoke-WebRequest -Uri "https://nodejs.org" -UseBasicParsing -TimeoutSec 5
        Write-CHULog "Connexion Internet - OK" -Level "OK" -Color Green
    } catch {
        Write-CHULog "Connexion Internet indisponible - certains composants ne pourront pas etre telecharges" -Level "WARN" -Color Yellow
    }
}

# ---------------------------------------------------------------------------
# Installation Node.js
# ---------------------------------------------------------------------------
function Install-NodeJS {
    if ($SkipNodejs) {
        Write-CHULog "Installation Node.js ignoree (--SkipNodejs)" -Level "WARN" -Color Yellow
        return
    }

    Write-CHULog "Verification de Node.js" -Level "STEP" -Color Cyan

    if (Test-CommandExists "node") {
        $version = Get-VersionNumber "node"
        $major = [int]($version -split '\.')[0]
        if ($major -ge 22) {
            Write-CHULog "Node.js $version deja installe ( 22) - OK" -Level "OK" -Color Green
            return
        }
        Write-CHULog "Node.js $version trouve mais version insuffisante (requis  22)" -Level "WARN" -Color Yellow
    }

    $installer = "$($Script:Config.TempDir)\node-setup.msi"
    if (Invoke-Download -Url $Script:Config.NodeUrl -Destination $installer -Description "Node.js $($Script:Config.NodeVersion) LTS") {
        Write-CHULog "Installation de Node.js $($Script:Config.NodeVersion)" -Level "STEP" -Color Cyan
        $process = Start-Process -FilePath "msiexec.exe" `
            -ArgumentList "/i `"$installer`" /quiet /norestart ADDLOCAL=ALL" `
            -Wait -PassThru
        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
            Write-CHULog "Node.js installe avec succes" -Level "OK" -Color Green
            # Rafraichir le PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                        [System.Environment]::GetEnvironmentVariable("Path", "User")
        } else {
            Write-CHULog "Echec de l'installation Node.js (code : $($process.ExitCode))" -Level "ERROR" -Color Red
        }
    }
}

# ---------------------------------------------------------------------------
# Installation Python
# ---------------------------------------------------------------------------
function Install-Python {
    if ($SkipPython) {
        Write-CHULog "Installation Python ignoree (--SkipPython)" -Level "WARN" -Color Yellow
        return
    }

    Write-CHULog "Verification de Python" -Level "STEP" -Color Cyan

    $pythonCmd = if (Test-CommandExists "python") { "python" }
                 elseif (Test-CommandExists "python3") { "python3" }
                 else { $null }

    if ($pythonCmd) {
        $version = Get-VersionNumber $pythonCmd
        $parts = $version -split '\.'
        if ([int]$parts[0] -ge 3 -and [int]$parts[1] -ge 11) {
            Write-CHULog "Python $version deja installe ( 3.11) - OK" -Level "OK" -Color Green
            $Script:PythonCmd = $pythonCmd
            return
        }
        Write-CHULog "Python $version trouve mais version insuffisante (requis  3.11)" -Level "WARN" -Color Yellow
    }

    $installer = "$($Script:Config.TempDir)\python-setup.exe"
    if (Invoke-Download -Url $Script:Config.PythonUrl -Destination $installer -Description "Python $($Script:Config.PythonVersion)") {
        Write-CHULog "Installation de Python $($Script:Config.PythonVersion)" -Level "STEP" -Color Cyan
        $process = Start-Process -FilePath $installer `
            -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_pip=1 Include_test=0" `
            -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Write-CHULog "Python installe avec succes" -Level "OK" -Color Green
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                        [System.Environment]::GetEnvironmentVariable("Path", "User")
            $Script:PythonCmd = "python"
        } else {
            Write-CHULog "Echec de l'installation Python (code : $($process.ExitCode))" -Level "ERROR" -Color Red
        }
    }
}

# ---------------------------------------------------------------------------
# Installation Git
# ---------------------------------------------------------------------------
function Install-Git {
    Write-CHULog "Verification de Git" -Level "STEP" -Color Cyan

    if (Test-CommandExists "git") {
        $version = Get-VersionNumber "git"
        Write-CHULog "Git $version deja installe - OK" -Level "OK" -Color Green
        return
    }

    $installer = "$($Script:Config.TempDir)\git-setup.exe"
    if (Invoke-Download -Url $Script:Config.GitUrl -Destination $installer -Description "Git for Windows") {
        Write-CHULog "Installation de Git" -Level "STEP" -Color Cyan
        Start-Process -FilePath $installer `
            -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /COMPONENTS=icons,ext\reg\shellhere,assoc,assoc_sh" `
            -Wait
        Write-CHULog "Git installe avec succes" -Level "OK" -Color Green
    }
}

# ---------------------------------------------------------------------------
# Installation des dependances Python
# ---------------------------------------------------------------------------
function Install-PythonPackages {
    Write-CHULog "Installation des dependances Python CHU" -Level "STEP" -Color Cyan

    $pythonCmd = if (Test-CommandExists "python") { "python" }
                 elseif (Test-CommandExists "python3") { "python3" }
                 else {
                     Write-CHULog "Python introuvable - impossible d'installer les dependances" -Level "ERROR" -Color Red
                     return
                 }

    # Mettre a jour pip
    Write-CHULog "Mise a jour de pip" -Level "INFO" -Color Gray
    & $pythonCmd -m pip install --upgrade pip --quiet 2>&1 | Out-Null

    # Installer chaque paquet
    foreach ($pkg in $Script:Config.PythonPackages) {
        Write-CHULog "  Installation : $pkg" -Level "INFO" -Color Gray
        $result = & $pythonCmd -m pip install $pkg --quiet 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-CHULog "Avertissement : echec de l'installation de $pkg" -Level "WARN" -Color Yellow
        }
    }

    Write-CHULog "Dependances Python installees" -Level "OK" -Color Green

    # Modele NLP francais
    if (-not $SkipNlpModel) {
        Write-CHULog "Telechargement du modele NLP francais (fr_core_news_lg - ~560 Mo)" -Level "STEP" -Color Cyan
        Write-CHULog "  Cette operation peut prendre plusieurs minutes selon votre connexion." -Level "INFO" -Color Gray
        $result = & $pythonCmd -m spacy download fr_core_news_lg 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-CHULog "Modele NLP francais installe" -Level "OK" -Color Green
        } else {
            Write-CHULog "Echec du telechargement du modele NLP - a installer manuellement : python -m spacy download fr_core_news_lg" -Level "WARN" -Color Yellow
        }
    } else {
        Write-CHULog "Modele NLP ignore (--SkipNlpModel) - a installer manuellement avant le premier demarrage" -Level "WARN" -Color Yellow
    }
}

# ---------------------------------------------------------------------------
# Configuration du pare-feu Windows
# ---------------------------------------------------------------------------
function Set-FirewallRules {
    Write-CHULog "Configuration du pare-feu Windows" -Level "STEP" -Color Cyan

    # Regle pour l'API CHU (port 8001 - localhost uniquement)
    $ruleName = "HERMES CHU API"
    $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if (-not $existingRule) {
        New-NetFirewallRule -DisplayName $ruleName `
            -Direction Inbound `
            -Protocol TCP `
            -LocalPort 8001 `
            -Action Allow `
            -Profile Private `
            -Description "HERMES CHU - API locale (Privacy Engine + Configuration)" `
            -ErrorAction SilentlyContinue | Out-Null
        Write-CHULog "Regle pare-feu creee : port 8001 (API CHU)" -Level "OK" -Color Green
    } else {
        Write-CHULog "Regle pare-feu deja presente : port 8001" -Level "OK" -Color Green
    }
}

# ---------------------------------------------------------------------------
# Creation des variables d'environnement systeme
# ---------------------------------------------------------------------------
function Set-EnvironmentVariables {
    param([string]$InstallDir)
    Write-CHULog "Configuration des variables d'environnement" -Level "STEP" -Color Cyan

    [System.Environment]::SetEnvironmentVariable("HERMES_CHU_HOME", $InstallDir, "Machine")
    [System.Environment]::SetEnvironmentVariable("CHU_API_BASE", "http://localhost:8001", "Machine")

    # Ajouter au PATH si necessaire
    $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $binPath = "$InstallDir"
    if ($currentPath -notlike "*$binPath*") {
        [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$binPath", "Machine")
    }

    Write-CHULog "Variables d'environnement configurees" -Level "OK" -Color Green
}

# ---------------------------------------------------------------------------
# Point d'entree principal
# ---------------------------------------------------------------------------
function Main {
    Show-Banner

    # Creer le dossier temporaire
    New-Item -ItemType Directory -Path $Script:Config.TempDir -Force | Out-Null

    # Initialiser le journal
    $startTime = Get-Date
    Add-Content -Path $Script:Config.LogFile -Value "=== HERMES CHU Installation - $startTime ===" -Encoding UTF8

    Write-CHULog "Demarrage de l'installation des prerequis" -Level "INFO" -Color White
    Write-CHULog "Journal : $($Script:Config.LogFile)" -Level "INFO" -Color Gray
    Write-Host ""

    # Etapes d'installation
    Test-Prerequisites
    Write-Host ""

    Install-NodeJS
    Install-Python
    Install-Git
    Write-Host ""

    Install-PythonPackages
    Write-Host ""

    Set-FirewallRules
    Set-EnvironmentVariables -InstallDir $InstallDir
    Write-Host ""

    # Nettoyage
    Remove-Item -Path $Script:Config.TempDir -Recurse -Force -ErrorAction SilentlyContinue

    # Resume final
    $duration = (Get-Date) - $startTime
    Write-Host ""
    Write-Host "+==========================================================+" -ForegroundColor Green
    Write-Host "|           Installation des prerequis terminee !        |" -ForegroundColor Green
    Write-Host "+==========================================================" -ForegroundColor Green
    Write-Host "|  Duree : $([math]::Round($duration.TotalSeconds))s" -ForegroundColor Green
    Write-Host "|  Journal : $($Script:Config.LogFile)" -ForegroundColor Green
    Write-Host "+==========================================================+" -ForegroundColor Green
    Write-Host ""
    Write-CHULog "Installation terminee en $([math]::Round($duration.TotalSeconds)) secondes" -Level "OK" -Color Green
}

Main
