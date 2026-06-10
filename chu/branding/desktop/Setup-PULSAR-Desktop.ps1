# ============================================================
#  Setup-PULSAR-Desktop.ps1
#  Configuration complete de l'identite PULSAR sur Windows
#
#  Ce script realise en une seule execution :
#    1. Telechargement de l'icone PULSAR (.ico multi-taille)
#    2. Creation de la commande "pulsar" (alias de hermes)
#    3. Raccourcis Bureau + Menu Demarrer "PULSAR" avec icone
#    4. Compilation de l'app desktop Electron (optionnel)
#    5. Mise a jour du profil PowerShell (persistant)
#
#  DSIO - CHU de Guyane | William MERI
#  Version 2.0.0
# ============================================================

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

#  Couleurs console 
function Write-Header {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  PULSAR -- Setup complet identite Windows" -ForegroundColor Cyan
    Write-Host "  Systeme Agentique Medical | DSIO CHU de Guyane" -ForegroundColor DarkCyan
    Write-Host "  William MERI" -ForegroundColor DarkCyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}
function Write-Step { param([string]$msg) Write-Host "" ; Write-Host "[>>] $msg" -ForegroundColor Cyan }
function Write-OK   { param([string]$msg) Write-Host "     [OK] $msg" -ForegroundColor Green }
function Write-Warn { param([string]$msg) Write-Host "     [!!] $msg" -ForegroundColor Yellow }
function Write-Fail { param([string]$msg) Write-Host "     [XX] $msg" -ForegroundColor Red }

#  Chemins 
$HermesHome  = Join-Path $env:LOCALAPPDATA "hermes"
$AssetsDir   = Join-Path $HermesHome "pulsar-assets"
$IcoPath     = Join-Path $AssetsDir "pulsar.ico"
$PngPath     = Join-Path $AssetsDir "pulsar-icon-256.png"
$ProfileDir  = Split-Path $PROFILE -Parent
$ProfileFile = $PROFILE

# URLs CDN
$ICO_URL  = "https://raw.githubusercontent.com/Tarzzan/PULSAR-CHU/main/chu/branding/desktop/pulsar.ico"
$PNG_URL  = "https://raw.githubusercontent.com/Tarzzan/PULSAR-CHU/main/chu/branding/desktop/pulsar-icon-256.png"

Write-Header

#  1. Dossier assets 
Write-Step "Creation du dossier assets PULSAR..."
if (-not (Test-Path $AssetsDir)) {
    New-Item -ItemType Directory -Path $AssetsDir -Force | Out-Null
}
Write-OK "Dossier : $AssetsDir"

#  2. Telechargement icone 
Write-Step "Telechargement de l'icone PULSAR..."
try {
    Invoke-WebRequest -Uri $ICO_URL -OutFile $IcoPath -UseBasicParsing
    Write-OK "Icone .ico : $IcoPath"
} catch {
    Write-Warn "Echec CDN, tentative fallback GitHub..."
    try {
        $fallback = "https://files.manuscdn.com/user_upload_by_module/session_file/92503813/LQkFvrSnNGPgInko.ico"
        Invoke-WebRequest -Uri $fallback -OutFile $IcoPath -UseBasicParsing
        Write-OK "Icone .ico (fallback) : $IcoPath"
    } catch {
        Write-Warn "Icone non telechargee -- les raccourcis utiliseront l'icone par defaut"
        $IcoPath = $null
    }
}
try {
    Invoke-WebRequest -Uri $PNG_URL -OutFile $PngPath -UseBasicParsing
    Write-OK "Icone .png 256px : $PngPath"
} catch { Write-Warn "PNG non telecharge (non bloquant)" }

#  3. Alias "pulsar" dans le profil PowerShell 
Write-Step "Creation de la commande 'pulsar' (alias de hermes)..."

$aliasBlock = @'

# ============================================================
#  PULSAR -- Systeme Agentique Medical | DSIO CHU de Guyane
#  Alias pulsar -> hermes (toutes les sous-commandes)
# ============================================================
function pulsar {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
    if ($Args.Count -eq 0) {
        # Sans argument : afficher l'aide PULSAR
        Write-Host ""
        Write-Host "  PULSAR -- Systeme Agentique Medical" -ForegroundColor Cyan
        Write-Host "  DSIO -- CHU de Guyane | William MERI" -ForegroundColor DarkCyan
        Write-Host ""
        Write-Host "  Commandes disponibles :" -ForegroundColor White
        Write-Host "    pulsar dashboard    Interface web (http://localhost:9119)" -ForegroundColor Gray
        Write-Host "    pulsar desktop      Application native Electron" -ForegroundColor Gray
        Write-Host "    pulsar chat         Interface en ligne de commande" -ForegroundColor Gray
        Write-Host "    pulsar setup        Configurer le provider LLM" -ForegroundColor Gray
        Write-Host "    pulsar update       Mettre a jour PULSAR" -ForegroundColor Gray
        Write-Host "    pulsar --help       Aide complete" -ForegroundColor Gray
        Write-Host ""
        return
    }
    # Remplacer "pulsar dashboard" par l'ouverture auto du navigateur
    if ($Args[0] -eq "dashboard") {
        Write-Host ""
        Write-Host "  (P) PULSAR -- Demarrage interface web..." -ForegroundColor Cyan
        Write-Host "  Disponible sur : http://localhost:9119" -ForegroundColor DarkCyan
        Write-Host "  Ctrl+C pour arreter" -ForegroundColor Gray
        Write-Host ""
        # Ouvrir le navigateur apres 2 secondes
        $job = Start-Job -ScriptBlock {
            Start-Sleep -Seconds 2
            Start-Process "http://localhost:9119"
        }
        hermes dashboard
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        return
    }
    # Toutes les autres commandes : passer directement a hermes
    & hermes @Args
}

