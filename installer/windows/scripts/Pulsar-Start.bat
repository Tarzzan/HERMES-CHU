@echo off
chcp 65001 >nul
title PULSAR — Démarrage

set PULSAR_HOME=%LOCALAPPDATA%\hermes\hermes-chu
set VENV=%PULSAR_HOME%\.venv\Scripts
set PYTHON=%VENV%\pythonw.exe
set PULSAR_EXE=%VENV%\pulsar.exe
set TRAY_SCRIPT=%PULSAR_HOME%\pulsar-tray.py

:: Vérifier l'installation
if not exist "%PULSAR_HOME%" (
    echo [ERREUR] PULSAR n'est pas installe.
    echo Lancez PULSAR-Setup-2.3.0.exe pour l'installer.
    pause
    exit /b 1
)

:: Vérifier si PULSAR tourne déjà (port 9119)
netstat -an 2>nul | find ":9119" >nul
if %errorlevel% equ 0 (
    echo PULSAR est deja en cours d'execution.
    start "" "http://localhost:9119"
    exit /b 0
)

:: Installer pystray et pillow si absent
echo Verification des dependances systray...
"%VENV%\pip.exe" show pystray >nul 2>&1
if %errorlevel% neq 0 (
    echo Installation de pystray et pillow...
    "%VENV%\pip.exe" install pystray pillow --quiet
)

:: Lancer le systray (qui démarre aussi le serveur et ouvre le navigateur)
if exist "%PYTHON%" (
    if exist "%TRAY_SCRIPT%" (
        start "" "%PYTHON%" "%TRAY_SCRIPT%"
        exit /b 0
    )
)

:: Fallback : lancer le serveur directement sans systray
echo Demarrage du serveur PULSAR...
if exist "%PULSAR_EXE%" (
    start "" /B "%PULSAR_EXE%" dashboard
) else (
    start "" /B python -m hermes_cli dashboard
)

:: Attendre que le serveur soit prêt
echo Attente du demarrage...
:WAIT_LOOP
timeout /t 1 /nobreak >nul
netstat -an 2>nul | find ":9119" >nul
if %errorlevel% neq 0 goto WAIT_LOOP

:: Ouvrir le navigateur
start "" "http://localhost:9119"
exit /b 0
