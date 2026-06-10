@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

echo.
echo ============================================================
echo   PULSAR -- Patch Identite Desktop Electron
echo   DSIO -- CHU de Guyane  ^|  William MERI
echo ============================================================
echo.

:: --- Localiser hermes-agent sur la machine ---
set "HERMES_BIN="
for /f "delims=" %%i in ('where hermes 2^>nul') do set "HERMES_BIN=%%i"

if "%HERMES_BIN%"=="" (
    echo [ERREUR] Commande hermes introuvable dans le PATH.
    echo         Assurez-vous que hermes-agent est installe.
    pause
    exit /b 1
)

:: PROJECT_ROOT = dossier parent de hermes_cli (qui contient hermes.exe)
:: Sur Windows : %LOCALAPPDATA%\hermes\hermes-agent\
for %%i in ("%HERMES_BIN%") do set "VENV_BIN=%%~dpi"
:: VENV_BIN = ..\venv\Scripts\  -> remonter pour trouver hermes-agent
set "HERMES_AGENT_DIR=%VENV_BIN%..\..\.."
pushd "%HERMES_AGENT_DIR%"
set "HERMES_AGENT_DIR=%CD%"
popd

set "DESKTOP_DIR=%HERMES_AGENT_DIR%\apps\desktop"
set "ELECTRON_DIR=%DESKTOP_DIR%\electron"
set "PKG_JSON=%DESKTOP_DIR%\package.json"

echo [INFO] hermes-agent : %HERMES_AGENT_DIR%
echo [INFO] apps/desktop  : %DESKTOP_DIR%

if not exist "%DESKTOP_DIR%" (
    echo [WARN] Le dossier apps/desktop n'existe pas encore.
    echo        Lancez d'abord : hermes desktop --build-only
    echo        Puis relancez ce script.
    pause
    exit /b 1
)

echo.
echo [1/6] Patch package.json -- nom et description PULSAR...
if exist "%PKG_JSON%" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$c = Get-Content '%PKG_JSON%' -Raw | ConvertFrom-Json; " ^
        "$c.name = 'pulsar-dsio-chu'; " ^
        "$c.productName = 'PULSAR'; " ^
        "$c.description = 'Plateforme Unifiee de Liaison, de Surveillance et d Assistance en temps Reel -- DSIO CHU de Guyane'; " ^
        "$c.author = 'William MERI -- DSIO CHU de Guyane'; " ^
        "$c | ConvertTo-Json -Depth 20 | Set-Content '%PKG_JSON%' -Encoding UTF8"
    echo [OK] package.json patche
) else (
    echo [SKIP] package.json introuvable
)

echo.
echo [2/6] Patch electron/main.cjs -- titre de fenetre PULSAR...
set "MAIN_CJS=%ELECTRON_DIR%\main.cjs"
if exist "%MAIN_CJS%" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$c = Get-Content '%MAIN_CJS%' -Raw; " ^
        "$c = $c -replace 'Hermes Agent', 'PULSAR'; " ^
        "$c = $c -replace 'Hermes Desktop', 'PULSAR -- DSIO CHU de Guyane'; " ^
        "$c = $c -replace 'hermes-agent', 'pulsar-dsio'; " ^
        "$c = $c -replace 'title: .Hermes.', 'title: ''PULSAR'''; " ^
        "Set-Content '%MAIN_CJS%' $c -Encoding UTF8"
    echo [OK] main.cjs patche
) else (
    echo [SKIP] electron/main.cjs introuvable
)

echo.
echo [3/6] Patch icone -- remplacement par icone PULSAR...
set "PULSAR_ICO=%LOCALAPPDATA%\hermes\pulsar-assets\pulsar.ico"
set "RESOURCES_DIR=%DESKTOP_DIR%\resources"
if not exist "%RESOURCES_DIR%" mkdir "%RESOURCES_DIR%"

:: Telecharger l'icone PULSAR si absente
if not exist "%PULSAR_ICO%" (
    echo [INFO] Telechargement icone PULSAR...
    curl -sL "https://raw.githubusercontent.com/Tarzzan/HERMES-CHU/main/chu/branding/desktop/pulsar.ico" ^
         -o "%PULSAR_ICO%" 2>nul
)

