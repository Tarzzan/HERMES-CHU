@echo off
:: ============================================================
::  Install-PULSAR-Command.bat
::  Installe la commande "pulsar" sans necessite d'ExecutionPolicy
::  DSIO -- CHU de Guyane | William MERI
:: ============================================================
setlocal enabledelayedexpansion

echo.
echo   ============================================================
echo   PULSAR -- Installation commande Windows
echo   DSIO -- CHU de Guyane ^| William MERI
echo   ============================================================
echo.

:: Dossier d'installation (dans le PATH utilisateur)
set "INSTALL_DIR=%LOCALAPPDATA%\hermes\bin"
set "PULSAR_BAT=%INSTALL_DIR%\pulsar.bat"
set "PULSAR_CMD=%INSTALL_DIR%\pulsar.cmd"
set "ASSETS_DIR=%LOCALAPPDATA%\hermes\pulsar-assets"
set "ICO_PATH=%ASSETS_DIR%\pulsar.ico"
set "LAUNCH_PS1=%ASSETS_DIR%\Launch-PULSAR.ps1"

:: 1. Creer les dossiers
echo [>>] Creation des dossiers...
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
if not exist "%ASSETS_DIR%" mkdir "%ASSETS_DIR%"
echo      [OK] Dossiers crees

:: 2. Telecharger pulsar.bat depuis GitHub
echo [>>] Telechargement de pulsar.bat...
powershell -Command "try { Invoke-WebRequest 'https://raw.githubusercontent.com/Tarzzan/HERMES-CHU/main/chu/branding/desktop/pulsar.bat' -OutFile '%PULSAR_BAT%' -UseBasicParsing; Write-Host '     [OK] pulsar.bat telecharge' } catch { Write-Host '     [!!] Echec telechargement, creation locale...' }"

:: Si le telechargement a echoue, creer le fichier localement
if not exist "%PULSAR_BAT%" (
    echo @echo off > "%PULSAR_BAT%"
    echo if "%%~1"=="" ( >> "%PULSAR_BAT%"
    echo   echo PULSAR -- Systeme Agentique Medical >> "%PULSAR_BAT%"
    echo   echo pulsar dashboard  ^| pulsar chat  ^| pulsar setup  ^| pulsar --help >> "%PULSAR_BAT%"
    echo   goto :eof >> "%PULSAR_BAT%"
    echo ^) >> "%PULSAR_BAT%"
    echo if /i "%%~1"=="dashboard" ( >> "%PULSAR_BAT%"
    echo   start "" cmd /c "timeout /t 2 /nobreak ^>nul ^&^& start http://localhost:9119" >> "%PULSAR_BAT%"
    echo   hermes dashboard >> "%PULSAR_BAT%"
    echo   goto :eof >> "%PULSAR_BAT%"
    echo ^) >> "%PULSAR_BAT%"
    echo hermes %%* >> "%PULSAR_BAT%"
    echo      [OK] pulsar.bat cree localement
)

:: Copier aussi en .cmd pour compatibilite maximale
copy /y "%PULSAR_BAT%" "%PULSAR_CMD%" >nul 2>&1
echo      [OK] pulsar.cmd cree

:: 3. Telecharger l'icone PULSAR
echo [>>] Telechargement de l'icone PULSAR...
powershell -Command "try { Invoke-WebRequest 'https://raw.githubusercontent.com/Tarzzan/HERMES-CHU/main/chu/branding/desktop/pulsar.ico' -OutFile '%ICO_PATH%' -UseBasicParsing; Write-Host '     [OK] Icone PULSAR telechargee' } catch { Write-Host '     [!!] Icone non telechargee (non bloquant)' }"

:: 4. Ajouter le dossier bin au PATH utilisateur
echo [>>] Ajout de %INSTALL_DIR% au PATH utilisateur...
for /f "tokens=2*" %%A in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "CURRENT_PATH=%%B"
echo !CURRENT_PATH! | findstr /i "%INSTALL_DIR%" >nul 2>&1
if errorlevel 1 (
    if defined CURRENT_PATH (
        setx PATH "!CURRENT_PATH!;%INSTALL_DIR%" >nul 2>&1
    ) else (
        setx PATH "%INSTALL_DIR%" >nul 2>&1
    )
    echo      [OK] PATH mis a jour -- ouvrez un nouveau terminal pour utiliser "pulsar"
) else (
    echo      [OK] Dossier deja dans le PATH
)

