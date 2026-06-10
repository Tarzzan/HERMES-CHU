# ============================================================
# HERMES CHU -- Script de personnalisation de l'interface
# Concu par William MERI -- CHU de Guyane
# Applique le branding CHU sur hermes-agent NousResearch
# ============================================================
# Usage : powershell -ExecutionPolicy Bypass -File Apply-CHU-Branding.ps1
# ============================================================

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "HERMES CHU - Application du branding"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  HERMES CHU -- Application du branding hospitalier" -ForegroundColor Cyan
Write-Host "  CHU de Guyane | William MERI | github: Tarzzan" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# --- Trouver le dossier d'installation hermes ---
$hermesPaths = @(
    "$env:LOCALAPPDATA\hermes\hermes-agent",
    "$env:LOCALAPPDATA\hermes\hermes-chu",
    "$env:USERPROFILE\.hermes\hermes-agent"
)

$hermesRoot = $null
foreach ($p in $hermesPaths) {
    if (Test-Path "$p\hermes_cli") {
        $hermesRoot = $p
        break
    }
}

if (-not $hermesRoot) {
    # Chercher via la commande hermes
    $hermesCmd = Get-Command hermes -ErrorAction SilentlyContinue
    if ($hermesCmd) {
        $hermesRoot = Split-Path (Split-Path $hermesCmd.Source)
        # Remonter jusqu'au dossier contenant hermes_cli
        $candidate = $hermesRoot
        for ($i = 0; $i -lt 4; $i++) {
            if (Test-Path "$candidate\hermes_cli") {
                $hermesRoot = $candidate
                break
            }
            $candidate = Split-Path $candidate
        }
    }
}

if (-not $hermesRoot -or -not (Test-Path "$hermesRoot\hermes_cli")) {
    Write-Host "[ERREUR] Dossier hermes-agent introuvable." -ForegroundColor Red
    Write-Host "Chemins tries :" -ForegroundColor Yellow
    foreach ($p in $hermesPaths) { Write-Host "  $p" -ForegroundColor Gray }
    Read-Host "Appuyez sur Entree pour fermer"
    exit 1
}

Write-Host "[OK] Hermes trouve : $hermesRoot" -ForegroundColor Green
Write-Host ""

# ============================================================
# 1. Copier le skin CHU dans le dossier des skins hermes
# ============================================================
Write-Host "[1/6] Installation du skin CHU..." -ForegroundColor Cyan

$hermesHome = "$env:LOCALAPPDATA\hermes"
$skinsDir = "$hermesHome\skins"
New-Item -ItemType Directory -Force -Path $skinsDir | Out-Null

$skinSource = Join-Path $PSScriptRoot "chu-guyane.yaml"
if (-not (Test-Path $skinSource)) {
    # Telecharger depuis GitHub si absent
    Write-Host "  Telechargement du skin depuis GitHub..." -ForegroundColor Gray
    try {
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Tarzzan/PULSAR-CHU/main/chu/branding/chu-guyane.yaml" `
            -OutFile "$skinsDir\chu-guyane.yaml" -UseBasicParsing
        Write-Host "  [OK] Skin telecharge" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Impossible de telecharger le skin : $_" -ForegroundColor Yellow
    }
} else {
    Copy-Item $skinSource "$skinsDir\chu-guyane.yaml" -Force
    Write-Host "  [OK] Skin copie : $skinsDir\chu-guyane.yaml" -ForegroundColor Green
}

# ============================================================
# 2. Modifier web/index.html -- titre de la page
# ============================================================
Write-Host "[2/6] Modification du titre de la page web..." -ForegroundColor Cyan

$indexHtml = "$hermesRoot\hermes_cli\web_dist\index.html"
if (-not (Test-Path $indexHtml)) {
    # Chercher dans les dossiers alternatifs
    $candidates = @(
        "$hermesRoot\web\index.html",
        "$hermesRoot\hermes_cli\web\index.html"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $indexHtml = $c; break }
    }
}

if (Test-Path $indexHtml) {
    $content = Get-Content $indexHtml -Raw -Encoding UTF8
    $newContent = $content -replace '<title>.*?</title>', '<title>HERMES CHU -- CHU de Guyane</title>'
    Set-Content $indexHtml $newContent -Encoding UTF8 -NoNewline
    Write-Host "  [OK] Titre modifie : $indexHtml" -ForegroundColor Green
} else {
    Write-Host "  [INFO] index.html non trouve (sera modifie lors du build)" -ForegroundColor Yellow
}

# ============================================================
# 3. Modifier les fichiers i18n (fr.ts et en.ts) -- brand et footer
# ============================================================
Write-Host "[3/6] Modification des fichiers de traduction..." -ForegroundColor Cyan

$i18nFiles = @(
    "$hermesRoot\web\src\i18n\fr.ts",
    "$hermesRoot\web\src\i18n\en.ts"
)

foreach ($f in $i18nFiles) {
    if (Test-Path $f) {
        $content = Get-Content $f -Raw -Encoding UTF8
        # Remplacer brand
        $content = $content -replace 'brand:\s*"Hermes Agent"', 'brand: "HERMES CHU"'
        $content = $content -replace "brand:\s*'Hermes Agent'", "brand: 'HERMES CHU'"
        # Remplacer brandShort
        $content = $content -replace 'brandShort:\s*"HA"', 'brandShort: "CHU"'
        $content = $content -replace "brandShort:\s*'HA'", "brandShort: 'CHU'"
        # Remplacer footer.org
        $content = $content -replace 'org:\s*"Nous Research"', 'org: "William MERI - CHU de Guyane"'
        $content = $content -replace "org:\s*'Nous Research'", "org: 'William MERI - CHU de Guyane'"
        Set-Content $f $content -Encoding UTF8 -NoNewline
        Write-Host "  [OK] Modifie : $f" -ForegroundColor Green
    } else {
        Write-Host "  [INFO] Non trouve : $f" -ForegroundColor Yellow
    }
}

