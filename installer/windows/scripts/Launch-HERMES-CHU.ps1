# ============================================================
# HERMES CHU - Script de lancement
# Concu par William MERI - CHU de Guyane
# Lance hermes setup si non configure, puis hermes dashboard
# v2.2.0 : Correction commande (hermes dashboard, port 9119)
# ============================================================

$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "HERMES CHU - Demarrage"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  HERMES CHU - Systeme Agentique Hospitalier" -ForegroundColor Cyan
Write-Host "  CHU de Guyane | William MERI | @Tarzzan" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# --- Rechargement du PATH depuis le registre ---
function Refresh-Path {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath    = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path    = "$machinePath;$userPath"
}

Refresh-Path

# --- Verifier que hermes est accessible ---
$hermesCmd = Get-Command hermes -ErrorAction SilentlyContinue
if (-not $hermesCmd) {
    # Essayer les chemins connus d'installation
    $candidates = @(
        "$env:LOCALAPPDATA\hermes\hermes-agent\venv\Scripts\hermes.exe",
        "$env:LOCALAPPDATA\hermes\hermes-chu\.venv\Scripts\hermes.exe",
        "$env:LOCALAPPDATA\hermes\hermes-chu\.venv\Scripts\hermes",
        "$env:USERPROFILE\.local\bin\hermes",
        "$env:APPDATA\Python\Scripts\hermes.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) {
            $hermesDir = Split-Path $c
            $env:Path = "$hermesDir;$env:Path"
            $hermesCmd = Get-Command hermes -ErrorAction SilentlyContinue
            if ($hermesCmd) { break }
        }
    }
}

if (-not $hermesCmd) {
    Write-Host "[ERREUR] La commande 'hermes' est introuvable." -ForegroundColor Red
    Write-Host ""
    Write-Host "Cela signifie que l'installation n'a pas ete completee." -ForegroundColor Yellow
    Write-Host "Veuillez relancer l'installateur HERMES-CHU-Setup.exe" -ForegroundColor Yellow
    Write-Host "ou executer manuellement :" -ForegroundColor Yellow
    Write-Host "  powershell -File $env:TEMP\install-chu.ps1" -ForegroundColor White
    Write-Host ""
    Read-Host "Appuyez sur Entree pour fermer"
    exit 1
}

Write-Host "[OK] Commande hermes trouvee : $($hermesCmd.Source)" -ForegroundColor Green
Write-Host ""

# --- Verifier si la configuration existe ---
$configPaths = @(
    "$env:USERPROFILE\.hermes\config.yaml",
    "$env:USERPROFILE\.hermes\config.yml",
    "$env:LOCALAPPDATA\hermes\config.yaml",
    "$env:LOCALAPPDATA\hermes\hermes-agent\config.yaml",
    "$env:LOCALAPPDATA\hermes\hermes-chu\config.yaml"
)

$configFound = $false
foreach ($p in $configPaths) {
    if (Test-Path $p) {
        $configFound = $true
        Write-Host "[OK] Configuration trouvee : $p" -ForegroundColor Green
        break
    }
}

# --- Setup si non configure ---
if (-not $configFound) {
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host "  PREMIERE UTILISATION - Configuration requise" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "HERMES CHU n'est pas encore configure." -ForegroundColor White
    Write-Host "L'assistant de configuration va demarrer." -ForegroundColor White
    Write-Host ""
    Write-Host "Vous pourrez choisir votre fournisseur LLM :" -ForegroundColor Cyan
    Write-Host "  - ChatGPT (abonnement, sans cle API)" -ForegroundColor White
    Write-Host "  - Azure OpenAI" -ForegroundColor White
    Write-Host "  - OpenAI (cle API)" -ForegroundColor White
    Write-Host "  - Ollama (local, gratuit)" -ForegroundColor White
    Write-Host "  - Et bien d'autres..." -ForegroundColor White
    Write-Host ""
    Write-Host "Pour ChatGPT abonnement : un code s'affichera," -ForegroundColor Cyan
    Write-Host "allez sur https://chatgpt.com/link et entrez le code." -ForegroundColor Cyan
    Write-Host ""
    Read-Host "Appuyez sur Entree pour lancer la configuration"
    Write-Host ""

    try {
        $ErrorActionPreference = "Continue"
        hermes setup
        $ErrorActionPreference = "Stop"
        Write-Host ""
        Write-Host "[OK] Configuration terminee !" -ForegroundColor Green
        Write-Host ""
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Host ""
        Write-Host "[ERREUR] La configuration a echoue : $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Vous pouvez reessayer en tapant : hermes setup" -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Appuyez sur Entree pour fermer"
        exit 1
    }
}

# --- Lancement de hermes dashboard ---
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Demarrage de l'interface web HERMES CHU..." -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "L'interface sera disponible sur : http://localhost:9119" -ForegroundColor Green
Write-Host "Le navigateur va s'ouvrir automatiquement." -ForegroundColor Gray
Write-Host ""
Write-Host "Pour arreter : Ctrl+C" -ForegroundColor Yellow
Write-Host ""

try {
    $ErrorActionPreference = "Continue"
    hermes dashboard
}
catch {
    Write-Host ""
    Write-Host "[ERREUR] hermes dashboard a echoue : $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Commandes utiles :" -ForegroundColor Yellow
    Write-Host "  hermes setup      - Reconfigurer le fournisseur LLM" -ForegroundColor White
    Write-Host "  hermes dashboard  - Interface web (port 9119)" -ForegroundColor White
    Write-Host "  hermes chat       - Interface en ligne de commande" -ForegroundColor White
    Write-Host "  hermes desktop    - Interface desktop Electron" -ForegroundColor White
    Write-Host "  hermes --help     - Aide complete" -ForegroundColor White
    Write-Host ""
    Read-Host "Appuyez sur Entree pour fermer"
    exit 1
}
