#Requires -Version 5.1
<#
.SYNOPSIS
    HERMES CHU - Assistant de configuration (premier demarrage)
.DESCRIPTION
    Configure le fournisseur LLM, le Privacy Engine RGPD et l'API CHU.
    Genere le fichier .env.chu dans le repertoire d'installation.
.NOTES
    Auteur  : William MERI - CHU de Guyane
    Version : 1.3.0
    Licence : Apache 2.0
#>

param(
    [string]$InstallDir = $PSScriptRoot + "\..",
    [switch]$Silent
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Fonctions utilitaires
# ---------------------------------------------------------------------------
function Write-Title {
    param([string]$Text)
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor DarkCyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "  ============================================================" -ForegroundColor DarkCyan
    Write-Host ""
}

function Write-Step {
    param([string]$Text)
    Write-Host "  >> $Text" -ForegroundColor Yellow
}

function Write-OK {
    param([string]$Text)
    Write-Host "  [OK] $Text" -ForegroundColor Green
}

function Write-ERR {
    param([string]$Text)
    Write-Host "  [ERREUR] $Text" -ForegroundColor Red
}

function Read-Input {
    param([string]$Prompt, [string]$Default = "")
    $display = if ($Default) { "$Prompt [$Default]" } else { $Prompt }
    $val = Read-Host "  $display"
    if ([string]::IsNullOrWhiteSpace($val)) { return $Default }
    return $val
}

# ---------------------------------------------------------------------------
# En-tete
# ---------------------------------------------------------------------------
Clear-Host
Write-Host ""
Write-Host "  ============================================================" -ForegroundColor DarkCyan
Write-Host "  HERMES CHU 1.3.0 - Configuration initiale" -ForegroundColor Cyan
Write-Host "  Concu par William MERI - CHU de Guyane" -ForegroundColor DarkGray
Write-Host "  Base sur Hermes Agent (NousResearch)" -ForegroundColor DarkGray
Write-Host "  ============================================================" -ForegroundColor DarkCyan
Write-Host ""

# ---------------------------------------------------------------------------
# Etape 1 - Choix du fournisseur LLM
# ---------------------------------------------------------------------------
Write-Title "Etape 1/4 - Fournisseur IA"
Write-Host "  Choisissez votre fournisseur de modele IA :" -ForegroundColor White
Write-Host ""
Write-Host "  --- ABONNEMENT (sans cle API) ---" -ForegroundColor DarkGray
Write-Host "  [1] ChatGPT           (abonnement Plus/Team/Enterprise)" -ForegroundColor Cyan
Write-Host "      -> Connexion via code sur chatgpt.com/link" -ForegroundColor DarkGray
Write-Host "  [2] Nous Portal       (abonnement NousResearch)" -ForegroundColor Cyan
Write-Host "      -> Connexion via code d'appairage" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  --- LOCAL (sans cle API) ---" -ForegroundColor DarkGray
Write-Host "  [3] Ollama            (modeles locaux)" -ForegroundColor Cyan
Write-Host "  [4] LM Studio         (modeles locaux)" -ForegroundColor Cyan
Write-Host "  [5] vLLM On-Premise   (Hermes-3-70B)" -ForegroundColor Cyan
Write-Host ""
Write-Host "  --- CLOUD (cle API requise) ---" -ForegroundColor DarkGray
Write-Host "  [6] Azure OpenAI      (certifie HDS)" -ForegroundColor Cyan
Write-Host "  [7] OpenAI API        (GPT-4o, o1, o3)" -ForegroundColor Cyan
Write-Host ""
Write-Host "  [8] Configurer plus tard" -ForegroundColor DarkGray
Write-Host ""
$choice = Read-Input "Votre choix" "1"
$provider = ""
$providerEnv = ""
$needsApiKey = $false

switch ($choice) {
    "1" {
        $provider = "ChatGPT (abonnement)"
        $providerEnv = "openai-codex"
        Write-Host ""
        Write-OK "ChatGPT selectionne."
        Write-Host "  Lors du premier lancement de HERMES CHU, un code sera affiche." -ForegroundColor White
        Write-Host "  Rendez-vous sur : https://chatgpt.com/link" -ForegroundColor Cyan
        Write-Host "  Saisissez le code pour autoriser la connexion." -ForegroundColor White
        Write-Host "  Fonctionne avec : ChatGPT Plus, Team, Enterprise" -ForegroundColor DarkGray
    }
    "2" {
        $provider = "Nous Portal (abonnement)"
        $providerEnv = "nous-portal"
        Write-OK "Nous Portal selectionne - code d'appairage au premier lancement."
    }
    "3" {
        $provider = "Ollama"
        $providerEnv = "ollama"
        $ollamaUrl = Read-Input "URL Ollama" "http://localhost:11434"
        $ollamaModel = Read-Input "Modele Ollama" "hermes3:70b"
        Write-OK "Ollama configure sur $ollamaUrl"
    }
    "4" {
        $provider = "LM Studio"
        $providerEnv = "lm-studio"
        $lmStudioUrl = Read-Input "URL LM Studio" "http://localhost:1234"
        Write-OK "LM Studio configure sur $lmStudioUrl"
    }
    "5" {
        $provider = "vLLM On-Premise"
        $providerEnv = "vllm"
        $vllmUrl = Read-Input "URL vLLM" "http://localhost:8000/v1"
        $vllmModel = Read-Input "Modele vLLM" "NousResearch/Hermes-3-Llama-3.1-70B-Instruct"
        Write-OK "vLLM configure sur $vllmUrl"
    }
    "6" {
        $provider = "Azure OpenAI"
        $providerEnv = "azure_openai"
        $needsApiKey = $true
        $azureEndpoint = Read-Input "Endpoint Azure OpenAI" "https://votre-ressource.openai.azure.com/"
        $azureKey = Read-Host "  Cle API Azure OpenAI (masquee)" -AsSecureString
        $azureKeyPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($azureKey))
        $azureDeployment = Read-Input "Nom du deploiement" "gpt-4o"
        Write-OK "Azure OpenAI configure."
    }
    "7" {
        $provider = "OpenAI API"
        $providerEnv = "openai"
        $needsApiKey = $true
        $openaiKey = Read-Host "  Cle API OpenAI (masquee)" -AsSecureString
        $openaiKeyPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($openaiKey))
        $openaiModel = Read-Input "Modele" "gpt-4o"
        Write-OK "OpenAI API configure."
    }
    default {
        $provider = "Non configure"
        $providerEnv = "none"
        Write-Step "Configuration reportee - modifiable dans $InstallDir\chu\.env.chu"
    }
}

