# ============================================================
# HERMES CHU - Script de lancement
# Concu par William MERI - CHU de Guyane
# Lance hermes setup si non configure, applique le branding
# CHU, puis demarre hermes dashboard (port 9119)
# v2.3.0 : Branding CHU automatique au premier lancement
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
$configPath = $null
foreach ($p in $configPaths) {
    if (Test-Path $p) {
        $configFound = $true
        $configPath = $p
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
        # Retrouver le config.yaml cree
        foreach ($p in $configPaths) {
            if (Test-Path $p) { $configPath = $p; break }
        }
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

# ============================================================
# --- Application du branding CHU (idempotent) ---
# ============================================================
$brandingMarker = "$env:LOCALAPPDATA\hermes\.chu_branding_applied"
if (-not (Test-Path $brandingMarker)) {
    Write-Host ""
    Write-Host "[...] Application du branding HERMES CHU..." -ForegroundColor Cyan

    $HermesHome = "$env:LOCALAPPDATA\hermes"

    # 1. Installer le skin chu-guyane.yaml
    $skinsDir = "$HermesHome\skins"
    New-Item -ItemType Directory -Force -Path $skinsDir | Out-Null

    # Trouver le fichier skin dans le dossier d'installation CHU
    $skinSource = $null
    $skinCandidates = @(
        "$env:LOCALAPPDATA\hermes\hermes-chu\chu\branding\chu-guyane.yaml",
        (Join-Path (Split-Path $PSCommandPath) "..\..\..\chu\branding\chu-guyane.yaml"),
        (Join-Path (Split-Path $PSCommandPath) "chu-guyane.yaml")
    )
    foreach ($sc in $skinCandidates) {
        if (Test-Path $sc) { $skinSource = $sc; break }
    }

    if ($skinSource) {
        Copy-Item $skinSource "$skinsDir\chu-guyane.yaml" -Force
        Write-Host "  [OK] Skin CHU installe" -ForegroundColor Green
    } else {
        # Telecharger depuis GitHub
        try {
            $skinUrl = "https://raw.githubusercontent.com/Tarzzan/HERMES-CHU/main/chu/branding/chu-guyane.yaml"
            Invoke-WebRequest -Uri $skinUrl -OutFile "$skinsDir\chu-guyane.yaml" -UseBasicParsing
            Write-Host "  [OK] Skin CHU telecharge depuis GitHub" -ForegroundColor Green
        } catch {
            Write-Host "  [WARN] Skin CHU non disponible : $_" -ForegroundColor Yellow
        }
    }

    # 2. Activer le skin dans config.yaml
    if ($configPath -and (Test-Path $configPath)) {
        $configContent = Get-Content $configPath -Raw -Encoding UTF8
        if ($configContent -notmatch "skin:\s*chu-guyane") {
            if ($configContent -match "display:") {
                if ($configContent -notmatch "display:[\s\S]{0,200}skin:") {
                    $configContent = $configContent -replace "(display:)", "`$1`n  skin: chu-guyane"
                } else {
                    $configContent = $configContent -replace "(skin:\s*)[\w-]+", "`${1}chu-guyane"
                }
            } else {
                $configContent = $configContent.TrimEnd() + "`n`n# Branding CHU de Guyane`ndisplay:`n  skin: chu-guyane`n"
            }
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($configPath, $configContent, $utf8NoBom)
            Write-Host "  [OK] Skin CHU active dans config.yaml" -ForegroundColor Green
        }
    }

    # 3. Patcher les fichiers i18n (brand + footer)
    $hermesAgentCandidates = @(
        "$env:LOCALAPPDATA\hermes\hermes-agent",
        "$env:LOCALAPPDATA\hermes\hermes-chu"
    )
    foreach ($agentDir in $hermesAgentCandidates) {
        $i18nFiles = @(
            "$agentDir\web\src\i18n\fr.ts",
            "$agentDir\web\src\i18n\en.ts"
        )
        foreach ($f in $i18nFiles) {
            if (Test-Path $f) {
                $c = Get-Content $f -Raw -Encoding UTF8
                $c = $c -replace 'brand:\s*"Hermes Agent"', 'brand: "HERMES CHU"'
                $c = $c -replace "brand:\s*'Hermes Agent'", "brand: 'HERMES CHU'"
                $c = $c -replace 'brandShort:\s*"HA"', 'brandShort: "CHU"'
                $c = $c -replace "brandShort:\s*'HA'", "brandShort: 'CHU'"
                $c = $c -replace 'org:\s*"Nous Research"', 'org: "William MERI · CHU de Guyane"'
                $c = $c -replace "org:\s*'Nous Research'", "org: 'William MERI · CHU de Guyane'"
                $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
                [System.IO.File]::WriteAllText($f, $c, $utf8NoBom)
                Write-Host "  [OK] i18n patche : $f" -ForegroundColor Green
            }
        }

        # 4. Patcher SidebarFooter.tsx
        $sidebarFooter = "$agentDir\web\src\components\SidebarFooter.tsx"
        if (Test-Path $sidebarFooter) {
            $c = Get-Content $sidebarFooter -Raw -Encoding UTF8
            $c = $c -replace 'href="https://nousresearch\.com"', 'href="https://github.com/Tarzzan/HERMES-CHU"'
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($sidebarFooter, $c, $utf8NoBom)
            Write-Host "  [OK] Footer patche" -ForegroundColor Green
        }

        # 5. Patcher index.html (titre onglet)
        $indexHtmlPaths = @(
            "$agentDir\hermes_cli\web_dist\index.html",
            "$agentDir\web\index.html"
        )
        foreach ($ih in $indexHtmlPaths) {
            if (Test-Path $ih) {
                $c = Get-Content $ih -Raw -Encoding UTF8
                $c = $c -replace '<title>Hermes Agent.*?</title>', '<title>HERMES CHU — CHU de Guyane</title>'
                $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
                [System.IO.File]::WriteAllText($ih, $c, $utf8NoBom)
                Write-Host "  [OK] Titre HTML patche : $ih" -ForegroundColor Green
            }
        }
    }

    # Marquer le branding comme applique
    "CHU branding applied $(Get-Date -Format 'yyyy-MM-dd HH:mm')" | Out-File $brandingMarker -Encoding UTF8
    Write-Host "  [OK] Branding CHU applique !" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "[OK] Branding CHU deja applique" -ForegroundColor Green
}

# ============================================================
# --- Lancement de hermes dashboard ---
# ============================================================
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
