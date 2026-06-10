; =============================================================================
; HERMES CHU Desktop — Installateur Windows (NSIS)
; =============================================================================
; Génère : HERMES-CHU-Setup-1.0.0.exe
;
; Prérequis pour compiler :
;   NSIS 3.09+ (https://nsis.sourceforge.io)
;   Plugins : NsisMultiUser, nsProcess, UAC, MUI2
;
; Compilation :
;   makensis HERMES-CHU-Setup.nsi
; =============================================================================

Unicode True
ManifestSupportedOS all
ManifestDPIAware true

; ---------------------------------------------------------------------------
; Métadonnées
; ---------------------------------------------------------------------------
!define APP_NAME        "HERMES CHU"
!define APP_VERSION     "1.0.0"
!define APP_PUBLISHER   "CHU — Système Agentique Hospitalier"
!define APP_URL         "https://github.com/Tarzzan/HERMES-CHU"
!define APP_EXE         "hermes-chu.exe"
!define APP_GUID        "{A8F3C2D1-4E7B-4F9A-8C2D-1E3F5A7B9C0D}"
!define UNINSTALL_KEY   "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_GUID}"
!define INSTALL_REG_KEY "Software\HERMES-CHU"

; Répertoire d'installation par défaut
!define DEFAULT_INSTALL_DIR "$PROGRAMFILES64\HERMES CHU"

; ---------------------------------------------------------------------------
; Inclusions NSIS
; ---------------------------------------------------------------------------
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "WinVer.nsh"
!include "x64.nsh"
!include "FileFunc.nsh"
!include "nsDialogs.nsh"
!include "WordFunc.nsh"

; ---------------------------------------------------------------------------
; Configuration générale
; ---------------------------------------------------------------------------
Name                "${APP_NAME} ${APP_VERSION}"
OutFile             "..\HERMES-CHU-Setup-${APP_VERSION}.exe"
InstallDir          "${DEFAULT_INSTALL_DIR}"
InstallDirRegKey    HKLM "${INSTALL_REG_KEY}" "InstallPath"
RequestExecutionLevel admin
ShowInstDetails     show
ShowUninstDetails   show
SetCompressor       /SOLID lzma
SetCompressorDictSize 64

; ---------------------------------------------------------------------------
; Variables
; ---------------------------------------------------------------------------
Var InstallMode         ; "all" ou "current"
Var PythonFound
Var NodeFound
Var GitFound
Var AzureEndpoint
Var AzureApiKey
Var PrivacyEnabled
Var CHUApiPort
Var Dialog
Var Label
Var TextField
Var CheckBox

; ---------------------------------------------------------------------------
; Interface MUI2 — Thème CHU
; ---------------------------------------------------------------------------
!define MUI_ABORTWARNING
!define MUI_ICON                    "..\assets\hermes-chu.ico"
!define MUI_UNICON                  "..\assets\hermes-chu.ico"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP      "..\assets\header-chu.bmp"
!define MUI_HEADERIMAGE_RIGHT
!define MUI_WELCOMEFINISHPAGE_BITMAP "..\assets\welcome-chu.bmp"
!define MUI_WELCOMEPAGE_TITLE       "Bienvenue dans l'installation de HERMES CHU"
!define MUI_WELCOMEPAGE_TEXT        "HERMES CHU est un système agentique hospitalier souverain basé sur Hermes Agent (NousResearch).$\r$\n$\r$\nCet assistant vous guidera dans l'installation complète, incluant la configuration du Privacy Engine RGPD et la connexion à votre fournisseur IA.$\r$\n$\r$\nFermez toutes les applications avant de continuer."
!define MUI_FINISHPAGE_RUN          "$INSTDIR\${APP_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT     "Lancer HERMES CHU"
!define MUI_FINISHPAGE_SHOWREADME   "$INSTDIR\README.md"
!define MUI_FINISHPAGE_SHOWREADME_TEXT "Afficher le guide de démarrage"
!define MUI_FINISHPAGE_LINK         "Documentation en ligne"
!define MUI_FINISHPAGE_LINK_LOCATION "${APP_URL}/wiki"

; Couleurs CHU (bleu médical)
!define MUI_BGCOLOR                 "FFFFFF"
!define MUI_TEXTCOLOR               "1A2B4A"

; ---------------------------------------------------------------------------
; Pages d'installation
; ---------------------------------------------------------------------------
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE       "..\assets\LICENSE.txt"
Page custom PagePrerequis PagePrerequis_Leave
!insertmacro MUI_PAGE_DIRECTORY
Page custom PageConfigCHU PageConfigCHU_Leave
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

; Pages de désinstallation
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; Langues
!insertmacro MUI_LANGUAGE "French"

; ---------------------------------------------------------------------------
; Page personnalisée — Vérification des prérequis
; ---------------------------------------------------------------------------
Function PagePrerequis
    nsDialogs::Create 1018
    Pop $Dialog
    ${If} $Dialog == error
        Abort
    ${EndIf}

    ${NSD_CreateLabel} 0 0 100% 20u "Vérification des prérequis système…"
    Pop $Label
    CreateFont $0 "Segoe UI" 10 700
    SendMessage $Label ${WM_SETFONT} $0 1

    ; Vérifier Node.js
    nsExec::ExecToStack 'node --version'
    Pop $0
    Pop $NodeFound
    ${If} $0 == 0
        ${NSD_CreateLabel} 10 30 100% 12u "✅  Node.js : $NodeFound (requis ≥ 22)"
        Pop $Label
    ${Else}
        ${NSD_CreateLabel} 10 30 100% 12u "❌  Node.js non trouvé — sera installé automatiquement"
        Pop $Label
        StrCpy $NodeFound ""
    ${EndIf}

    ; Vérifier Python
    nsExec::ExecToStack 'python --version'
    Pop $0
    Pop $PythonFound
    ${If} $0 == 0
        ${NSD_CreateLabel} 10 50 100% 12u "✅  Python : $PythonFound (requis ≥ 3.11)"
        Pop $Label
    ${Else}
        ${NSD_CreateLabel} 10 50 100% 12u "❌  Python non trouvé — sera installé automatiquement"
        Pop $Label
        StrCpy $PythonFound ""
    ${EndIf}

    ; Vérifier Git
    nsExec::ExecToStack 'git --version'
    Pop $0
    Pop $GitFound
    ${If} $0 == 0
        ${NSD_CreateLabel} 10 70 100% 12u "✅  Git : $GitFound"
        Pop $Label
    ${Else}
        ${NSD_CreateLabel} 10 70 100% 12u "❌  Git non trouvé — sera installé automatiquement"
        Pop $Label
        StrCpy $GitFound ""
    ${EndIf}

    ${NSD_CreateLabel} 0 100 100% 30u "Les prérequis manquants seront téléchargés et installés automatiquement. Une connexion Internet est requise."
    Pop $Label

    nsDialogs::Show
FunctionEnd

Function PagePrerequis_Leave
FunctionEnd

; ---------------------------------------------------------------------------
; Page personnalisée — Configuration CHU
; ---------------------------------------------------------------------------
Function PageConfigCHU
    nsDialogs::Create 1018
    Pop $Dialog
    ${If} $Dialog == error
        Abort
    ${EndIf}

    ${NSD_CreateLabel} 0 0 100% 20u "Configuration HERMES CHU"
    Pop $Label
    CreateFont $0 "Segoe UI" 10 700
    SendMessage $Label ${WM_SETFONT} $0 1

    ; --- Fournisseur IA ---
    ${NSD_CreateGroupBox} 0 25 100% 65u "Fournisseur IA (modifiable après installation)"
    Pop $0

    ${NSD_CreateLabel} 10 42 90u 12u "Azure OpenAI Endpoint :"
    Pop $Label
    ${NSD_CreateText} 105 40 185u 12u "https://votre-ressource.openai.azure.com/"
    Pop $TextField
    ${NSD_OnChange} $TextField PageConfigCHU_EndpointChange

    ${NSD_CreateLabel} 10 62 90u 12u "Clé API Azure :"
    Pop $Label
    ${NSD_CreatePassword} 105 60 185u 12u ""
    Pop $TextField
    ${NSD_OnChange} $TextField PageConfigCHU_ApiKeyChange

    ${NSD_CreateLabel} 10 82 280u 10u "💡 Laissez vide pour configurer après l'installation via l'interface."
    Pop $Label

    ; --- Privacy Engine ---
    ${NSD_CreateGroupBox} 0 100 100% 40u "Privacy Engine RGPD"
    Pop $0

    ${NSD_CreateCheckBox} 10 115 280u 12u "Activer l'anonymisation RGPD dès le démarrage (recommandé)"
    Pop $CheckBox
    ${NSD_Check} $CheckBox
    StrCpy $PrivacyEnabled "1"

    ${NSD_CreateLabel} 10 130 280u 10u "Le Privacy Engine anonymise les données de santé avant envoi au LLM."
    Pop $Label

    ; --- Port API CHU ---
    ${NSD_CreateGroupBox} 0 150 100% 30u "Port de l'API CHU"
    Pop $0

    ${NSD_CreateLabel} 10 165 80u 12u "Port (défaut 8001) :"
    Pop $Label
    ${NSD_CreateNumber} 95 163 50u 12u "8001"
    Pop $TextField
    ${NSD_OnChange} $TextField PageConfigCHU_PortChange
    StrCpy $CHUApiPort "8001"

    nsDialogs::Show
FunctionEnd

Function PageConfigCHU_EndpointChange
    Pop $TextField
    ${NSD_GetText} $TextField $AzureEndpoint
FunctionEnd

Function PageConfigCHU_ApiKeyChange
    Pop $TextField
    ${NSD_GetText} $TextField $AzureApiKey
FunctionEnd

Function PageConfigCHU_PortChange
    Pop $TextField
    ${NSD_GetText} $TextField $CHUApiPort
FunctionEnd

Function PageConfigCHU_Leave
    ${NSD_GetState} $CheckBox $PrivacyEnabled
FunctionEnd

; ---------------------------------------------------------------------------
; Section principale — Installation
; ---------------------------------------------------------------------------
Section "HERMES CHU Desktop" SecMain
    SectionIn RO  ; Obligatoire

    SetOutPath "$INSTDIR"
    SetOverwrite on

    DetailPrint "Installation de HERMES CHU ${APP_VERSION}…"

    ; --- Fichiers principaux ---
    File /r "..\dist\win-unpacked\*.*"

    ; --- Scripts CHU ---
    SetOutPath "$INSTDIR\chu"
    File /r "..\..\..\chu\*.*"

    ; --- Documentation ---
    SetOutPath "$INSTDIR\docs"
    File "..\..\..\README.md"
    File "..\..\..\HERMES_CHU_Livrable\HERMES_CHU_Dossier_Technique.md"

    ; --- Fichier de configuration CHU ---
    SetOutPath "$INSTDIR\chu"
    FileOpen $0 "$INSTDIR\chu\.env.chu" w
    FileWrite $0 "# HERMES CHU — Configuration générée par l'installateur$\r$\n"
    FileWrite $0 "# Date d'installation : $\r$\n"
    FileWrite $0 "$\r$\n"
    FileWrite $0 "# === Fournisseur IA ===$\r$\n"
    FileWrite $0 "FOURNISSEUR_ACTIF=azure_openai$\r$\n"
    FileWrite $0 "AZURE_OPENAI_ENDPOINT=$AzureEndpoint$\r$\n"
    FileWrite $0 "AZURE_OPENAI_API_KEY=$AzureApiKey$\r$\n"
    FileWrite $0 "AZURE_OPENAI_DEPLOYMENT=gpt-4o$\r$\n"
    FileWrite $0 "$\r$\n"
    FileWrite $0 "# === Privacy Engine ===$\r$\n"
    FileWrite $0 "PRIVACY_ENGINE_ACTIF=$PrivacyEnabled$\r$\n"
    FileWrite $0 "CHU_API_PORT=$CHUApiPort$\r$\n"
    FileWrite $0 "$\r$\n"
    FileWrite $0 "# === Base de données ===$\r$\n"
    FileWrite $0 "DATABASE_URL=sqlite:///$INSTDIR\chu\data\hermes_chu.db$\r$\n"
    FileWrite $0 "$\r$\n"
    FileWrite $0 "# === Journalisation ISO 27001 ===$\r$\n"
    FileWrite $0 "AUDIT_LOG_PATH=$INSTDIR\chu\logs\audit.jsonl$\r$\n"
    FileWrite $0 "LOG_LEVEL=INFO$\r$\n"
    FileClose $0

    ; --- Créer les dossiers de données ---
    CreateDirectory "$INSTDIR\chu\data"
    CreateDirectory "$INSTDIR\chu\logs"
    CreateDirectory "$INSTDIR\chu\cache"

    ; --- Raccourcis Bureau ---
    CreateShortcut "$DESKTOP\HERMES CHU.lnk" \
        "$INSTDIR\${APP_EXE}" "" \
        "$INSTDIR\${APP_EXE}" 0 \
        SW_SHOWNORMAL "" \
        "Système Agentique Hospitalier HERMES CHU"

    ; --- Menu Démarrer ---
    CreateDirectory "$SMPROGRAMS\HERMES CHU"
    CreateShortcut "$SMPROGRAMS\HERMES CHU\HERMES CHU.lnk" \
        "$INSTDIR\${APP_EXE}" "" \
        "$INSTDIR\${APP_EXE}" 0
    CreateShortcut "$SMPROGRAMS\HERMES CHU\Démarrer l'API CHU.lnk" \
        "powershell.exe" \
        '-ExecutionPolicy Bypass -File "$INSTDIR\chu\scripts\start-api-chu.ps1"' \
        "$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" 0
    CreateShortcut "$SMPROGRAMS\HERMES CHU\Documentation.lnk" \
        "$INSTDIR\docs\README.md"
    CreateShortcut "$SMPROGRAMS\HERMES CHU\Désinstaller HERMES CHU.lnk" \
        "$INSTDIR\Uninstall.exe"

    ; --- Registre Windows ---
    WriteRegStr   HKLM "${UNINSTALL_KEY}" "DisplayName"          "${APP_NAME}"
    WriteRegStr   HKLM "${UNINSTALL_KEY}" "DisplayVersion"       "${APP_VERSION}"
    WriteRegStr   HKLM "${UNINSTALL_KEY}" "Publisher"            "${APP_PUBLISHER}"
    WriteRegStr   HKLM "${UNINSTALL_KEY}" "URLInfoAbout"         "${APP_URL}"
    WriteRegStr   HKLM "${UNINSTALL_KEY}" "InstallLocation"      "$INSTDIR"
    WriteRegStr   HKLM "${UNINSTALL_KEY}" "UninstallString"      "$INSTDIR\Uninstall.exe"
    WriteRegStr   HKLM "${UNINSTALL_KEY}" "QuietUninstallString" "$INSTDIR\Uninstall.exe /S"
    WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoModify"             1
    WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoRepair"             0
    WriteRegStr   HKLM "${INSTALL_REG_KEY}" "InstallPath"        "$INSTDIR"
    WriteRegStr   HKLM "${INSTALL_REG_KEY}" "Version"            "${APP_VERSION}"

    ; Taille estimée (en KB)
    ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
    IntFmt $0 "0x%08X" $0
    WriteRegDWORD HKLM "${UNINSTALL_KEY}" "EstimatedSize" "$0"

    ; --- Désinstalleur ---
    WriteUninstaller "$INSTDIR\Uninstall.exe"

    DetailPrint "Installation terminée !"
SectionEnd

; ---------------------------------------------------------------------------
; Section optionnelle — Prérequis automatiques
; ---------------------------------------------------------------------------
Section "Installer les prérequis manquants" SecPrerequis
    SetOutPath "$TEMP\hermes-chu-prereqs"

    ; Installer Node.js si absent
    ${If} $NodeFound == ""
        DetailPrint "Téléchargement de Node.js 22 LTS…"
        inetc::get /CAPTION "Téléchargement Node.js" \
            "https://nodejs.org/dist/v22.13.0/node-v22.13.0-x64.msi" \
            "$TEMP\hermes-chu-prereqs\node-setup.msi" /END
        Pop $0
        ${If} $0 == "OK"
            DetailPrint "Installation de Node.js…"
            ExecWait 'msiexec /i "$TEMP\hermes-chu-prereqs\node-setup.msi" /quiet /norestart'
        ${Else}
            MessageBox MB_ICONEXCLAMATION "Impossible de télécharger Node.js. Installez-le manuellement depuis https://nodejs.org"
        ${EndIf}
    ${EndIf}

    ; Installer Python si absent
    ${If} $PythonFound == ""
        DetailPrint "Téléchargement de Python 3.11…"
        inetc::get /CAPTION "Téléchargement Python" \
            "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe" \
            "$TEMP\hermes-chu-prereqs\python-setup.exe" /END
        Pop $0
        ${If} $0 == "OK"
            DetailPrint "Installation de Python…"
            ExecWait '"$TEMP\hermes-chu-prereqs\python-setup.exe" /quiet InstallAllUsers=1 PrependPath=1 Include_pip=1'
        ${Else}
            MessageBox MB_ICONEXCLAMATION "Impossible de télécharger Python. Installez-le manuellement depuis https://python.org"
        ${EndIf}
    ${EndIf}

    ; Installer Git si absent
    ${If} $GitFound == ""
        DetailPrint "Téléchargement de Git…"
        inetc::get /CAPTION "Téléchargement Git" \
            "https://github.com/git-for-windows/git/releases/download/v2.47.0.windows.1/Git-2.47.0-64-bit.exe" \
            "$TEMP\hermes-chu-prereqs\git-setup.exe" /END
        Pop $0
        ${If} $0 == "OK"
            DetailPrint "Installation de Git…"
            ExecWait '"$TEMP\hermes-chu-prereqs\git-setup.exe" /VERYSILENT /NORESTART'
        ${EndIf}
    ${EndIf}

    ; Installer les dépendances Python CHU
    DetailPrint "Installation des dépendances Python CHU…"
    ExecWait 'python -m pip install --quiet fastapi uvicorn spacy redis sqlalchemy python-jose cryptography 2>&1'

    ; Télécharger le modèle spaCy français
    DetailPrint "Téléchargement du modèle NLP français (fr_core_news_lg)…"
    ExecWait 'python -m spacy download fr_core_news_lg --quiet 2>&1'

    RMDir /r "$TEMP\hermes-chu-prereqs"
SectionEnd

; ---------------------------------------------------------------------------
; Descriptions des sections
; ---------------------------------------------------------------------------
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${SecMain}     "Application HERMES CHU Desktop, Privacy Engine RGPD et API CHU."
    !insertmacro MUI_DESCRIPTION_TEXT ${SecPrerequis} "Installe automatiquement Node.js 22, Python 3.11 et Git s'ils sont absents."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

; ---------------------------------------------------------------------------
; Fonctions d'initialisation
; ---------------------------------------------------------------------------
Function .onInit
    ; Vérifier Windows 10 minimum
    ${IfNot} ${AtLeastWin10}
        MessageBox MB_ICONSTOP "HERMES CHU requiert Windows 10 ou supérieur."
        Abort
    ${EndIf}

    ; Vérifier architecture 64 bits
    ${IfNot} ${RunningX64}
        MessageBox MB_ICONSTOP "HERMES CHU requiert un système Windows 64 bits."
        Abort
    ${EndIf}

    ; Vérifier si déjà installé
    ReadRegStr $0 HKLM "${INSTALL_REG_KEY}" "InstallPath"
    ${If} $0 != ""
        MessageBox MB_YESNO|MB_ICONQUESTION \
            "HERMES CHU est déjà installé dans $0.$\r$\nVoulez-vous mettre à jour l'installation ?" \
            IDYES +2
        Abort
    ${EndIf}

    ; Initialiser les variables
    StrCpy $AzureEndpoint ""
    StrCpy $AzureApiKey ""
    StrCpy $PrivacyEnabled "1"
    StrCpy $CHUApiPort "8001"
FunctionEnd

Function .onInstSuccess
    ; Ouvrir le guide de démarrage rapide
    ExecShell "open" "$INSTDIR\docs\README.md"
FunctionEnd

; ---------------------------------------------------------------------------
; Section de désinstallation
; ---------------------------------------------------------------------------
Section "Uninstall"
    ; Arrêter les processus en cours
    nsProcess::_FindProcess "${APP_EXE}"
    Pop $0
    ${If} $0 == 0
        nsProcess::_KillProcess "${APP_EXE}"
        Sleep 1000
    ${EndIf}

    nsProcess::_FindProcess "python.exe"
    Pop $0
    ${If} $0 == 0
        ; Arrêter l'API CHU proprement
        nsExec::Exec 'taskkill /F /FI "WINDOWTITLE eq HERMES CHU API*"'
    ${EndIf}

    ; Supprimer les fichiers
    RMDir /r "$INSTDIR\resources"
    RMDir /r "$INSTDIR\locales"
    RMDir /r "$INSTDIR\chu"
    RMDir /r "$INSTDIR\docs"
    Delete "$INSTDIR\${APP_EXE}"
    Delete "$INSTDIR\*.dll"
    Delete "$INSTDIR\*.pak"
    Delete "$INSTDIR\*.dat"
    Delete "$INSTDIR\Uninstall.exe"
    RMDir "$INSTDIR"

    ; Supprimer les raccourcis
    Delete "$DESKTOP\HERMES CHU.lnk"
    RMDir /r "$SMPROGRAMS\HERMES CHU"

    ; Supprimer le registre
    DeleteRegKey HKLM "${UNINSTALL_KEY}"
    DeleteRegKey HKLM "${INSTALL_REG_KEY}"

    MessageBox MB_ICONINFORMATION "HERMES CHU a été désinstallé avec succès.$\r$\nVos données (logs, configuration) ont été conservées dans $APPDATA\HERMES-CHU."
SectionEnd