# ---------------------------------------------------------------------------
# Etape 2 - Privacy Engine RGPD
# ---------------------------------------------------------------------------
Write-Title "Etape 2/4 - Privacy Engine RGPD"
Write-Host "  Le Privacy Engine anonymise les donnees de sante (PHI)" -ForegroundColor White
Write-Host "  avant tout envoi au LLM, meme avec un fournisseur tiers." -ForegroundColor White
Write-Host "  7 flux couverts : entrees, sorties, memoire, skills, contexte." -ForegroundColor DarkGray
Write-Host ""
$privacyChoice = Read-Input "Activer le Privacy Engine RGPD ? (O/n)" "O"
$privacyEnabled = ($privacyChoice -match "^[Oo]")

if ($privacyEnabled) {
    Write-OK "Privacy Engine RGPD active (recommande pour le POC)."
} else {
    Write-Host "  [AVERT] Privacy Engine desactive." -ForegroundColor Yellow
    Write-Host "  Assurez-vous que vos donnees sont deja anonymisees." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Etape 3 - Port API CHU
# ---------------------------------------------------------------------------
Write-Title "Etape 3/4 - API CHU"
$apiPort = Read-Input "Port de l'API CHU" "8001"
Write-OK "API CHU configuree sur le port $apiPort"

# ---------------------------------------------------------------------------
# Etape 4 - Generation du .env.chu
# ---------------------------------------------------------------------------
Write-Title "Etape 4/4 - Generation de la configuration"

$envPath = "$InstallDir\chu\.env.chu"
$envDir = Split-Path $envPath -Parent
if (-not (Test-Path $envDir)) { New-Item -ItemType Directory -Path $envDir -Force | Out-Null }

$envContent = @"
# HERMES CHU 1.3.0 - Configuration
# Genere par Configure-CHU.ps1
# Auteur : William MERI - CHU de Guyane
# Date   : $(Get-Date -Format "yyyy-MM-dd HH:mm")

# ============================================================
# FOURNISSEUR LLM
# ============================================================
FOURNISSEUR_ACTIF=$providerEnv

# ChatGPT abonnement (openai-codex) - sans cle API
# Connexion via code sur chatgpt.com/link au premier lancement
CHATGPT_PROVIDER=openai-codex

# Ollama (local - sans cle API)
OLLAMA_BASE_URL=$(if ($choice -eq "3") { $ollamaUrl } else { "http://localhost:11434" })
OLLAMA_MODEL=$(if ($choice -eq "3") { $ollamaModel } else { "hermes3:70b" })

# LM Studio (local - sans cle API)
LM_STUDIO_BASE_URL=$(if ($choice -eq "4") { $lmStudioUrl } else { "http://localhost:1234/v1" })

# vLLM On-Premise
VLLM_BASE_URL=$(if ($choice -eq "5") { $vllmUrl } else { "http://localhost:8000/v1" })
VLLM_MODEL=$(if ($choice -eq "5") { $vllmModel } else { "NousResearch/Hermes-3-Llama-3.1-70B-Instruct" })

# Azure OpenAI (HDS - cle API requise)
AZURE_OPENAI_ENDPOINT=$(if ($choice -eq "6") { $azureEndpoint } else { "" })
AZURE_OPENAI_API_KEY=$(if ($choice -eq "6") { $azureKeyPlain } else { "" })
AZURE_OPENAI_DEPLOYMENT=$(if ($choice -eq "6") { $azureDeployment } else { "gpt-4o" })
AZURE_OPENAI_API_VERSION=2024-02-01

# OpenAI API (cle API requise)
OPENAI_API_KEY=$(if ($choice -eq "7") { $openaiKeyPlain } else { "" })
OPENAI_MODEL=$(if ($choice -eq "7") { $openaiModel } else { "gpt-4o" })

# ============================================================
# PRIVACY ENGINE RGPD
# ============================================================
PRIVACY_ENGINE_ACTIF=$(if ($privacyEnabled) { "true" } else { "false" })
PRIVACY_LOG_LEVEL=INFO
PRIVACY_PATCH_CONVERSATION=true
PRIVACY_PATCH_MEMORY=true
PRIVACY_PATCH_BACKGROUND_REVIEW=true
PRIVACY_PATCH_TRAJECTORY=true
PRIVACY_PATCH_CURATOR=true
PRIVACY_PATCH_CONTEXT_COMPRESSOR=true
PRIVACY_NER_MODEL=fr_core_news_lg
PRIVACY_GLASS_BREAK_REQUIRE_JUSTIFICATION=true
PRIVACY_AUDIT_LOG=true

# ============================================================
# API CHU
# ============================================================
CHU_API_PORT=$apiPort
CHU_API_HOST=127.0.0.1
DATABASE_URL=sqlite:///$InstallDir\chu\data\hermes_chu.db
"@

$envContent | Out-File -FilePath $envPath -Encoding UTF8 -Force
Write-OK "Configuration sauvegardee dans : $envPath"

# ---------------------------------------------------------------------------
# Resume final
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host "  HERMES CHU 1.3.0 - Configuration terminee !" -ForegroundColor Green
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host "  Fournisseur LLM  : $provider" -ForegroundColor Green
Write-Host "  Privacy RGPD     : $(if ($privacyEnabled) { 'ACTIVE (7 flux)' } else { 'Desactive' })" -ForegroundColor Green
Write-Host "  Port API CHU     : $apiPort" -ForegroundColor Green
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Prochaines etapes :" -ForegroundColor White
Write-Host "  1. Lancez 'Demarrer l API CHU' depuis le menu Demarrer" -ForegroundColor White
Write-Host "  2. Ouvrez HERMES CHU depuis le bureau" -ForegroundColor White
Write-Host "  3. Wiki : github.com/Tarzzan/PULSAR-CHU/wiki" -ForegroundColor Cyan
Write-Host ""

if (-not $Silent) {
    Write-Host "  Appuyez sur une touche pour fermer..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
