@echo off
chcp 65001 >nul 2>&1
echo ============================================================
echo   PULSAR v3.0 - Patch Global Branding
echo   DSIO - CHU de Guyane
echo ============================================================
echo.

REM Verifier que Python est disponible
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERREUR] Python n'est pas installe ou pas dans le PATH.
    echo Installez Python depuis https://python.org
    pause
    exit /b 1
)

REM Chemin du script (meme dossier que ce .bat)
set SCRIPT_DIR=%~dp0
set PATCH_SCRIPT=%SCRIPT_DIR%patch_pulsar_full.py

if not exist "%PATCH_SCRIPT%" (
    echo [ERREUR] patch_pulsar_full.py introuvable dans %SCRIPT_DIR%
    pause
    exit /b 1
)

echo Lancement du patch...
echo.
python "%PATCH_SCRIPT%"

echo.
echo ============================================================
echo   Patch termine. Lancez maintenant :
echo.
echo   cd /d "%LOCALAPPDATA%\hermes\hermes-agent\web"
echo   npm run build
echo.
echo   Puis relancez : pulsar dashboard
echo ============================================================
echo.
pause
