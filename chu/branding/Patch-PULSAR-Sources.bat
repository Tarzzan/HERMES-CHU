@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

echo.
echo ============================================================
echo   PULSAR -- Patch Sources TypeScript
echo   DSIO CHU de Guyane -- William MERI
echo ============================================================
echo.
echo Ce script patche les sources hermes-agent pour que le
echo dashboard affiche l'identite PULSAR apres rebuild.
echo.

:: ── Trouver le dossier hermes-agent ──────────────────────────
set "HERMES_DIR=%LOCALAPPDATA%\hermes\hermes-agent"
if not exist "%HERMES_DIR%" (
    :: Chercher via pip
    for /f "tokens=*" %%i in ('python -c "import hermes_cli, os; print(os.path.dirname(os.path.dirname(hermes_cli.__file__)))" 2^>nul') do set "HERMES_DIR=%%i"
)
if not exist "%HERMES_DIR%" (
    :: Chercher dans le venv
    for /f "tokens=*" %%i in ('python -c "import site; print(site.getsitepackages()[0])" 2^>nul') do (
        if exist "%%i\hermes_cli" set "HERMES_DIR=%%i"
    )
)
if not exist "%HERMES_DIR%" (
    :: Chercher via where hermes
    for /f "tokens=*" %%i in ('where hermes 2^>nul') do (
        set "HERMES_EXE=%%i"
    )
    if defined HERMES_EXE (
        for %%i in ("!HERMES_EXE!") do set "HERMES_DIR=%%~dpi.."
    )
)

echo [INFO] Recherche hermes-agent...

:: Chercher le dossier web/src dans les emplacements courants
set "WEB_SRC="
for %%p in (
    "%LOCALAPPDATA%\hermes\hermes-agent\web\src"
    "%USERPROFILE%\.hermes\hermes-agent\web\src"
    "%APPDATA%\hermes\hermes-agent\web\src"
    "%LOCALAPPDATA%\Programs\hermes\hermes-agent\web\src"
) do (
    if exist "%%~p" set "WEB_SRC=%%~p"
)

:: Chercher via Python
if not defined WEB_SRC (
    for /f "tokens=*" %%i in ('python -c "import hermes_cli, os; p=os.path.join(os.path.dirname(os.path.dirname(hermes_cli.__file__)), 'web', 'src'); print(p)" 2^>nul') do (
        if exist "%%i" set "WEB_SRC=%%i"
    )
)

if not defined WEB_SRC (
    echo [ERREUR] Impossible de trouver les sources web hermes-agent.
    echo.
    echo Cherchez manuellement le dossier contenant web\src\index.css
    echo et relancez ce script avec la variable WEB_SRC definie :
    echo   set WEB_SRC=C:\chemin\vers\hermes-agent\web\src
    echo   Patch-PULSAR-Sources.bat
    pause
    exit /b 1
)

echo [OK] Sources trouvees : %WEB_SRC%
echo.

:: ── Sauvegarde ───────────────────────────────────────────────
set "BACKUP_DIR=%LOCALAPPDATA%\hermes\pulsar-backup"
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

echo [1/6] Sauvegarde des fichiers originaux...
if exist "%WEB_SRC%\index.css" copy /y "%WEB_SRC%\index.css" "%BACKUP_DIR%\index.css.bak" >nul
if exist "%WEB_SRC%\themes\presets.ts" copy /y "%WEB_SRC%\themes\presets.ts" "%BACKUP_DIR%\presets.ts.bak" >nul
if exist "%WEB_SRC%\i18n\fr.ts" copy /y "%WEB_SRC%\i18n\fr.ts" "%BACKUP_DIR%\fr.ts.bak" >nul
if exist "%WEB_SRC%\i18n\en.ts" copy /y "%WEB_SRC%\i18n\en.ts" "%BACKUP_DIR%\en.ts.bak" >nul
if exist "%WEB_SRC%\components\SidebarFooter.tsx" copy /y "%WEB_SRC%\components\SidebarFooter.tsx" "%BACKUP_DIR%\SidebarFooter.tsx.bak" >nul
echo [OK] Sauvegarde dans %BACKUP_DIR%

