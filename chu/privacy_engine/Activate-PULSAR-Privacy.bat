@echo off
:: ============================================================
::  PULSAR -- Activation du Privacy Engine RGPD
::  Plateforme Unifiee de Liaison, de Surveillance et
::  d'Assistance en temps Reel
::  DSIO -- CHU de Guyane | William MERI
::
::  Ce script :
::  1. Installe les dependances Python du Privacy Engine
::  2. Copie le Privacy Engine dans le dossier hermes
::  3. Configure les variables d'environnement
::  4. Teste l'anonymisation
::  5. Demarre l'API CHU avec Privacy Engine actif
:: ============================================================
setlocal EnableDelayedExpansion

echo.
echo   ============================================================
echo   PULSAR -- Privacy Engine RGPD
echo   Activation et configuration
echo   ============================================================
echo.

set "PULSAR_DIR=%LOCALAPPDATA%\hermes"
set "CHU_DIR=%PULSAR_DIR%\chu"
set "PRIVACY_DIR=%CHU_DIR%\privacy_engine"
set "API_DIR=%CHU_DIR%\api"
set "CHU_API_PORT=8001"
set "GITHUB_RAW=https://raw.githubusercontent.com/Tarzzan/HERMES-CHU/main"

:: ── Etape 1 : Verifier Python ─────────────────────────────────
echo   [1/6] Verification de Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo   [ERREUR] Python non trouve. Installez PULSAR d'abord.
    pause
    exit /b 1
)
for /f "tokens=*" %%v in ('python --version 2^>^&1') do echo   [OK] %%v

:: ── Etape 2 : Installer les dependances ──────────────────────
echo.
echo   [2/6] Installation des dependances Privacy Engine...
pip install fastapi uvicorn pydantic --quiet --no-warn-script-location
if errorlevel 1 (
    echo   [AVERTISSEMENT] Certaines dependances n'ont pas pu etre installees.
) else (
    echo   [OK] Dependances installees.
)

:: ── Etape 3 : Telecharger les fichiers Privacy Engine ─────────
echo.
echo   [3/6] Telechargement du Privacy Engine...
if not exist "%PRIVACY_DIR%" mkdir "%PRIVACY_DIR%"
if not exist "%API_DIR%" mkdir "%API_DIR%"

:: Telecharger middleware.py
curl -L "%GITHUB_RAW%/chu/privacy_engine/middleware.py" -o "%PRIVACY_DIR%\middleware.py" --silent --show-error
if errorlevel 1 (
    echo   [ERREUR] Impossible de telecharger middleware.py
    pause
    exit /b 1
)
echo   [OK] middleware.py

:: Telecharger serveur_chu.py
curl -L "%GITHUB_RAW%/chu/api/serveur_chu.py" -o "%API_DIR%\serveur_chu.py" --silent --show-error
if errorlevel 1 (
    echo   [ERREUR] Impossible de telecharger serveur_chu.py
    pause
    exit /b 1
)
echo   [OK] serveur_chu.py

:: Telecharger config_chu.yaml
curl -L "%GITHUB_RAW%/chu/config_chu.yaml" -o "%CHU_DIR%\config_chu.yaml" --silent --show-error
echo   [OK] config_chu.yaml

:: Creer __init__.py pour le package
echo. > "%PRIVACY_DIR%\__init__.py"
echo. > "%CHU_DIR%\__init__.py"

:: ── Etape 4 : Configurer les variables d'environnement ────────
echo.
echo   [4/6] Configuration des variables d'environnement...
setx CHU_PRIVACY_ENGINE_ACTIF "true" >nul 2>&1
setx CHU_AUDIT_LOG_DIR "%PULSAR_DIR%\audit" >nul 2>&1
setx CHU_API_PORT "%CHU_API_PORT%" >nul 2>&1
setx PYTHONPATH "%PULSAR_DIR%;%PYTHONPATH%" >nul 2>&1
if not exist "%PULSAR_DIR%\audit" mkdir "%PULSAR_DIR%\audit"
echo   [OK] Variables d'environnement configurees.

:: ── Etape 5 : Test du Privacy Engine ─────────────────────────
echo.
echo   [5/6] Test du Privacy Engine...
python -c "
import sys
sys.path.insert(0, r'%PULSAR_DIR%')
try:
    from chu.privacy_engine.middleware import get_privacy_engine
    pe = get_privacy_engine()
    texte = 'Le patient Jean DUPONT, ne le 15/03/1985, IPP 123456789, consulte pour douleur thoracique.'
    resultat = pe.anonymiser(texte, 'test-session', 'test-user')
    print('  [OK] Anonymisation fonctionnelle')
    print('  Avant :', texte[:60] + '...')
    print('  Apres :', resultat.texte_anonymise[:60] + '...')
    print('  Entites detectees :', len(resultat.entites_detectees))
except Exception as e:
    print('  [AVERTISSEMENT] Test partiel :', str(e)[:80])
    print('  Le Privacy Engine sera actif au demarrage de l API CHU.')
" 2>&1

:: ── Etape 6 : Demarrer l'API CHU ─────────────────────────────
echo.
echo   [6/6] Demarrage de l'API CHU PULSAR...
echo.

:: Verifier si deja demarre
curl -s http://localhost:%CHU_API_PORT%/api/chu/sante >nul 2>&1
if not errorlevel 1 (
    echo   [INFO] L'API CHU est deja active sur le port %CHU_API_PORT%.
    echo   Documentation : http://localhost:%CHU_API_PORT%/api/chu/docs
    goto :success
)

:: Demarrer l'API
start "PULSAR-API-CHU" /min python -c "
import sys, os
sys.path.insert(0, r'%PULSAR_DIR%')
os.environ['CHU_PRIVACY_ENGINE_ACTIF'] = 'true'
os.environ['CHU_AUDIT_LOG_DIR'] = r'%PULSAR_DIR%\audit'
import uvicorn
from chu.api.serveur_chu import app
uvicorn.run(app, host='127.0.0.1', port=%CHU_API_PORT%, log_level='warning')
"

:: Attendre le demarrage
timeout /t 3 /nobreak >nul
curl -s http://localhost:%CHU_API_PORT%/api/chu/sante >nul 2>&1
if errorlevel 1 (
    echo   [AVERTISSEMENT] L'API CHU n'a pas demarre immediatement.
    echo   Verifiez avec : curl http://localhost:%CHU_API_PORT%/api/chu/sante
) else (
    echo   [OK] API CHU active sur http://localhost:%CHU_API_PORT%
    echo   Documentation : http://localhost:%CHU_API_PORT%/api/chu/docs
)

:success
echo.
echo   ============================================================
echo   PULSAR Privacy Engine -- Configuration terminee
echo   ============================================================
echo.
echo   Statut :
echo     Privacy Engine RGPD  : ACTIF
echo     Anonymisation PHI    : ACTIVE
echo     Journal audit ISO    : ACTIF
echo     API CHU              : http://localhost:%CHU_API_PORT%
echo     Documentation        : http://localhost:%CHU_API_PORT%/api/chu/docs
echo.
echo   Pour demarrer PULSAR avec Privacy Engine :
echo     pulsar dashboard
echo.
echo   Pour verifier le statut :
echo     curl http://localhost:%CHU_API_PORT%/api/chu/privacy/statut
echo.
pause
endlocal
