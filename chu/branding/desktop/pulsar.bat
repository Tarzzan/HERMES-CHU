@echo off
:: ============================================================
::  PULSAR -- Systeme Agentique Medical
::  Plateforme Unifiee de Liaison, de Surveillance et
::  d'Assistance en temps Reel
::  DSIO -- CHU de Guyane | William MERI
::  v2.3.0
:: ============================================================
setlocal EnableDelayedExpansion

:: Recharger le PATH utilisateur
for /f "tokens=2*" %%A in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "USER_PATH=%%B"
for /f "tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul') do set "SYS_PATH=%%B"
if defined USER_PATH (
    set "PATH=%SYS_PATH%;%USER_PATH%"
) else (
    set "PATH=%SYS_PATH%"
)

set "PULSAR_DIR=%LOCALAPPDATA%\hermes"
set "CHU_API_PORT=8001"

:: ── Aucun argument -- aide PULSAR ────────────────────────────
if "%~1"=="" (
    echo.
    echo   ============================================================
    echo   PULSAR -- Systeme Agentique Medical
    echo   DSIO -- CHU de Guyane ^| William MERI
    echo   ============================================================
    echo.
    echo   Commandes disponibles :
    echo     pulsar dashboard    Interface web ^(http://localhost:9119^)
    echo     pulsar desktop      Application native Electron
    echo     pulsar chat         Interface en ligne de commande
    echo     pulsar setup        Configurer le provider LLM
    echo     pulsar update       Mettre a jour PULSAR ^(+ re-patch auto^)
    echo     pulsar api          Demarrer l'API CHU ^(port 8001^)
    echo     pulsar api stop     Arreter l'API CHU
    echo     pulsar patch        Appliquer les patches visuels PULSAR
    echo     pulsar status       Statut du systeme PULSAR
    echo     pulsar --help       Aide complete hermes
    echo.
    goto :end
)

:: ── Commande : pulsar patch ───────────────────────────────────
if /i "%~1"=="patch" (
    echo.
    echo   PULSAR -- Application des patches visuels...
    echo.
    set "PATCH_URL=https://raw.githubusercontent.com/Tarzzan/PULSAR-CHU/main/chu/branding/Patch-PULSAR-Sources.bat"
    set "PATCH_TMP=%TEMP%\Patch-PULSAR-Sources.bat"
    curl -L "!PATCH_URL!" -o "!PATCH_TMP!" --silent --show-error
    if exist "!PATCH_TMP!" (
        call "!PATCH_TMP!"
    ) else (
        echo [ERREUR] Impossible de telecharger le script de patch.
        echo Verifiez votre connexion internet.
    )
    goto :end
)

:: ── Commande : pulsar api ─────────────────────────────────────
if /i "%~1"=="api" (
    if /i "%~2"=="stop" (
        echo   PULSAR API -- Arret...
        taskkill /FI "WINDOWTITLE eq PULSAR-API*" /F >nul 2>&1
        echo   [OK] API CHU arretee.
        goto :end
    )
    echo.
    echo   PULSAR API CHU -- Demarrage sur port %CHU_API_PORT%...
    echo   Documentation : http://localhost:%CHU_API_PORT%/api/chu/docs
    echo.
    set "API_SCRIPT="
    for %%p in (
        "%PULSAR_DIR%\chu\api\serveur_chu.py"
        "%USERPROFILE%\.hermes\chu\api\serveur_chu.py"
    ) do (
        if exist "%%~p" set "API_SCRIPT=%%~p"
    )
    if not defined API_SCRIPT (
        echo [ERREUR] serveur_chu.py non trouve.
        echo Installez PULSAR complet depuis :
        echo https://github.com/Tarzzan/PULSAR-CHU/releases
        goto :end
    )
    start "PULSAR-API" /min python "!API_SCRIPT!" --port %CHU_API_PORT%
    echo   [OK] API CHU demarree en arriere-plan.
    goto :end
)

:: ── Commande : pulsar status ──────────────────────────────────
if /i "%~1"=="status" (
    echo.
    echo   ============================================================
    echo   PULSAR -- Statut du systeme
    echo   ============================================================
    echo.
    where hermes >nul 2>&1
    if errorlevel 1 (echo   [ERREUR] hermes non trouve dans le PATH) else (echo   [OK]    hermes disponible)
    python --version >nul 2>&1
    if errorlevel 1 (echo   [ERREUR] Python non disponible) else (for /f "tokens=*" %%v in ('python --version 2^>^&1') do echo   [OK]    %%v)
    curl -s http://localhost:%CHU_API_PORT%/api/chu/sante >nul 2>&1
    if errorlevel 1 (echo   [INFO]  API CHU non demarree  ^(pulsar api^)) else (echo   [OK]    API CHU active sur port %CHU_API_PORT%)
    curl -s http://localhost:9119 >nul 2>&1
    if errorlevel 1 (echo   [INFO]  Dashboard non demarre ^(pulsar dashboard^)) else (echo   [OK]    Dashboard actif sur port 9119)
    echo.
    goto :end
)

:: ── Commande : pulsar dashboard ───────────────────────────────
if /i "%~1"=="dashboard" (
    echo.
    echo   ============================================================
    echo   PULSAR -- Interface web
    echo   ============================================================
    echo   Disponible sur : http://localhost:9119
    echo   Ctrl+C pour arreter
    echo.
    :: Demarrer l'API CHU en arriere-plan si disponible
    set "API_SCRIPT="
    for %%p in (
        "%PULSAR_DIR%\chu\api\serveur_chu.py"
        "%USERPROFILE%\.hermes\chu\api\serveur_chu.py"
    ) do (
        if exist "%%~p" set "API_SCRIPT=%%~p"
    )
    if defined API_SCRIPT (
        curl -s http://localhost:%CHU_API_PORT%/api/chu/sante >nul 2>&1
        if errorlevel 1 (
            echo   [INFO] Demarrage API CHU en arriere-plan...
            start "PULSAR-API" /min python "!API_SCRIPT!" --port %CHU_API_PORT%
        )
    )
    :: Ouvrir le navigateur apres 3 secondes
    start "" cmd /c "timeout /t 3 /nobreak >nul && start http://localhost:9119"
    hermes dashboard
    goto :end
)

:: ── Commande : pulsar update ──────────────────────────────────
if /i "%~1"=="update" (
    echo.
    echo   PULSAR -- Mise a jour...
    echo.
    hermes update
    echo.
    echo   [INFO] Re-application des patches PULSAR apres mise a jour...
    set "PATCH_URL=https://raw.githubusercontent.com/Tarzzan/PULSAR-CHU/main/chu/branding/Patch-PULSAR-Sources.bat"
    set "PATCH_TMP=%TEMP%\Patch-PULSAR-Sources.bat"
    curl -L "!PATCH_URL!" -o "!PATCH_TMP!" --silent
    if exist "!PATCH_TMP!" call "!PATCH_TMP!"
    goto :end
)

:: ── Toutes les autres commandes -> hermes ─────────────────────
hermes %*

:end
endlocal