:: ── Patch via Python (plus fiable que sed sur Windows) ───────
echo [2/6] Patch index.html (titre onglet)...
set "INDEX_HTML=%WEB_SRC%\..\index.html"
python -c "
import sys
path = r'%INDEX_HTML%'
try:
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    content = content.replace(
        '<title>Hermes Agent - Dashboard</title>',
        '<title>PULSAR -- Systeme Agentique Medical | DSIO CHU de Guyane</title>'
    )
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print('[OK] index.html patche')
except Exception as e:
    print('[WARN] index.html:', e)
" 2>&1

echo [3/6] Patch i18n/fr.ts (branding francais)...
python -c "
import sys
path = r'%WEB_SRC%\i18n\fr.ts'
try:
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    content = content.replace('brand: \"Hermes Agent\"', 'brand: \"PULSAR\"')
    content = content.replace('brandShort: \"HA\"', 'brandShort: \"PSR\"')
    content = content.replace('org: \"Nous Research\"', 'org: \"DSIO CHU de Guyane\"')
    content = content.replace('\"Hermes Agent\"', '\"PULSAR\"')
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print('[OK] fr.ts patche')
except Exception as e:
    print('[WARN] fr.ts:', e)
" 2>&1

echo [4/6] Patch i18n/en.ts (branding anglais)...
python -c "
import sys
path = r'%WEB_SRC%\i18n\en.ts'
try:
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    content = content.replace('brand: \"Hermes Agent\"', 'brand: \"PULSAR\"')
    content = content.replace('brandShort: \"HA\"', 'brandShort: \"PSR\"')
    content = content.replace('org: \"Nous Research\"', 'org: \"DSIO CHU de Guyane\"')
    content = content.replace('\"Hermes Agent\"', '\"PULSAR\"')
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print('[OK] en.ts patche')
except Exception as e:
    print('[WARN] en.ts:', e)
" 2>&1

echo [5/6] Patch SidebarFooter.tsx (lien footer)...
python -c "
import sys
path = r'%WEB_SRC%\components\SidebarFooter.tsx'
try:
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    content = content.replace(
        'href=\"https://nousresearch.com\"',
        'href=\"https://github.com/Tarzzan/PULSAR-CHU\"'
    )
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print('[OK] SidebarFooter.tsx patche')
except Exception as e:
    print('[WARN] SidebarFooter.tsx:', e)
" 2>&1

echo [6/6] Patch themes/presets.ts (theme PULSAR natif)...
python -c "
import sys
path = r'%WEB_SRC%\themes\presets.ts'
try:
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    # Remplacer le theme default (Hermes Teal) par PULSAR
    content = content.replace(
        'label: \"Hermes Teal\"',
        'label: \"PULSAR\"'
    )
    content = content.replace(
        'description: \"Classic dark teal -- the canonical Hermes look\"',
        'description: \"PULSAR -- Systeme Agentique Medical | DSIO CHU de Guyane\"'
    )
    # Remplacer la palette du theme default par les couleurs PULSAR
    # background: teal fonce -> bleu nuit medical
    content = content.replace(
        'background: { hex: \"#041c1c\", alpha: 1 },\n    midground: { hex: \"#ffe6cb\", alpha: 1 },\n    foreground: { hex: \"#ffffff\", alpha: 0 },\n    warmGlow: \"rgba(255, 189, 56, 0.35)\",\n    noiseOpacity: 1,',
        'background: { hex: \"#020d1a\", alpha: 1 },\n    midground: { hex: \"#00d4ff\", alpha: 1 },\n    foreground: { hex: \"#ffffff\", alpha: 0 },\n    warmGlow: \"rgba(0, 180, 216, 0.25)\",\n    noiseOpacity: 0.6,'
    )
    # Remplacer aussi dans index.css les variables par defaut
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print('[OK] presets.ts patche')
except Exception as e:
    print('[WARN] presets.ts:', e)
" 2>&1

