@echo off
:: PULSAR -- Lanceur du patch Python
:: DSIO CHU de Guyane | William MERI
::
:: Ce fichier telecharge patch_pulsar.py et l'execute.
:: Pour contourner SmartScreen : clic droit > Proprietes > Debloquer

setlocal
set "TMP_PY=%TEMP%\patch_pulsar_%RANDOM%.py"
set "GITHUB_RAW=https://raw.githubusercontent.com/Tarzzan/HERMES-CHU/main/chu/branding/patch_pulsar.py"

echo.
echo   PULSAR -- Patch Sources TypeScript
echo   DSIO CHU de Guyane -- William MERI
echo.

:: Telecharger le script Python
curl -L "%GITHUB_RAW%" -o "%TMP_PY%" --silent --show-error
if errorlevel 1 (
    echo   [ERREUR] Telechargement echoue. Verifiez votre connexion.
    pause
    exit /b 1
)

:: Executer le patch avec rebuild automatique
python "%TMP_PY%" --rebuild
del "%TMP_PY%" >nul 2>&1

pause
endlocal
