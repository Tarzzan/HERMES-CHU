; ============================================================
;  HERMES CHU — Installateur Windows
;  Système Agentique Hospitalier Souverain
;  Version : 1.2.0 — Couverture RGPD totale (7 flux)
;  Compilé avec NSIS 3.09 (Linux/makensis)
; ============================================================

Unicode True

;--------------------------------
; Includes
;--------------------------------
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"

;--------------------------------
; Métadonnées
;--------------------------------
Name              "HERMES CHU 1.2.0"
OutFile           "/home/ubuntu/nsis_build/output/HERMES-CHU-Setup-1.2.0.exe"
InstallDir        "$PROGRAMFILES64\HERMES CHU"
InstallDirRegKey  HKLM "Software\HERMES CHU" "InstallDir"
RequestExecutionLevel admin
SetCompressor     /SOLID lzma
SetCompressorDictSize 32

;--------------------------------
; Informations de version
;--------------------------------
VIProductVersion  "1.2.0.0"
VIAddVersionKey   "ProductName"      "HERMES CHU"
VIAddVersionKey   "ProductVersion"   "1.2.0"
VIAddVersionKey   "CompanyName"      "William MERI — CHU de Guyane"
VIAddVersionKey   "FileDescription"  "Système Agentique Hospitalier Souverain"
VIAddVersionKey   "FileVersion"      "1.2.0"
VIAddVersionKey   "LegalCopyright"   "© 2025-2026 CHU — Licence Apache 2.0"
VIAddVersionKey   "Comments"         "Conçu par William MERI (CHU-Guyane) — Basé sur NousResearch Hermes Agent"

;--------------------------------
; Interface MUI2
;--------------------------------
!define MUI_ABORTWARNING
!define MUI_ABORTWARNING_TEXT        "Annuler l'installation de HERMES CHU ?"

; --- À propos ---
!define MUI_COMPONENTSPAGE_NODESC
!define MUI_FINISHPAGE_NOAUTOCLOSE
!define MUI_ICON                    "/usr/share/nsis/Contrib/Graphics/Icons/modern-install-blue.ico"
!define MUI_UNICON                  "/usr/share/nsis/Contrib/Graphics/Icons/modern-uninstall-blue.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "/home/ubuntu/nsis_build/assets/sidebar.bmp"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP      "/home/ubuntu/nsis_build/assets/banner.bmp"
!define MUI_HEADERIMAGE_RIGHT

!define MUI_WELCOMEPAGE_TITLE       "Bienvenue dans HERMES CHU 1.2.0"
!define MUI_WELCOMEPAGE_TEXT        "Cet assistant va installer HERMES CHU — Système Agentique Hospitalier Souverain.$\r$\n$\r$\nHERMES CHU est basé sur Hermes Agent de NousResearch, adapté pour les établissements de santé avec :$\r$\n$\r$\n• Privacy Engine RGPD — 7 flux couverts (NER médical, mémoire, skills, contexte)$\r$\n• Support multi-LLM (Azure OpenAI, OpenAI, Ollama, vLLM)$\r$\n• Agents spécialisés (Clinique, Administratif, Logistique, Recherche)$\r$\n• Conformité ISO 27001 et HDS$\r$\n$\r$\nIl est recommandé de fermer toutes les autres applications avant de continuer."

!define MUI_FINISHPAGE_TITLE        "Installation terminée !"
!define MUI_FINISHPAGE_TEXT         "HERMES CHU 1.2.0 a été installé avec succès.$\r$\n$\r$\nConçu par William MERI — CHU de Guyane$\r$\n$\r$\nProchaines étapes :$\r$\n1. Lancez l'assistant de configuration via le Menu Démarrer$\r$\n2. Renseignez vos paramètres Azure OpenAI ou Ollama$\r$\n3. Activez le Privacy Engine RGPD$\r$\n4. Ouvrez HERMES CHU depuis le bureau$\r$\n$\r$\nDocumentation : github.com/Tarzzan/HERMES-CHU/wiki"
!define MUI_FINISHPAGE_RUN          "$INSTDIR\scripts\Configure-CHU.bat"
!define MUI_FINISHPAGE_RUN_TEXT     "Lancer l'assistant de configuration CHU"
!define MUI_FINISHPAGE_LINK         "Consulter le Wiki HERMES CHU"
!define MUI_FINISHPAGE_LINK_LOCATION "https://github.com/Tarzzan/HERMES-CHU/wiki"