:: Mettre a jour le PATH de la session courante
set "PATH=%PATH%;%INSTALL_DIR%"

:: 5. Creer le script de lancement PULSAR (pour les raccourcis)
echo [>>] Creation du script de lancement...
(
echo @echo off
echo title PULSAR -- Systeme Agentique Medical
echo echo.
echo echo   ============================================================
echo echo   PULSAR -- Systeme Agentique Medical
echo echo   DSIO -- CHU de Guyane ^| William MERI
echo echo   ============================================================
echo echo.
echo echo   Demarrage interface web PULSAR...
echo echo   Disponible sur : http://localhost:9119
echo echo   Ctrl+C pour arreter
echo echo.
echo start "" cmd /c "timeout /t 2 /nobreak ^>nul ^&^& start http://localhost:9119"
echo hermes dashboard
echo if errorlevel 1 (
echo   echo.
echo   echo   [!!] PULSAR s'est arrete. Appuyez sur une touche...
echo   pause ^>nul
echo ^)
) > "%ASSETS_DIR%\Launch-PULSAR.bat"
echo      [OK] Script de lancement cree

:: 6. Creer les raccourcis Bureau et Menu Demarrer
echo [>>] Creation des raccourcis PULSAR...
set "DESKTOP=%USERPROFILE%\Desktop"
set "STARTMENU=%APPDATA%\Microsoft\Windows\Start Menu\Programs"
set "LAUNCH_BAT=%ASSETS_DIR%\Launch-PULSAR.bat"

:: Raccourci Bureau
powershell -Command ^
  "$ico = '%ICO_PATH%'; $lnk = '%DESKTOP%\PULSAR.lnk'; $bat = '%LAUNCH_BAT%'; " ^
  "$sh = New-Object -ComObject WScript.Shell; $sc = $sh.CreateShortcut($lnk); " ^
  "$sc.TargetPath = $bat; $sc.WorkingDirectory = '%ASSETS_DIR%'; " ^
  "$sc.Description = 'PULSAR -- Systeme Agentique Medical | DSIO CHU de Guyane'; " ^
  "if (Test-Path $ico) { $sc.IconLocation = $ico + ',0' }; $sc.Save(); " ^
  "Write-Host '     [OK] Raccourci Bureau : ' $lnk"

:: Dossier Menu Demarrer
if not exist "%STARTMENU%\PULSAR" mkdir "%STARTMENU%\PULSAR"
powershell -Command ^
  "$ico = '%ICO_PATH%'; $lnk = '%STARTMENU%\PULSAR\PULSAR.lnk'; $bat = '%LAUNCH_BAT%'; " ^
  "$sh = New-Object -ComObject WScript.Shell; $sc = $sh.CreateShortcut($lnk); " ^
  "$sc.TargetPath = $bat; $sc.WorkingDirectory = '%ASSETS_DIR%'; " ^
  "$sc.Description = 'PULSAR -- Systeme Agentique Medical | DSIO CHU de Guyane'; " ^
  "if (Test-Path $ico) { $sc.IconLocation = $ico + ',0' }; $sc.Save(); " ^
  "Write-Host '     [OK] Raccourci Menu Demarrer : ' $lnk"

:: Rafraichir les icones
ie4uinit.exe -show >nul 2>&1

:: 7. Activer ExecutionPolicy pour l'utilisateur (sans admin)
echo [>>] Activation ExecutionPolicy RemoteSigned pour l'utilisateur...
powershell -Command "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; Write-Host '     [OK] ExecutionPolicy RemoteSigned active pour l''utilisateur courant'"

:: 8. Test de la commande pulsar
echo [>>] Test de la commande pulsar...
where pulsar >nul 2>&1
if errorlevel 1 (
    echo      [!!] pulsar pas encore dans le PATH de cette session
    echo      Ouvrez un nouveau terminal et tapez : pulsar
) else (
    echo      [OK] Commande pulsar disponible !
    pulsar
)

echo.
echo   ============================================================
echo   PULSAR installe avec succes !
echo   ============================================================
echo.
echo   Commandes disponibles (dans un nouveau terminal) :
echo     pulsar              Afficher l'aide
echo     pulsar dashboard    Lancer l'interface web
echo     pulsar chat         Interface CLI
echo     pulsar setup        Configurer le provider LLM
echo     pulsar --help       Aide complete
echo.
echo   Raccourcis crees :
echo     Bureau    : PULSAR.lnk
echo     Menu Dem. : PULSAR\PULSAR.lnk
echo.
pause
endlocal
