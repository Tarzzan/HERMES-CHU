@echo off
echo ============================================================
echo   PULSAR — Lancement de la desinstallation...
echo ============================================================
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)
powershell -ExecutionPolicy Bypass -File "%~dp0uninstall-pulsar.ps1"