;--------------------------------
; Pages de l'installateur
;--------------------------------
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE       "/home/ubuntu/nsis_build/assets/LICENSE.txt"
Page custom PageAPropos
Page custom PagePrerequisites PagePrerequisitesLeave
Page custom PageCHUConfig PageCHUConfigLeave
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

;--------------------------------
; Pages du désinstallateur
;--------------------------------
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

;--------------------------------
; Langues
;--------------------------------
!insertmacro MUI_LANGUAGE "French"

;--------------------------------
; Variables personnalisées
;--------------------------------
Var AzureEndpoint
Var AzureApiKey
Var AzureDeployment
Var PrivacyEnabled
Var ProviderChoice
Var NodeFound
Var PythonFound
Var GitFound


;--------------------------------
; Page À propos — Crédits William MERI
;--------------------------------
Function PageAPropos
    nsDialogs::Create 1018
    Pop $0

    ${NSD_CreateLabel} 0 0 100% 14u "HERMES CHU — Système Agentique Hospitalier Souverain"
    Pop $0
    SetCtlColors $0 0x003366 transparent

    ${NSD_CreateLabel} 0 20u 100% 1u ""
    Pop $0

    ${NSD_CreateGroupBox} 0 25u 100% 80u "Conception & Développement"
    Pop $0

    ${NSD_CreateLabel} 10u 40u 100% 12u "Concepteur & Porteur de projet :"
    Pop $0

    ${NSD_CreateLabel} 10u 55u 100% 14u "William MERI — CHU de Guyane"
    Pop $0

    ${NSD_CreateLabel} 10u 75u 100% 10u "Architecte du système agentique hospitalier"
    Pop $0

    ${NSD_CreateLabel} 10u 88u 100% 10u "github.com/Tarzzan/HERMES-CHU"
    Pop $0

    ${NSD_CreateGroupBox} 0 115u 100% 50u "Technologie de base"
    Pop $0

    ${NSD_CreateLabel} 10u 130u 100% 10u "Basé sur Hermes Agent — NousResearch"
    Pop $0

    ${NSD_CreateLabel} 10u 145u 100% 10u "Modèle : Hermes-3-Llama-3.1-70B-Instruct"
    Pop $0

    ${NSD_CreateLabel} 10u 158u 100% 10u "Licence Apache 2.0 — Open Source"
    Pop $0

    ${NSD_CreateLabel} 0 175u 100% 10u "Version 1.2.0 — Juin 2026 — Conformité ISO 27001 & HDS & RGPD"
    Pop $0

    nsDialogs::Show
FunctionEnd

;--------------------------------
; Page Prérequis (personnalisée)
;--------------------------------
Function PagePrerequisites
    nsDialogs::Create 1018
    Pop $0

    ${NSD_CreateLabel} 0 0 100% 20u "Vérification des prérequis système"
    Pop $0

    ; Vérifier Node.js
    nsExec::ExecToStack "node --version"
    Pop $1  ; code retour
    Pop $2  ; sortie
    ${If} $1 == 0
        StrCpy $NodeFound "1"
        ${NSD_CreateLabel} 0 30u 100% 12u "✓ Node.js détecté : $2"
        Pop $0
    ${Else}
        StrCpy $NodeFound "0"
        ${NSD_CreateLabel} 0 30u 100% 12u "✗ Node.js non trouvé — sera installé automatiquement"
        Pop $0
    ${EndIf}

    ; Vérifier Python
    nsExec::ExecToStack "python --version"
    Pop $1
    Pop $2
    ${If} $1 == 0
        StrCpy $PythonFound "1"
        ${NSD_CreateLabel} 0 50u 100% 12u "✓ Python détecté : $2"
        Pop $0
    ${Else}
        StrCpy $PythonFound "0"
        ${NSD_CreateLabel} 0 50u 100% 12u "✗ Python non trouvé — sera installé automatiquement"
        Pop $0
    ${EndIf}

    ; Vérifier Git
    nsExec::ExecToStack "git --version"
    Pop $1
    Pop $2
    ${If} $1 == 0
        StrCpy $GitFound "1"
        ${NSD_CreateLabel} 0 70u 100% 12u "✓ Git détecté : $2"
        Pop $0
    ${Else}
        StrCpy $GitFound "0"
        ${NSD_CreateLabel} 0 70u 100% 12u "✗ Git non trouvé — sera installé automatiquement"
        Pop $0
    ${EndIf}

    ${NSD_CreateLabel} 0 95u 100% 30u "Les prérequis manquants seront téléchargés et installés automatiquement pendant l'installation. Une connexion Internet est requise."
    Pop $0

    nsDialogs::Show
