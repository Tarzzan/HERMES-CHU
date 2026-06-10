@echo off
:: ============================================================
::  PULSAR -- Installation des Skills Agents CHU
::  DSIO -- CHU de Guyane | William MERI
::
::  Installe les 6 agents specialises PULSAR dans hermes-agent :
::    - Agent Clinique        (medecins, infirmiers)
::    - Agent Administratif   (secretaires, cadres)
::    - Agent Logistique      (pharmacie, biomédical, achats)
::    - Agent Recherche       (DRCI, URC, biostatisticiens)
::    - Agent Qualite         (qualite, RSSI, DPO)
::    - Agent Formation       (DRH, formateurs, IFSI)
:: ============================================================
setlocal EnableDelayedExpansion

echo.
echo   ============================================================
echo   PULSAR -- Installation des Skills Agents CHU
echo   ============================================================
echo.

set "GITHUB_RAW=https://raw.githubusercontent.com/Tarzzan/HERMES-CHU/main/chu/skills"
set "HERMES_SKILLS_DIR=%LOCALAPPDATA%\hermes\skills\chu"
set "HERMES_BIN=%LOCALAPPDATA%\hermes\hermes-agent\venv\Scripts\hermes.exe"

:: Verifier hermes
where hermes >nul 2>&1
if errorlevel 1 (
    echo   [ERREUR] hermes non trouve. Installez PULSAR d'abord.
    pause
    exit /b 1
)

:: Creer le dossier skills CHU
if not exist "%HERMES_SKILLS_DIR%" mkdir "%HERMES_SKILLS_DIR%"
echo   [OK] Dossier skills : %HERMES_SKILLS_DIR%
echo.

:: Liste des skills a installer
set "SKILLS=agent_clinique agent_administratif agent_logistique agent_recherche agent_qualite agent_formation"
set "SKILL_COUNT=0"
set "SKILL_OK=0"

for %%s in (%SKILLS%) do (
    set /a SKILL_COUNT+=1
    echo   [!SKILL_COUNT!/6] Installation de %%s...

    :: Telecharger le fichier .md
    curl -L "%GITHUB_RAW%/%%s.md" -o "%HERMES_SKILLS_DIR%\%%s.md" --silent --show-error
    if errorlevel 1 (
        echo   [ERREUR] Impossible de telecharger %%s.md
    ) else (
        echo   [OK] %%s.md installe.
        set /a SKILL_OK+=1
    )
)

echo.
echo   [!SKILL_OK!/!SKILL_COUNT!] skills installes avec succes.
echo.

:: Verifier si hermes peut charger les skills
echo   Verification du chargement des skills...
hermes skills list 2>nul | findstr /i "chu" >nul 2>&1
if errorlevel 1 (
    echo   [INFO] Les skills CHU seront disponibles au prochain demarrage de PULSAR.
) else (
    echo   [OK] Skills CHU detectes par hermes.
)

echo.
echo   ============================================================
echo   Skills PULSAR installes
echo   ============================================================
echo.
echo   Pour activer un agent dans PULSAR :
echo     pulsar chat --skills chu/agent_clinique
echo     pulsar chat --skills chu/agent_administratif
echo     pulsar chat --skills chu/agent_logistique
echo     pulsar chat --skills chu/agent_recherche
echo     pulsar chat --skills chu/agent_qualite
echo     pulsar chat --skills chu/agent_formation
echo.
echo   Pour activer tous les agents :
echo     pulsar chat --skills chu
echo.
echo   Dans le dashboard web :
echo     Menu Competences -- Skills CHU disponibles
echo.
pause
endlocal