# ============================================================
# 4. Modifier SidebarFooter.tsx -- lien et texte du footer
# ============================================================
Write-Host "[4/6] Modification du footer de la sidebar..." -ForegroundColor Cyan

$sidebarFooter = "$hermesRoot\web\src\components\SidebarFooter.tsx"
if (Test-Path $sidebarFooter) {
    $content = Get-Content $sidebarFooter -Raw -Encoding UTF8
    # Remplacer le lien nousresearch.com par le lien GitHub CHU
    $content = $content -replace 'href="https://nousresearch\.com"', 'href="https://github.com/Tarzzan/PULSAR-CHU"'
    # Remplacer target="_blank" rel="noopener noreferrer" (garder)
    Set-Content $sidebarFooter $content -Encoding UTF8 -NoNewline
    Write-Host "  [OK] Modifie : $sidebarFooter" -ForegroundColor Green
} else {
    Write-Host "  [INFO] Non trouve : $sidebarFooter" -ForegroundColor Yellow
}

# ============================================================
# 5. Modifier config.yaml hermes -- activer le skin CHU
# ============================================================
Write-Host "[5/6] Activation du skin CHU dans config.yaml..." -ForegroundColor Cyan

$configPaths = @(
    "$env:LOCALAPPDATA\hermes\config.yaml",
    "$env:USERPROFILE\.hermes\config.yaml",
    "$hermesRoot\config.yaml"
)

$configFound = $false
foreach ($configPath in $configPaths) {
    if (Test-Path $configPath) {
        $configFound = $true
        $content = Get-Content $configPath -Raw -Encoding UTF8

        # Vérifier si display.skin existe déjà
        if ($content -match "skin:\s*chu-guyane") {
            Write-Host "  [OK] Skin CHU deja active dans : $configPath" -ForegroundColor Green
        } elseif ($content -match "display:") {
            # Modifier le skin existant
            $content = $content -replace '(display:.*?skin:\s*)[\w-]+', '${1}chu-guyane'
            if ($content -notmatch "skin:\s*chu-guyane") {
                # Ajouter skin sous display:
                $content = $content -replace '(display:)', "`$1`n  skin: chu-guyane"
            }
            Set-Content $configPath $content -Encoding UTF8 -NoNewline
            Write-Host "  [OK] Skin CHU active dans : $configPath" -ForegroundColor Green
        } else {
            # Ajouter la section display à la fin
            $content = $content.TrimEnd()
            $content += "`n`n# Branding CHU de Guyane`ndisplay:`n  skin: chu-guyane`n"
            Set-Content $configPath $content -Encoding UTF8 -NoNewline
            Write-Host "  [OK] Section display ajoutee dans : $configPath" -ForegroundColor Green
        }
        break
    }
}

if (-not $configFound) {
    Write-Host "  [INFO] config.yaml non trouve -- le skin sera active au prochain hermes setup" -ForegroundColor Yellow
}

# ============================================================
# 6. Rebuild du dashboard web (si Node.js disponible)
# ============================================================
Write-Host "[6/6] Rebuild du dashboard web..." -ForegroundColor Cyan

$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
$npmCmd = Get-Command npm -ErrorAction SilentlyContinue
$webDir = "$hermesRoot\web"

if ($nodeCmd -and $npmCmd -and (Test-Path "$webDir\package.json")) {
    Write-Host "  Node.js trouve -- lancement du build..." -ForegroundColor Gray
    Write-Host "  (Cette etape peut prendre 2-5 minutes)" -ForegroundColor Gray
    try {
        Push-Location $webDir
        $buildResult = & npm run build 2>&1
        Pop-Location
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Dashboard rebuild avec succes !" -ForegroundColor Green
            Write-Host "  Redemarrez HERMES CHU pour voir les changements." -ForegroundColor Cyan
        } else {
            Write-Host "  [WARN] Build echoue (code $LASTEXITCODE)" -ForegroundColor Yellow
            Write-Host "  Les modifications de texte seront visibles apres le prochain build automatique." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  [WARN] Erreur build : $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [INFO] Node.js absent ou dossier web non trouve." -ForegroundColor Yellow
    Write-Host "  Les modifications de texte seront visibles apres le prochain build." -ForegroundColor Yellow
    Write-Host "  Le skin CLI (couleurs, banner, messages) est actif immediatement." -ForegroundColor Green
}

# ============================================================
# Résumé
# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Branding CHU applique avec succes !" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Modifications appliquees :" -ForegroundColor Cyan
Write-Host "  [OK] Skin CHU installe : $skinsDir\chu-guyane.yaml" -ForegroundColor White
Write-Host "  [OK] Couleurs bleues medicales CHU" -ForegroundColor White
Write-Host "  [OK] Banner : HERMES CHU -- CHU de Guyane" -ForegroundColor White
Write-Host "  [OK] Footer : William MERI - CHU de Guyane" -ForegroundColor White
Write-Host "  [OK] Titre page web : HERMES CHU -- CHU de Guyane" -ForegroundColor White
Write-Host ""
Write-Host "Pour voir les changements :" -ForegroundColor Yellow
Write-Host "  1. Fermez hermes dashboard (Ctrl+C)" -ForegroundColor White
Write-Host "  2. Relancez : hermes dashboard" -ForegroundColor White
Write-Host ""
Write-Host "Concu par William MERI -- CHU de Guyane" -ForegroundColor Cyan
Write-Host "https://github.com/Tarzzan/PULSAR-CHU" -ForegroundColor Gray
Write-Host ""
Read-Host "Appuyez sur Entree pour fermer"