FunctionEnd

Function PagePrerequisitesLeave
FunctionEnd

;--------------------------------
; Page Configuration CHU (personnalisée)
;--------------------------------
Function PageCHUConfig
    nsDialogs::Create 1018
    Pop $0

    ${NSD_CreateLabel} 0 0 100% 12u "Configuration du fournisseur IA"
    Pop $0

    ${NSD_CreateLabel} 0 18u 100% 10u "Fournisseur LLM :"
    Pop $0

    ${NSD_CreateDropList} 0 30u 200u 60u ""
    Pop $1
    ${NSD_CB_AddString} $1 "Azure OpenAI (recommandé — certifié HDS)"
    ${NSD_CB_AddString} $1 "OpenAI (GPT-4o, GPT-4-turbo)"
    ${NSD_CB_AddString} $1 "Ollama (modèles locaux)"
    ${NSD_CB_AddString} $1 "vLLM On-Premise (Hermes-3-70B)"
    ${NSD_CB_AddString} $1 "Configurer plus tard"
    ${NSD_CB_SelectString} $1 "Azure OpenAI (recommandé — certifié HDS)"
    GetFunctionAddress $2 OnProviderChange
    nsDialogs::OnChange $1 $2

    ${NSD_CreateLabel} 0 55u 80u 10u "Endpoint Azure OpenAI :"
    Pop $0
    ${NSD_CreateText} 0 67u 100% 12u "https://votre-ressource.openai.azure.com/"
    Pop $AzureEndpoint

    ${NSD_CreateLabel} 0 85u 80u 10u "Clé API :"
    Pop $0
    ${NSD_CreatePassword} 0 97u 100% 12u ""
    Pop $AzureApiKey

    ${NSD_CreateLabel} 0 115u 80u 10u "Nom du déploiement :"
    Pop $0
    ${NSD_CreateText} 0 127u 100% 12u "gpt-4o"
    Pop $AzureDeployment

    ${NSD_CreateLabel} 0 150u 100% 10u "Privacy Engine RGPD :"
    Pop $0
    ${NSD_CreateCheckbox} 0 163u 100% 12u "Activer l'anonymisation des données de santé (recommandé)"
    Pop $PrivacyEnabled
    ${NSD_Check} $PrivacyEnabled

    ${NSD_CreateLabel} 0 185u 100% 35u "Note RGPD (v1.1) : 7 flux couverts — entrées/sorties LLM, mémoire persistante, revue de fond, trajectoires fine-tuning, amélioration des skills (curator) et résumés de contexte (context_compressor). Aucun PHI ne persiste en clair."
    Pop $0

    nsDialogs::Show
FunctionEnd

Function OnProviderChange
    ; Callback simplifié — la configuration détaillée se fait via Configure-CHU.ps1
FunctionEnd

Function PageCHUConfigLeave
    ${NSD_GetText} $AzureEndpoint $0
    StrCpy $AzureEndpoint $0
    ${NSD_GetText} $AzureApiKey $0
    StrCpy $AzureApiKey $0
    ${NSD_GetText} $AzureDeployment $0
    StrCpy $AzureDeployment $0
    ${NSD_GetState} $PrivacyEnabled $0
    StrCpy $PrivacyEnabled $0
FunctionEnd

