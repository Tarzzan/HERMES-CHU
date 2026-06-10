@echo off
:: ============================================================
::  PULSAR -- Systeme Agentique Medical
::  DSIO -- CHU de Guyane | William MERI
::  Wrapper CMD pour la commande pulsar
:: ============================================================
setlocal

:: Recharger le PATH utilisateur
for /f "tokens=2*" %%A in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "USER_PATH=%%B"
for /f "tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul') do set "SYS_PATH=%%B"
if defined USER_PATH (
    set "PATH=%SYS_PATH%;%USER_PATH%"
) else (
    set "PATH=%SYS_PATH%"
)

:: Aucun argument -- afficher l'aide PULSAR
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
    echo     pulsar update       Mettre a jour PULSAR
    echo     pulsar --help       Aide complete
    echo.
    goto :end
)

:: Commande dashboard -- ouvrir le navigateur automatiquement
if /i "%~1"=="dashboard" (
    echo.
    echo   PULSAR -- Demarrage interface web...
    echo   Disponible sur : http://localhost:9119
    echo   Ctrl+C pour arreter
    echo.
    :: Ouvrir le navigateur apres 2 secondes en arriere-plan
    start "" cmd /c "timeout /t 2 /nobreak >nul && start http://localhost:9119"
    hermes dashboard
    goto :end
)

:: Toutes les autres commandes -- deleguer a hermes
hermes %*

:end
endlocal