# Completion basique pour pulsar
Register-ArgumentCompleter -CommandName pulsar -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $cmds = @('dashboard','desktop','chat','setup','update','--help','--version',
              'model','secrets','gateway','portal','kanban','hooks','doctor',
              'skills','plugins','mcp','sessions','logs','config','profile')
    $cmds | Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}

'@

# Creer le dossier du profil si besoin
if (-not (Test-Path $ProfileDir)) {
    New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
}

# Verifier si l'alias existe deja
$profileContent = ""
if (Test-Path $ProfileFile) {
    $profileContent = Get-Content $ProfileFile -Raw -Encoding UTF8
}

if ($profileContent -match "function pulsar") {
    Write-OK "Alias 'pulsar' deja present dans le profil PowerShell"
    # Mettre a jour en remplacant le bloc existant
    $profileContent = $profileContent -replace "(s)# ={10,}.*PULSAR.*# ={10,}.*\n", ""
    $profileContent += $aliasBlock
    $profileContent | Out-File -FilePath $ProfileFile -Encoding UTF8 -NoNewline
    Write-OK "Alias 'pulsar' mis a jour"
} else {
    Add-Content -Path $ProfileFile -Value $aliasBlock -Encoding UTF8
    Write-OK "Alias 'pulsar' ajoute au profil : $ProfileFile"
}

# Charger l'alias dans la session courante
Invoke-Expression "function pulsar { param([Parameter(ValueFromRemainingArguments=`$true)][string[]]`$Args); if (`$Args.Count -eq 0) { Write-Host 'PULSAR -- Systeme Agentique Medical' -ForegroundColor Cyan; return }; & hermes @Args }"
Write-OK "Alias 'pulsar' actif dans cette session"

#  4. Raccourcis Bureau + Menu Demarrer 
Write-Step "Creation des raccourcis PULSAR (Bureau + Menu Demarrer)..."

# Trouver hermes.exe pour les raccourcis "dashboard" (via script de lancement)
$HermesExe = $null
$hermesCmd = Get-Command hermes -ErrorAction SilentlyContinue
if ($hermesCmd) { $HermesExe = $hermesCmd.Source }