;--------------------------------
; Section principale d'installation
;--------------------------------
Section "HERMES CHU (requis)" SecMain
    SectionIn RO
    SetOutPath "$INSTDIR"

    ; --- Copie des fichiers principaux ---
    File /r "/home/ubuntu/nsis_build/payload\*.*"

    ; --- Créer le fichier .env.chu ---
    FileOpen $0 "$INSTDIR\chu\.env.chu" w

    FileWrite $0 "# HERMES CHU — Configuration$\r$\n"
    FileWrite $0 "# Généré automatiquement par l'installateur$\r$\n"
    FileWrite $0 "$\r$\n"
    FileWrite $0 "# Fournisseur LLM actif$\r$\n"
    FileWrite $0 "FOURNISSEUR_ACTIF=azure_openai$\r$\n"
    FileWrite $0 "$\r$\n"
    FileWrite $0 "# Azure OpenAI$\r$\n"
    FileWrite $0 "AZURE_OPENAI_ENDPOINT=$AzureEndpoint$\r$\n"
    FileWrite $0 "AZURE_OPENAI_API_KEY=$AzureApiKey$\r$\n"
    FileWrite $0 "AZURE_OPENAI_DEPLOYMENT=$AzureDeployment$\r$\n"
    FileWrite $0 "AZURE_OPENAI_API_VERSION=2024-02-01$\r$\n"
    FileWrite $0 "$\r$\n"
    FileWrite $0 "# OpenAI (alternatif)$\r$\n"
    FileWrite $0 "OPENAI_API_KEY=$\r$\n"
    FileWrite $0 "OPENAI_MODEL=gpt-4o$\r$\n"
    FileWrite $0 "$\r$\n"
    FileWrite $0 "# Ollama (local)$\r$\n"
    FileWrite $0 "OLLAMA_BASE_URL=http://localhost:11434$\r$\n"
    FileWrite $0 "OLLAMA_MODEL=hermes3:70b$\r$\n"
    FileWrite $0 "$\r$\n"
    FileWrite $0 "# vLLM On-Premise$\r$\n"
    FileWrite $0 "VLLM_BASE_URL=http://vllm-service:8000/v1$\r$\n"
    FileWrite $0 "VLLM_MODEL=NousResearch/Hermes-3-Llama-3.1-70B-Instruct$\r$\n"
    FileWrite $0 "$\r$\n"
    FileWrite $0 "# Privacy Engine RGPD$\r$\n"

    ${If} $PrivacyEnabled == ${BST_CHECKED}
        FileWrite $0 "PRIVACY_ENGINE_ACTIF=true$\r$\n"
    ${Else}
        FileWrite $0 "PRIVACY_ENGINE_ACTIF=false$\r$\n"
    ${EndIf}

    FileWrite $0 "PRIVACY_LOG_LEVEL=INFO$\r$\n"
    FileWrite $0 "$\r$\n"
    FileWrite $0 "# API CHU$\r$\n"
    FileWrite $0 "CHU_API_PORT=8001$\r$\n"
    FileWrite $0 "CHU_API_HOST=127.0.0.1$\r$\n"
    FileWrite $0 "$\r$\n"
    FileWrite $0 "# Base de données$\r$\n"
    FileWrite $0 "DATABASE_URL=sqlite:///$INSTDIR\chu\data\hermes_chu.db$\r$\n"
    FileClose $0

    ; --- Créer les scripts .bat de lancement ---
    FileOpen $0 "$INSTDIR\scripts\Configure-CHU.bat" w
    FileWrite $0 "@echo off$\r$\n"
    FileWrite $0 "cd /d $\"%~dp0..$\"$\r$\n"
    FileWrite $0 "PowerShell -ExecutionPolicy Bypass -File $\"scripts\Configure-CHU.ps1$\"$\r$\n"
    FileWrite $0 "pause$\r$\n"
    FileClose $0

    FileOpen $0 "$INSTDIR\scripts\Start-API-CHU.bat" w
    FileWrite $0 "@echo off$\r$\n"
    FileWrite $0 "cd /d $\"%~dp0..$\"$\r$\n"
    FileWrite $0 "PowerShell -ExecutionPolicy Bypass -File $\"scripts\Start-API-CHU.ps1$\" -Mode background$\r$\n"
    FileClose $0

    FileOpen $0 "$INSTDIR\scripts\Install-Prerequisites.bat" w
    FileWrite $0 "@echo off$\r$\n"
    FileWrite $0 "cd /d $\"%~dp0..$\"$\r$\n"
    FileWrite $0 "PowerShell -ExecutionPolicy Bypass -File $\"scripts\Install-Prerequisites.ps1$\"$\r$\n"
    FileWrite $0 "pause$\r$\n"
    FileClose $0

    ; --- Raccourcis Bureau ---
    CreateDirectory "$SMPROGRAMS\HERMES CHU"
    CreateShortcut "$DESKTOP\HERMES CHU.lnk" \
        "$INSTDIR\scripts\Start-API-CHU.bat" "" \
        "$INSTDIR\assets\icon.ico" 0 \
        SW_SHOWMINIMIZED "" "Lancer HERMES CHU"

    ; --- Raccourcis Menu Démarrer ---
    CreateShortcut "$SMPROGRAMS\HERMES CHU\HERMES CHU.lnk" \
        "$INSTDIR\scripts\Start-API-CHU.bat" "" \
        "$INSTDIR\assets\icon.ico" 0 \
        SW_SHOWMINIMIZED "" "Lancer HERMES CHU"

    CreateShortcut "$SMPROGRAMS\HERMES CHU\Configurer HERMES CHU.lnk" \
        "$INSTDIR\scripts\Configure-CHU.bat" "" \
        "$INSTDIR\assets\icon.ico" 0 \
        SW_SHOWNORMAL "" "Configurer HERMES CHU"

    CreateShortcut "$SMPROGRAMS\HERMES CHU\Installer les prérequis.lnk" \
        "$INSTDIR\scripts\Install-Prerequisites.bat" "" \
        "$INSTDIR\assets\icon.ico" 0 \
        SW_SHOWNORMAL "" "Installer les prérequis (Node.js, Python, Git)"

    CreateShortcut "$SMPROGRAMS\HERMES CHU\Documentation Wiki.lnk" \
        "https://github.com/Tarzzan/HERMES-CHU/wiki" "" "" 0

    CreateShortcut "$SMPROGRAMS\HERMES CHU\Désinstaller HERMES CHU.lnk" \
        "$INSTDIR\Uninstall.exe" "" "" 0

    ; --- Registre Windows ---
    WriteRegStr HKLM "Software\HERMES CHU" "InstallDir" "$INSTDIR"
    WriteRegStr HKLM "Software\HERMES CHU" "Version"    "1.2.0"

    WriteRegStr HKLM \
        "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES CHU" \
        "DisplayName"          "HERMES CHU 1.2.0"
    WriteRegStr HKLM \
        "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES CHU" \
        "DisplayVersion"       "1.2.0"
    WriteRegStr HKLM \
        "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES CHU" \
        "Publisher"            "William MERI — CHU de Guyane"
    WriteRegStr HKLM \
        "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES CHU" \
        "UninstallString"      "$INSTDIR\Uninstall.exe"
    WriteRegStr HKLM \
        "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES CHU" \
        "InstallLocation"      "$INSTDIR"
    WriteRegStr HKLM \
        "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES CHU" \
        "URLInfoAbout"         "https://github.com/Tarzzan/HERMES-CHU"
    WriteRegStr HKLM \
        "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES CHU" \
        "HelpLink"             "https://github.com/Tarzzan/HERMES-CHU/wiki"
    WriteRegDWORD HKLM \
        "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES CHU" \
        "NoModify" 1
    WriteRegDWORD HKLM \
        "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES CHU" \
        "NoRepair"  1

    ; Calculer la taille installée
    ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
    IntFmt $0 "0x%08X" $0
    WriteRegDWORD HKLM \
        "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES CHU" \
        "EstimatedSize" "$0"

    ; --- Écrire le désinstallateur ---
    WriteUninstaller "$INSTDIR\Uninstall.exe"

