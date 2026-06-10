#Requires -Version 5.1
<#
.SYNOPSIS
    HERMES CHU — Assistant de configuration (premier démarrage)
.DESCRIPTION
    Guide interactif de configuration de HERMES CHU après installation :
    - Choix du fournisseur LLM (Azure OpenAI, OpenAI, Ollama, vLLM)
    - Configuration des clés API
    - Test de connectivité
    - Configuration du Privacy Engine RGPD
    - Enregistrement comme service Windows (optionnel)
#>

[CmdletBinding()]
param(
    [string]$InstallDir = $env:HERMES_CHU_HOME,
    [switch]$Silent
)

$ErrorActionPreference = "Continue"

if (-not $InstallDir) {
    $InstallDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

$EnvFile = "$InstallDir\chu\.env.chu"

# ---------------------------------------------------------------------------
# Utilitaires UI
# ---------------------------------------------------------------------------
function Write-Title {
    param([string]$Text)
    Write-Host ""
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor Blue
    Write-Host "  $Text" -ForegroundColor White
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor Blue
    Write-Host ""
}

function Read-SecureInput {
    param([string]$Prompt)
    Write-Host "  $Prompt : " -NoNewline -ForegroundColor Cyan
    $secure = Read-Host -AsSecureString
    $bstr   = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
}

function Read-Input {
    param([string]$Prompt, [string]$Default = "")
    if ($Default) {
        Write-Host "  $Prompt [$Default] : " -NoNewline -ForegroundColor Cyan
    } else {
        Write-Host "  $Prompt : " -NoNewline -ForegroundColor Cyan
    }
    $input = Read-Host
    if ([string]::IsNullOrWhiteSpace($input) -and $Default) { return $Default }
    return $input
}

function Test-AzureOpenAI {
    param([string]$Endpoint, [string]$ApiKey, [string]$Deployment)
    try {
        $uri = "$Endpoint/openai/deployments/$Deployment/chat/completions?api-version=2024-02-01"
        $body = @{
            messages = @(@{ role = "user"; content = "test" })
            max_tokens = 1
        } | ConvertTo-Json
        $headers = @{ "api-key" = $ApiKey; "Content-Type" = "application/json" }
        $response = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -Body $body -TimeoutSec 10
        return $true
    } catch {
        return $false
    }
}

function Test-OpenAI {
    param([string]$ApiKey)
    try {
        $headers = @{ "Authorization" = "Bearer $ApiKey"; "Content-Type" = "application/json" }
        $body = @{ model = "gpt-4o-mini"; messages = @(@{ role = "user"; content = "test" }); max_tokens = 1 } | ConvertTo-Json
        $response = Invoke-RestMethod -Uri "https://api.openai.com/v1/chat/completions" -Method POST -Headers $headers -Body $body -TimeoutSec 10
        return $true
    } catch {
        return $false
    }
}

function Update-EnvFile {
    param([hashtable]$Values)
    $content = Get-Content $EnvFile -Raw -ErrorAction SilentlyContinue
    if (-not $content) { $content = "" }

    foreach ($key in $Values.Keys) {
        $value = $Values[$key]
        if ($content -match "(?m)^$key=.*$") {
            $content = $content -replace "(?m)^$key=.*$", "$key=$value"
        } else {
            $content += "`r`n$key=$value"
        }
    }
    $content | Set-Content -Path $EnvFile -Encoding UTF8
}

# ---------------------------------------------------------------------------
# Bannière
# ---------------------------------------------------------------------------
Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "  ║                                                          ║" -ForegroundColor Blue
Write-Host "  ║      HERMES CHU — Assistant de Configuration             ║" -ForegroundColor Blue
Write-Host "  ║      Système Agentique Hospitalier Souverain             ║" -ForegroundColor Blue
Write-Host "  ║                                                          ║" -ForegroundColor Blue
Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""
Write-Host "  Cet assistant configure votre instance HERMES CHU." -ForegroundColor Gray
Write-Host "  Toutes les clés API sont stockées localement dans :" -ForegroundColor Gray
Write-Host "  $EnvFile" -ForegroundColor DarkGray
Write-Host ""

# ---------------------------------------------------------------------------
# Étape 1 — Choix du fournisseur LLM
# ---------------------------------------------------------------------------
Write-Title "Étape 1/4 — Fournisseur IA"
Write-Host "  Choisissez votre fournisseur de modèle IA :" -ForegroundColor White
Write-Host ""
Write-Host "  [1] Azure OpenAI     (recommandé POC — certifié HDS)" -ForegroundColor Cyan
Write-Host "  [2] OpenAI           (GPT-4o, GPT-4-turbo)" -ForegroundColor Cyan
Write-Host "  [3] Ollama           (modèles locaux — GPU requis)" -ForegroundColor Cyan
Write-Host "  [4] vLLM On-Premise  (Hermes-3-70B — infrastructure CHU)" -ForegroundColor Cyan
Write-Host "  [5] Configurer plus tard" -ForegroundColor DarkGray
Write-Host ""

$choice = Read-Input "Votre choix" "1"
$provider = ""
$providerConfig = @{}

switch ($choice) {
    "1" {
        $provider = "azure_openai"
        Write-Host ""
        Write-Host "  Configuration Azure OpenAI" -ForegroundColor White
        Write-Host "  → Trouvez ces informations dans le portail Azure (Cognitive Services)" -ForegroundColor DarkGray
        Write-Host ""
        $endpoint   = Read-Input "Endpoint Azure" "https://votre-ressource.openai.azure.com/"
        $apiKey     = Read-SecureInput "Clé API Azure"
        $deployment = Read-Input "Nom du déploiement" "gpt-4o"
        $apiVersion = Read-Input "Version API" "2024-02-01"

        Write-Host ""
        Write-Host "  Test de connexion Azure OpenAI…" -ForegroundColor Cyan -NoNewline
        if (Test-AzureOpenAI -Endpoint $endpoint -ApiKey $apiKey -Deployment $deployment) {
            Write-Host " ✅ Connexion réussie !" -ForegroundColor Green
        } else {
            Write-Host " ⚠️  Connexion échouée — vérifiez les paramètres" -ForegroundColor Yellow
        }

        $providerConfig = @{
            FOURNISSEUR_ACTIF           = "azure_openai"
            AZURE_OPENAI_ENDPOINT       = $endpoint
            AZURE_OPENAI_API_KEY        = $apiKey
            AZURE_OPENAI_DEPLOYMENT     = $deployment
            AZURE_OPENAI_API_VERSION    = $apiVersion
        }
    }
    "2" {
        $provider = "openai"
        Write-Host ""
        $apiKey = Read-SecureInput "Clé API OpenAI (sk-...)"
        $model  = Read-Input "Modèle" "gpt-4o"

        Write-Host ""
        Write-Host "  Test de connexion OpenAI…" -ForegroundColor Cyan -NoNewline
        if (Test-OpenAI -ApiKey $apiKey) {
            Write-Host " ✅ Connexion réussie !" -ForegroundColor Green
        } else {
            Write-Host " ⚠️  Connexion échouée — vérifiez la clé API" -ForegroundColor Yellow
        }

        $providerConfig = @{
            FOURNISSEUR_ACTIF = "openai"
            OPENAI_API_KEY    = $apiKey
            OPENAI_MODEL      = $model
        }
    }
    "3" {
        $provider = "ollama"
        $ollamaUrl = Read-Input "URL Ollama" "http://localhost:11434"
        $model     = Read-Input "Modèle Ollama" "hermes3:70b"
        $providerConfig = @{
            FOURNISSEUR_ACTIF = "ollama"
            OLLAMA_BASE_URL   = $ollamaUrl
            OLLAMA_MODEL      = $model
        }
    }
    "4" {
        $provider = "vllm"
        $vllmUrl  = Read-Input "URL vLLM" "http://vllm-service:8000/v1"
        $model    = Read-Input "Modèle" "NousResearch/Hermes-3-Llama-3.1-70B-Instruct"
        $providerConfig = @{
            FOURNISSEUR_ACTIF = "vllm"
            VLLM_BASE_URL     = $vllmUrl
            VLLM_MODEL        = $model
        }
    }
    default {
        Write-Host "  ℹ️  Configuration LLM ignorée — à configurer via l'interface HERMES CHU" -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# Étape 2 — Privacy Engine RGPD
# ---------------------------------------------------------------------------
Write-Title "Étape 2/4 — Privacy Engine RGPD"
Write-Host "  Le Privacy Engine anonymise les données de santé (PHI)" -ForegroundColor White
Write-Host "  avant tout envoi au modèle IA." -ForegroundColor White
Write-Host ""
Write-Host "  Entités détectées : Noms, NIR, IPP, Adresses, Téléphones," -ForegroundColor Gray
Write-Host "  Dates de naissance, Numéros de dossier, Codes postaux" -ForegroundColor Gray
Write-Host ""

$privacyChoice = Read-Input "Activer l'anonymisation RGPD dès le démarrage ? (O/n)" "O"
$privacyEnabled = if ($privacyChoice -match "^[Oo]") { "true" } else { "false" }

$providerConfig["PRIVACY_ENGINE_ACTIF"] = $privacyEnabled

if ($privacyEnabled -eq "true") {
    Write-Host "  ✅ Privacy Engine activé" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Privacy Engine désactivé — les données brutes seront envoyées au LLM" -ForegroundColor Yellow
    Write-Host "     Activez-le avant toute utilisation en production !" -ForegroundColor Red
}

# ---------------------------------------------------------------------------
# Étape 3 — Port et configuration réseau
# ---------------------------------------------------------------------------
Write-Title "Étape 3/4 — Configuration réseau"

$apiPort = Read-Input "Port de l'API CHU" "8001"
$providerConfig["CHU_API_PORT"] = $apiPort

Write-Host "  ✅ API CHU configurée sur le port $apiPort" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Étape 4 — Service Windows
# ---------------------------------------------------------------------------
Write-Title "Étape 4/4 — Service Windows (optionnel)"
Write-Host "  Enregistrer l'API CHU comme service Windows ?" -ForegroundColor White
Write-Host "  (Démarrage automatique avec Windows, sans fenêtre visible)" -ForegroundColor Gray
Write-Host ""

$serviceChoice = Read-Input "Créer le service Windows ? (o/N)" "N"
if ($serviceChoice -match "^[Oo]") {
    # Vérifier NSSM
    $nssmPath = "$InstallDir\tools\nssm.exe"
    if (Test-Path $nssmPath) {
        $serviceName = "HERMES-CHU-API"
        $pythonCmd   = (Get-Command "python" -ErrorAction SilentlyContinue).Source

        & $nssmPath install $serviceName $pythonCmd "-m uvicorn chu.api.serveur_chu:app --host 127.0.0.1 --port $apiPort" 2>&1 | Out-Null
        & $nssmPath set $serviceName AppDirectory $InstallDir 2>&1 | Out-Null
        & $nssmPath set $serviceName DisplayName "HERMES CHU — API Hospitalière" 2>&1 | Out-Null
        & $nssmPath set $serviceName Description "Privacy Engine RGPD et API de configuration HERMES CHU" 2>&1 | Out-Null
        & $nssmPath set $serviceName Start SERVICE_AUTO_START 2>&1 | Out-Null
        & $nssmPath set $serviceName AppStdout "$InstallDir\chu\logs\service-stdout.log" 2>&1 | Out-Null
        & $nssmPath set $serviceName AppStderr "$InstallDir\chu\logs\service-stderr.log" 2>&1 | Out-Null

        Start-Service -Name $serviceName -ErrorAction SilentlyContinue
        Write-Host "  ✅ Service Windows '$serviceName' créé et démarré" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  NSSM non trouvé — service non créé" -ForegroundColor Yellow
        Write-Host "     Utilisez le raccourci 'Démarrer l'API CHU' dans le menu Démarrer" -ForegroundColor Gray
    }
} else {
    Write-Host "  ℹ️  Service Windows non créé — démarrage manuel via le menu Démarrer" -ForegroundColor Gray
}

# ---------------------------------------------------------------------------
# Enregistrement de la configuration
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  💾 Enregistrement de la configuration…" -ForegroundColor Cyan
Update-EnvFile -Values $providerConfig
Write-Host "  ✅ Configuration enregistrée dans $EnvFile" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Résumé final
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║         ✅  HERMES CHU est configuré et prêt !           ║" -ForegroundColor Green
Write-Host "  ╠══════════════════════════════════════════════════════════╣" -ForegroundColor Green
Write-Host "  ║  Fournisseur IA   : $provider" -ForegroundColor Green
Write-Host "  ║  Privacy Engine   : $privacyEnabled" -ForegroundColor Green
Write-Host "  ║  Port API CHU     : $apiPort" -ForegroundColor Green
Write-Host "  ╠══════════════════════════════════════════════════════════╣" -ForegroundColor Green
Write-Host "  ║  Prochaines étapes :" -ForegroundColor Green
Write-Host "  ║  1. Lancez 'Démarrer l'API CHU' depuis le menu Démarrer" -ForegroundColor Green
Write-Host "  ║  2. Ouvrez HERMES CHU depuis le bureau" -ForegroundColor Green
Write-Host "  ║  3. Consultez le wiki : github.com/Tarzzan/HERMES-CHU/wiki" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