# Creer le script de lancement PULSAR dashboard
$LaunchScript = Join-Path $AssetsDir "Launch-PULSAR.ps1"
@"
# PULSAR -- Lancement interface web
# DSIO CHU de Guyane | William MERI
`$host.UI.RawUI.WindowTitle = "PULSAR -- Systeme Agentique Medical"
Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Cyan
Write-Host "  PULSAR -- Systeme Agentique Medical" -ForegroundColor Cyan
Write-Host "  DSIO -- CHU de Guyane | William MERI" -ForegroundColor DarkCyan
Write-Host "  ============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Demarrage de l'interface web PULSAR..." -ForegroundColor White
Write-Host "  Disponible sur : http://localhost:9119" -ForegroundColor Cyan
Write-Host "  Ctrl+C pour arreter" -ForegroundColor Gray
Write-Host ""
# Ouvrir le navigateur apres 2 secondes
Start-Job -ScriptBlock { Start-Sleep 2; Start-Process "http://localhost:9119" } | Out-Null
# Recharger le PATH
`$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
# Lancer hermes dashboard
hermes dashboard
if (`$LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "  [!!] PULSAR s'est arrete avec le code : `$LASTEXITCODE" -ForegroundColor Yellow
    Write-Host "  Appuyez sur une touche pour fermer..." -ForegroundColor Gray
    `$null = `$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
"@ | Out-File -FilePath $LaunchScript -Encoding UTF8
Write-OK "Script de lancement : $LaunchScript"

# Icone a utiliser
$iconLocation = if ($IcoPath -and (Test-Path $IcoPath)) { "$IcoPath,0" } else { "" }

# Cibles des raccourcis
$shortcuts = @(
    @{
        Path        = Join-Path ([Environment]::GetFolderPath('Desktop')) 'PULSAR.lnk'
        Label       = "Bureau"
    },
    @{
        Path        = Join-Path ([Environment]::GetFolderPath('Programs')) 'PULSAR\PULSAR.lnk'
        Label       = "Menu Demarrer"
    }
)

$shell = New-Object -ComObject WScript.Shell

foreach ($s in $shortcuts) {
    try {
        $parent = Split-Path -Parent $s.Path
        if (-not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        $sc = $shell.CreateShortcut($s.Path)
        $sc.TargetPath       = "powershell.exe"
        $sc.Arguments        = "-ExecutionPolicy Bypass -WindowStyle Normal -File `"$LaunchScript`""
        $sc.WorkingDirectory = $AssetsDir
        $sc.Description      = "PULSAR -- Systeme Agentique Medical | DSIO CHU de Guyane"
        if ($iconLocation) { $sc.IconLocation = $iconLocation }
        $sc.Save()
        Write-OK "Raccourci $($s.Label) : $($s.Path)"
    } catch {
        Write-Warn "Raccourci $($s.Label) non cree : $($_.Exception.Message)"
    }
}

# Rafraichir le cache d'icones Windows
try { & ie4uinit.exe -show 2>$null } catch {}

#  5. Raccourci PULSAR Desktop (si Hermes.exe existe) 
Write-Step "Recherche de l'application desktop Electron..."

$desktopExePaths = @(
    (Join-Path $HermesHome "hermes-agent\apps\desktop\release\win-unpacked\Hermes.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\Hermes\Hermes.exe"),
    (Join-Path $env:APPDATA "Hermes\Hermes.exe")
)

$desktopExe = $null
foreach ($p in $desktopExePaths) {
    if (Test-Path $p) { $desktopExe = $p; break }
}

if ($desktopExe) {
    Write-OK "App desktop trouvee : $desktopExe"

    # Remplacer l'icone dans resources/icon.ico si possible
    $resourcesDir = Join-Path (Split-Path -Parent $desktopExe) "resources"
    if ((Test-Path $resourcesDir) -and $IcoPath -and (Test-Path $IcoPath)) {
        try {
            Copy-Item $IcoPath (Join-Path $resourcesDir "icon.ico") -Force
            Write-OK "Icone PULSAR installee dans resources/icon.ico"
        } catch {
            Write-Warn "Impossible de remplacer l'icone dans resources : $($_.Exception.Message)"
        }
    }

    # Raccourci PULSAR Desktop
    $desktopShortcutPaths = @(
        (Join-Path ([Environment]::GetFolderPath('Desktop')) 'PULSAR Desktop.lnk'),
        (Join-Path ([Environment]::GetFolderPath('Programs')) 'PULSAR\PULSAR Desktop.lnk')
    )
    foreach ($lnkPath in $desktopShortcutPaths) {
        try {
            $parent = Split-Path -Parent $lnkPath
            if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
            $sc = $shell.CreateShortcut($lnkPath)
            $sc.TargetPath       = $desktopExe
            $sc.WorkingDirectory = Split-Path -Parent $desktopExe
            $sc.Description      = "PULSAR Desktop -- Application native | DSIO CHU de Guyane"
            if ($iconLocation) { $sc.IconLocation = $iconLocation }
            $sc.Save()
            Write-OK "Raccourci PULSAR Desktop : $lnkPath"
        } catch {
            Write-Warn "Raccourci Desktop non cree : $($_.Exception.Message)"
        }
    }
    try { & ie4uinit.exe -show 2>$null } catch {}
} else {
    Write-Warn "App desktop Electron non trouvee."
    Write-Host "     Pour l'installer, executez dans PowerShell :" -ForegroundColor Gray
    Write-Host "     hermes desktop --build-only" -ForegroundColor White
    Write-Host "     (necessite Node.js >= 20.19 et ~150 Mo d'espace)" -ForegroundColor Gray
}

#  Recapitulatif 
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  PULSAR -- Configuration terminee !" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Commandes disponibles (ouvrez un nouveau PowerShell) :" -ForegroundColor White
Write-Host ""
Write-Host "    pulsar               Afficher l'aide PULSAR" -ForegroundColor Cyan
Write-Host "    pulsar dashboard     Interface web (port 9119)" -ForegroundColor Cyan
Write-Host "    pulsar desktop       Application native Electron" -ForegroundColor Cyan
Write-Host "    pulsar chat          Interface CLI" -ForegroundColor Cyan
Write-Host "    pulsar setup         Reconfigurer le provider LLM" -ForegroundColor Cyan
Write-Host "    pulsar update        Mettre a jour" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Raccourcis crees :" -ForegroundColor White
Write-Host "    Bureau    : PULSAR.lnk" -ForegroundColor Gray
Write-Host "    Menu Dem. : PULSAR\PULSAR.lnk" -ForegroundColor Gray
Write-Host ""
Write-Host "  Icone : $IcoPath" -ForegroundColor Gray
Write-Host "  Profil PowerShell mis a jour : $ProfileFile" -ForegroundColor Gray
Write-Host ""
Write-Host "  IMPORTANT : Ouvrez un nouveau PowerShell pour utiliser 'pulsar'" -ForegroundColor Yellow
Write-Host ""