if exist "%PULSAR_ICO%" (
    copy /y "%PULSAR_ICO%" "%RESOURCES_DIR%\icon.ico" >nul 2>&1
    copy /y "%PULSAR_ICO%" "%RESOURCES_DIR%\icon.png" >nul 2>&1
    copy /y "%PULSAR_ICO%" "%DESKTOP_DIR%\icon.ico" >nul 2>&1
    echo [OK] Icone PULSAR installee
) else (
    echo [WARN] Icone PULSAR non disponible -- icone par defaut conservee
)

echo.
echo [4/6] Patch index.html -- titre onglet PULSAR...
set "INDEX_HTML=%DESKTOP_DIR%\src\index.html"
if not exist "%INDEX_HTML%" set "INDEX_HTML=%DESKTOP_DIR%\index.html"
if exist "%INDEX_HTML%" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$c = Get-Content '%INDEX_HTML%' -Raw; " ^
        "$c = $c -replace '<title>.*?</title>', '<title>PULSAR -- DSIO CHU de Guyane</title>'; " ^
        "Set-Content '%INDEX_HTML%' $c -Encoding UTF8"
    echo [OK] index.html patche
) else (
    echo [SKIP] index.html introuvable
)

echo.
echo [5/6] Patch electron-builder config -- nom binaire PULSAR...
set "BUILDER_YML=%DESKTOP_DIR%\electron-builder.yml"
set "BUILDER_JSON=%DESKTOP_DIR%\electron-builder.json"
if exist "%BUILDER_YML%" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$c = Get-Content '%BUILDER_YML%' -Raw; " ^
        "$c = $c -replace 'productName:.*', 'productName: PULSAR'; " ^
        "$c = $c -replace 'appId:.*', 'appId: fr.chu-guyane.pulsar'; " ^
        "$c = $c -replace 'copyright:.*', 'copyright: DSIO CHU de Guyane -- William MERI'; " ^
        "Set-Content '%BUILDER_YML%' $c -Encoding UTF8"
    echo [OK] electron-builder.yml patche
)
if exist "%BUILDER_JSON%" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$c = Get-Content '%BUILDER_JSON%' -Raw | ConvertFrom-Json; " ^
        "$c.productName = 'PULSAR'; " ^
        "$c.appId = 'fr.chu-guyane.pulsar'; " ^
        "$c.copyright = 'DSIO CHU de Guyane -- William MERI'; " ^
        "$c | ConvertTo-Json -Depth 20 | Set-Content '%BUILDER_JSON%' -Encoding UTF8"
    echo [OK] electron-builder.json patche
)

echo.
echo [6/6] Mise a jour du raccourci PULSAR Desktop...
set "SHORTCUT=%USERPROFILE%\Desktop\PULSAR Desktop.lnk"
set "LAUNCH_SCRIPT=%LOCALAPPDATA%\hermes\bin\pulsar-desktop.bat"

:: Creer le script de lancement desktop
(
    echo @echo off
    echo title PULSAR Desktop -- DSIO CHU de Guyane
    echo echo Demarrage de PULSAR Desktop...
    echo hermes desktop
) > "%LAUNCH_SCRIPT%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ws = New-Object -ComObject WScript.Shell; " ^
    "$s = $ws.CreateShortcut('%SHORTCUT%'); " ^
    "$s.TargetPath = '%LAUNCH_SCRIPT%'; " ^
    "$s.Description = 'PULSAR -- Systeme Agentique Medical -- DSIO CHU de Guyane'; " ^
    "$s.WorkingDirectory = '%USERPROFILE%'; " ^
    "if (Test-Path '%PULSAR_ICO%') { $s.IconLocation = '%PULSAR_ICO%' }; " ^
    "$s.Save()"
echo [OK] Raccourci PULSAR Desktop mis a jour

echo.
echo ============================================================
echo   Patch PULSAR Desktop termine !
echo.
echo   Relancez maintenant : hermes desktop --force-build
echo   pour recompiler avec l'identite PULSAR.
echo ============================================================
echo.
pause