:: ── Patch index.css variables CSS de base ───────────────────
echo [BONUS] Patch index.css (variables CSS racine)...
python -c "
import sys
path = r'%WEB_SRC%\index.css'
try:
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    # Remplacer les couleurs de base du theme default dans :root
    content = content.replace(
        '--midground: color-mix(in srgb, #ffe6cb 100%, transparent);',
        '--midground: color-mix(in srgb, #00d4ff 100%, transparent);'
    )
    content = content.replace(
        '--midground-base: #ffe6cb;',
        '--midground-base: #00d4ff;'
    )
    content = content.replace(
        '--background: color-mix(in srgb, #041c1c 100%, transparent);',
        '--background: color-mix(in srgb, #020d1a 100%, transparent);'
    )
    content = content.replace(
        '--background-base: #041c1c;',
        '--background-base: #020d1a;'
    )
    content = content.replace(
        '--warm-glow: rgba(255, 189, 56, 0.35);',
        '--warm-glow: rgba(0, 180, 216, 0.25);'
    )
    content = content.replace(
        '--series-input-token: #ffe6cb;',
        '--series-input-token: #00d4ff;'
    )
    content = content.replace(
        '--series-output-token: #34d399;',
        '--series-output-token: #00e5a0;'
    )
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print('[OK] index.css patche')
except Exception as e:
    print('[WARN] index.css:', e)
" 2>&1

:: ── Patch banner.py (Nous Research -> DSIO CHU de Guyane) ────
echo [BONUS] Patch banner.py (Nous Research -> DSIO CHU de Guyane)...
for /f "tokens=*" %%i in ('python -c "import hermes_cli, os; print(os.path.join(os.path.dirname(hermes_cli.__file__), 'banner.py'))" 2^>nul') do set "BANNER_PY=%%i"
if defined BANNER_PY (
    python -c "
path = r'%BANNER_PY%'
try:
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    content = content.replace('Nous Research', 'DSIO CHU de Guyane')
    content = content.replace('NousResearch', 'DSIO CHU de Guyane')
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print('[OK] banner.py patche')
except Exception as e:
    print('[WARN] banner.py:', e)
" 2>&1
)

:: ── Patch skin_engine.py (default skin -> PULSAR) ────────────
echo [BONUS] Patch skin_engine.py (skin default -> PULSAR)...
for /f "tokens=*" %%i in ('python -c "import hermes_cli, os; print(os.path.join(os.path.dirname(hermes_cli.__file__), 'skin_engine.py'))" 2^>nul') do set "SKIN_PY=%%i"
if defined SKIN_PY (
    python -c "
path = r'%SKIN_PY%'
try:
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    content = content.replace('\"agent_name\": \"Hermes Agent\"', '\"agent_name\": \"PULSAR\"')
    content = content.replace('\"Welcome to Hermes Agent!', '\"Bienvenue sur PULSAR -- DSIO CHU de Guyane!')
    content = content.replace('\" ⚕ Hermes \"', '\" ⚕ PULSAR \"')
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print('[OK] skin_engine.py patche')
except Exception as e:
    print('[WARN] skin_engine.py:', e)
" 2>&1
)

:: ── Rebuild du dashboard ─────────────────────────────────────
echo.
echo ============================================================
echo   Patches appliques. Rebuild du dashboard...
echo ============================================================
echo.

:: Trouver le dossier web (parent de web/src)
for %%i in ("%WEB_SRC%\..") do set "WEB_DIR=%%~fi"

if not exist "%WEB_DIR%\package.json" (
    echo [WARN] package.json non trouve dans %WEB_DIR%
    echo Le rebuild doit etre fait manuellement :
    echo   cd %WEB_DIR%
    echo   npm run build
    goto :done
)

echo [BUILD] Installation des dependances npm...
cd /d "%WEB_DIR%"
call npm install --silent 2>&1 | findstr /v "warn\|npm notice"

echo [BUILD] Compilation Vite (peut prendre 1-2 minutes)...
call npm run build 2>&1
if errorlevel 1 (
    echo [ERREUR] Le build a echoue. Verifiez les erreurs ci-dessus.
    goto :done
)

echo.
echo [OK] Build termine avec succes !

:done
echo.
echo ============================================================
echo   PULSAR -- Patch complet
echo ============================================================
echo.
echo   Couleurs : bleu nuit medical + cyan electrique
echo   Titre    : PULSAR -- Systeme Agentique Medical
echo   Footer   : DSIO CHU de Guyane
echo   Banner   : PULSAR (CLI)
echo.
echo   Lancez : pulsar dashboard
echo   Puis rechargez le navigateur (Ctrl+F5)
echo.
pause