SectionEnd

;--------------------------------
; Section : Variables d'environnement
;--------------------------------
Section "Variables d'environnement système" SecEnv
    WriteRegExpandStr HKLM \
        "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" \
        "HERMES_CHU_HOME" "$INSTDIR"
    SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000
SectionEnd

;--------------------------------
; Désinstallateur
;--------------------------------
Section "Uninstall"
    ; Arrêter l'API CHU si en cours
    nsExec::Exec "taskkill /F /IM python.exe /FI $\"WINDOWTITLE eq HERMES CHU*$\""

    ; Supprimer les fichiers (conserver les données utilisateur)
    RMDir /r "$INSTDIR\upstream"
    RMDir /r "$INSTDIR\chu\api"
    RMDir /r "$INSTDIR\chu\privacy_engine"
    RMDir /r "$INSTDIR\chu\skills"
    RMDir /r "$INSTDIR\chu-desktop"
    RMDir /r "$INSTDIR\scripts"
    RMDir /r "$INSTDIR\assets"
    Delete "$INSTDIR\Uninstall.exe"
    Delete "$INSTDIR\README.md"

    ; Conserver : chu\.env.chu, chu\data\, chu\logs\
    DetailPrint "Les données utilisateur (logs, configuration) sont conservées dans $INSTDIR\chu\"

    ; Supprimer les raccourcis
    Delete "$DESKTOP\HERMES CHU.lnk"
    RMDir /r "$SMPROGRAMS\HERMES CHU"

    ; Nettoyer le registre
    DeleteRegKey HKLM "Software\HERMES CHU"
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES CHU"
    DeleteRegValue HKLM \
        "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" \
        "HERMES_CHU_HOME"

    ; Tenter de supprimer le répertoire (échouera si des données sont présentes)
    RMDir "$INSTDIR"

SectionEnd
