@echo off
chcp 65001 >nul
title PULSAR — Mise à jour v3.0

echo.
echo  ╔══════════════════════════════════════════════════════╗
echo  ║         PULSAR — Mise à jour automatique             ║
echo  ║         DSIO - CHU de Guyane                         ║
echo  ╚══════════════════════════════════════════════════════╝
echo.

set PULSAR_HOME=%LOCALAPPDATA%\hermes\hermes-chu

:: Vérifier que l'installation existe
if not exist "%PULSAR_HOME%" (
    echo [ERREUR] PULSAR n'est pas installe dans %PULSAR_HOME%
    echo Lancez d'abord PULSAR-Setup-2.3.0.exe
    pause
    exit /b 1
)

:: Arrêter le serveur PULSAR s'il tourne
echo [1/5] Arret du serveur PULSAR en cours...
taskkill /F /IM pulsar.exe 2>nul
taskkill /F /IM python.exe /FI "WINDOWTITLE eq PULSAR*" 2>nul
timeout /t 2 /nobreak >nul

:: Git pull
echo [2/5] Recuperation des dernières mises a jour depuis GitHub...
cd /d "%PULSAR_HOME%"
git pull origin main
if %errorlevel% neq 0 (
    echo [AVERTISSEMENT] git pull a echoue. Verifiez votre connexion.
    echo La mise a jour continue avec les sources locales...
)

:: Copier le web_dist pre-compile depuis le depot
echo [3/5] Mise a jour de l'interface web...
if exist "%PULSAR_HOME%\upstream\hermes-agent\hermes_cli\web_dist" (
    xcopy /E /Y /Q "%PULSAR_HOME%\upstream\hermes-agent\hermes_cli\web_dist\*" "%PULSAR_HOME%\hermes_cli\web_dist\" >nul
    echo     Interface web mise a jour depuis le build pre-compile.
) else (
    :: Rebuild si node est disponible
    where node >nul 2>&1
    if %errorlevel% equ 0 (
        echo     Reconstruction de l'interface web (npm build)...
        cd /d "%PULSAR_HOME%\web"
        call npm run build
        if %errorlevel% neq 0 (
            echo [AVERTISSEMENT] Build npm echoue. Interface non mise a jour.
        )
    ) else (
        echo [AVERTISSEMENT] Node.js absent, interface non reconstruite.
    )
)

:: Installer les dépendances Python si nécessaire
echo [4/5] Verification des dependances Python...
cd /d "%PULSAR_HOME%"
if exist ".venv\Scripts\pip.exe" (
    .venv\Scripts\pip.exe install cryptography --quiet 2>nul
    echo     Dependances OK.
) else (
    echo [AVERTISSEMENT] Environnement virtuel absent.
)

:: Copier les nouveaux scripts de lancement
echo [5/5] Mise a jour des scripts de lancement...
set SCRIPTS_SRC=%PULSAR_HOME%\installer\windows\scripts
if exist "%SCRIPTS_SRC%\Pulsar-Start.bat" (
    copy /Y "%SCRIPTS_SRC%\Pulsar-Start.bat" "%PULSAR_HOME%\Pulsar-Start.bat" >nul
)
if exist "%SCRIPTS_SRC%\pulsar-tray.py" (
    copy /Y "%SCRIPTS_SRC%\pulsar-tray.py" "%PULSAR_HOME%\pulsar-tray.py" >nul
)

echo.
echo  ✓ Mise a jour terminee !
echo.
echo  Pour relancer PULSAR :
echo    - Double-cliquez sur "PULSAR" sur le Bureau
echo    - Ou lancez : %PULSAR_HOME%\Pulsar-Start.bat
echo.
set /p RELAUNCH="Relancer PULSAR maintenant ? (O/N) : "
if /i "%RELAUNCH%"=="O" (
    start "" "%PULSAR_HOME%\Pulsar-Start.bat"
)
exit /b 0
