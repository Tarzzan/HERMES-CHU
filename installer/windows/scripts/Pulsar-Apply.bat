@echo off
chcp 65001 >nul
title PULSAR CHU — Application des mises à jour

echo.
echo  ╔══════════════════════════════════════════════════════╗
echo  ║         PULSAR CHU — Application des mises à jour    ║
echo  ║         DSIO - CHU de Guyane                         ║
echo  ╚══════════════════════════════════════════════════════╝
echo.

:: Détection du répertoire d'installation
set "INSTALL_DIR=%LOCALAPPDATA%\hermes\pulsar-chu"
if not exist "%INSTALL_DIR%" set "INSTALL_DIR=%LOCALAPPDATA%\hermes\hermes-chu"
if not exist "%INSTALL_DIR%" set "INSTALL_DIR=%LOCALAPPDATA%\hermes\hermes-agent"

if not exist "%INSTALL_DIR%" (
    echo  [ERREUR] Installation PULSAR introuvable.
    echo  Lancez d'abord PULSAR-Setup-2.3.0.exe
    pause & exit /b 1
)

echo  Installation détectée : %INSTALL_DIR%
echo.

:: Vérifier git
where git >nul 2>&1
if errorlevel 1 (
    echo  [ERREUR] Git non trouvé. Installez Git pour Windows.
    pause & exit /b 1
)

cd /d "%INSTALL_DIR%"

:: Corriger le remote si nécessaire
for /f "tokens=*" %%r in ('git remote get-url origin 2^>nul') do set "CURRENT_REMOTE=%%r"
if not "%CURRENT_REMOTE%"=="https://github.com/Tarzzan/PULSAR-CHU.git" (
    echo  Correction du remote git...
    git remote set-url origin https://github.com/Tarzzan/PULSAR-CHU.git 2>nul
    git remote add origin https://github.com/Tarzzan/PULSAR-CHU.git 2>nul
)

:: Pull depuis PULSAR-CHU
echo  Récupération des mises à jour depuis GitHub...
git fetch origin main --depth=1 2>&1
git checkout origin/main -- hermes_cli/ web/src/ web/index.html 2>&1

if errorlevel 1 (
    echo  [ERREUR] Impossible de récupérer les sources.
    pause & exit /b 1
)

echo  Sources mises à jour.
echo.

:: Rebuild frontend
echo  Reconstruction de l'interface...
cd /d "%INSTALL_DIR%\web"
call npm run build >nul 2>&1
if errorlevel 1 (
    echo  [AVERT] Build frontend échoué — interface non mise à jour.
) else (
    echo  Interface reconstruite avec succès.
)

echo.
echo  ✅ PULSAR CHU mis à jour avec succès.
echo  Relancez PULSAR pour appliquer les changements.
echo.
pause
