; ============================================================
;  HERMES CHU - Installateur Windows
;  Systeme Agentique Hospitalier Souverain
;  Version : 1.3.0 - Couverture RGPD totale (7 flux)
;  Compile avec NSIS 3.09 (Linux/makensis)
; ============================================================

Unicode True

;--------------------------------
; Includes
;--------------------------------
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"

;--------------------------------
; Metadonnees
;--------------------------------
Name              "HERMES CHU 1.3.0"
OutFile           "/home/ubuntu/nsis_build/output/HERMES-CHU-Setup-1.3.0.exe"
InstallDir        "$PROGRAMFILES64\HERMES CHU"
InstallDirRegKey  HKLM "Software\HERMES CHU" "InstallDir"
RequestExecutionLevel admin
SetCompressor     /SOLID lzma
SetCompressorDictSize 32

;--------------------------------
; Informations de version
;--------------------------------
VIProductVersion  "1.3.0.0"
VIAddVersionKey   "ProductName"      "HERMES CHU"
VIAddVersionKey   "ProductVersion"   "1.3.0"
VIAddVersionKey   "CompanyName"      "William MERI - CHU de Guyane"
VIAddVersionKey   "FileDescription"  "Systeme Agentique Hospitalier Souverain"
VIAddVersionKey   "FileVersion"      "1.3.0"
VIAddVersionKey   "LegalCopyright"   "(c) 2025-2026 CHU - Licence Apache 2.0"
VIAddVersionKey   "Comments"         "Concu par William MERI (CHU-Guyane) - Base sur NousResearch Hermes Agent"

;--------------------------------
; Interface MUI2
;--------------------------------
!define MUI_ABORTWARNING
!define MUI_ABORTWARNING_TEXT        "Annuler l'installation de HERMES CHU ?"

; --- A propos ---
!define MUI_COMPONENTSPAGE_NODESC
!define MUI_FINISHPAGE_NOAUTOCLOSE
!define MUI_ICON                    "/usr/share/nsis/Contrib/Graphics/Icons/modern-install-blue.ico"
!define MUI_UNICON                  "/usr/share/nsis/Contrib/Graphics/Icons/modern-uninstall-blue.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "/home/ubuntu/nsis_build/assets/sidebar.bmp"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP      "/home/ubuntu/nsis_build/assets/banner.bmp"
!define MUI_HEADERIMAGE_RIGHT

!define MUI_WELCOMEPAGE_TITLE       "Bienvenue dans HERMES CHU 1.3.0"
!define MUI_WELCOMEPAGE_TEXT        "Cet assistant va installer HERMES CHU - Systeme Agentique Hospitalier Souverain.$\r$\n$\r$\nHERMES CHU est base sur Hermes Agent de NousResearch, adapte pour les etablissements de sante avec :$\r$\n$\r$\n- Privacy Engine RGPD - 7 flux couverts (NER medical, memoire, skills, contexte)$\r$\n- Support multi-LLM (Azure OpenAI, OpenAI, Ollama, vLLM)$\r$\n- Agents specialises (Clinique, Administratif, Logistique, Recherche)$\r$\n- Conformite ISO 27001 et HDS$\r$\n$\r$\nIl est recommande de fermer toutes les autres applications avant de continuer."

!define MUI_FINISHPAGE_TITLE        "Installation terminee !"
!define MUI_FINISHPAGE_TEXT         "HERMES CHU 1.3.0 a ete installe avec succes.$\r$\n$\r$\nConcu par William MERI - CHU de Guyane$\r$\n$\r$\nProchaines etapes :$\r$\n1. Lancez l'assistant de configuration via le Menu Demarrer$\r$\n2. Renseignez vos parametres Azure OpenAI ou Ollama$\r$\n3. Activez le Privacy Engine RGPD$\r$\n4. Ouvrez HERMES CHU depuis le bureau$\r$\n$\r$\nDocumentation : github.com/Tarzzan/HERMES-CHU/wiki"
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
; Pages du desinstallateur
;--------------------------------
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

;--------------------------------
; Langues
;--------------------------------
!insertmacro MUI_LANGUAGE "French"

;--------------------------------
; Variables personnalisees
;--------------------------------
Var PrivacyEnabled
Var NodeFound
Var PythonFound
Var GitFound


;--------------------------------
; Page A propos - Credits William MERI
;--------------------------------
Function PageAPropos
    nsDialogs::Create 1018
    Pop $0

    ${NSD_CreateLabel} 0 0 100% 14u "HERMES CHU - Systeme Agentique Hospitalier Souverain"
    Pop $0
    SetCtlColors $0 0x003366 transparent

    ${NSD_CreateLabel} 0 20u 100% 1u ""
    Pop $0

    ${NSD_CreateGroupBox} 0 25u 100% 80u "Conception & Developpement"
    Pop $0

    ${NSD_CreateLabel} 10u 40u 100% 12u "Concepteur & Porteur de projet :"
    Pop $0

    ${NSD_CreateLabel} 10u 55u 100% 14u "William MERI - CHU de Guyane"
    Pop $0

    ${NSD_CreateLabel} 10u 75u 100% 10u "Architecte du systeme agentique hospitalier"
    Pop $0

    ${NSD_CreateLabel} 10u 88u 100% 10u "github.com/Tarzzan/HERMES-CHU"
    Pop $0

    ${NSD_CreateGroupBox} 0 115u 100% 50u "Technologie de base"
    Pop $0

    ${NSD_CreateLabel} 10u 130u 100% 10u "Base sur Hermes Agent - NousResearch"
    Pop $0

    ${NSD_CreateLabel} 10u 145u 100% 10u "Modele : Hermes-3-Llama-3.1-70B-Instruct"
    Pop $0

    ${NSD_CreateLabel} 10u 158u 100% 10u "Licence Apache 2.0 - Open Source"
    Pop $0

    ${NSD_CreateLabel} 0 175u 100% 10u "Version 1.3.0 - Juin 2026 - Conformite ISO 27001 & HDS & RGPD"
    Pop $0

    nsDialogs::Show
FunctionEnd

;--------------------------------
; Page Prerequis (personnalisee)
;--------------------------------
Function PagePrerequisites
    nsDialogs::Create 1018
    Pop $0

    ${NSD_CreateLabel} 0 0 100% 20u "Verification des prerequis systeme"
    Pop $0

    ; Verifier Node.js
    nsExec::ExecToStack "node --version"
    Pop $1  ; code retour
    Pop $2  ; sortie
    ${If} $1 == 0
        StrCpy $NodeFound "1"
        ${NSD_CreateLabel} 0 30u 100% 12u "? Node.js detecte : $2"
        Pop $0
    ${Else}
        StrCpy $NodeFound "0"
        ${NSD_CreateLabel} 0 30u 100% 12u "? Node.js non trouve - sera installe automatiquement"
        Pop $0
    ${EndIf}

    ; Verifier Python
    nsExec::ExecToStack "python --version"
    Pop $1
    Pop $2
    ${If} $1 == 0
        StrCpy $PythonFound "1"
        ${NSD_CreateLabel} 0 50u 100% 12u "? Python detecte : $2"
        Pop $0
    ${Else}
        StrCpy $PythonFound "0"
        ${NSD_CreateLabel} 0 50u 100% 12u "? Python non trouve - sera installe automatiquement"
        Pop $0
    ${EndIf}

    ; Verifier Git
    nsExec::ExecToStack "git --version"
    Pop $1
    Pop $2
    ${If} $1 == 0
        StrCpy $GitFound "1"
        ${NSD_CreateLabel} 0 70u 100% 12u "? Git detecte : $2"
        Pop $0
    ${Else}
        StrCpy $GitFound "0"
        ${NSD_CreateLabel} 0 70u 100% 12u "? Git non trouve - sera installe automatiquement"
        Pop $0
    ${EndIf}

    ${NSD_CreateLabel} 0 95u 100% 30u "Les prerequis manquants seront telecharges et installes automatiquement pendant l'installation. Une connexion Internet est requise."
    Pop $0

    nsDialogs::Show
FunctionEnd

Function PagePrerequisitesLeave
FunctionEnd

;--------------------------------
; Page Configuration CHU (personnalisee)
;--------------------------------
Function PageCHUConfig
    nsDialogs::Create 1018
    Pop $0

    ${NSD_CreateLabel} 0 0 100% 12u "Choisissez votre fournisseur IA"
    Pop $0

    ${NSD_CreateLabel} 0 18u 100% 10u "Fournisseur LLM :"
    Pop $0

    ${NSD_CreateDropList} 0 30u 280u 120u ""
    Pop $1
    ${NSD_CB_AddString} $1 "ChatGPT (abonnement Plus/Team/Enterprise)"
    ${NSD_CB_AddString} $1 "Nous Portal (abonnement NousResearch)"
    ${NSD_CB_AddString} $1 "Ollama (modeles locaux - sans cle API)"
    ${NSD_CB_AddString} $1 "LM Studio (modeles locaux - sans cle API)"
    ${NSD_CB_AddString} $1 "vLLM On-Premise (Hermes-3-70B)"
    ${NSD_CB_AddString} $1 "Azure OpenAI (certifie HDS - cle API requise)"
    ${NSD_CB_AddString} $1 "OpenAI API (cle API requise)"
    ${NSD_CB_AddString} $1 "Configurer plus tard"
    ${NSD_CB_SelectString} $1 "ChatGPT (abonnement Plus/Team/Enterprise)"

    ${NSD_CreateGroupBox} 0 55u 100% 70u "Connexion par abonnement (sans cle API)"
    Pop $0

    ${NSD_CreateLabel} 10u 70u 100% 22u "Aucune cle API requise. Lors du premier lancement, HERMES CHU affichera un code unique. Rendez-vous sur chatgpt.com/link et saisissez ce code pour autoriser la connexion."
    Pop $0

    ${NSD_CreateLabel} 10u 95u 100% 10u "Fonctionne avec : ChatGPT Plus (20 USD/mois), Team, Enterprise"
    Pop $0

    ${NSD_CreateLabel} 10u 108u 100% 10u "Modeles disponibles : GPT-4o, o1, o3, GPT-5"
    Pop $0

    ${NSD_CreateLabel} 0 135u 100% 10u "Privacy Engine RGPD :"
    Pop $0
    ${NSD_CreateCheckbox} 0 148u 100% 12u "Activer l'anonymisation RGPD des donnees de sante (recommande)"
    Pop $PrivacyEnabled
    ${NSD_Check} $PrivacyEnabled

    ${NSD_CreateLabel} 0 168u 100% 30u "RGPD : 7 flux couverts - entrees/sorties, memoire, revue de fond, trajectoires, skills, contexte. Aucun PHI ne persiste en clair, meme avec un LLM tiers."
    Pop $0

    nsDialogs::Show
FunctionEnd

Function OnProviderChange
    ; La configuration detaillee se fait au premier lancement via Configure-CHU.ps1
FunctionEnd

Function PageCHUConfigLeave
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

    ; --- Creer le fichier .env.chu ---
    FileOpen $0 "$INSTDIR\chu\.env.chu" w

    FileWrite $0 "# HERMES CHU - Configuration$\r$\n"
    FileWrite $0 "# Genere automatiquement par l'installateur$\r$\n"
    FileWrite $0 "$\r$\n"
    FileWrite $0 "# Fournisseur LLM actif$\r$\n"
    FileWrite $0 "# Configurez votre fournisseur au premier lancement via Configure-CHU.bat$\r$\n"
    FileWrite $0 "# Connexion par abonnement (sans cle API) : chatgpt.com/link$\r$\n"
    FileWrite $0 "FOURNISSEUR_ACTIF=openai-codex$\r$\n"
    FileWrite $0 "$\r$\n"
    FileWrite $0 "# ChatGPT abonnement (openai-codex) - code d appairage genere au 1er lancement$\r$\n"
    FileWrite $0 "# Aucune cle API requise - rendez-vous sur chatgpt.com/link$\r$\n"
    FileWrite $0 "CHATGPT_PROVIDER=openai-codex$\r$\n"
    FileWrite $0 "$\r$\n"
    FileWrite $0 "# Ollama (local - sans cle API)$\r$\n"
    FileWrite $0 "OLLAMA_BASE_URL=http://localhost:11434$\r$\n"
    FileWrite $0 "OLLAMA_MODEL=hermes3:70b$\r$\n"
    FileWrite $0 "$\r$\n"
    FileWrite $0 "# Azure OpenAI (HDS - cle API requise)$\r$\n"
    FileWrite $0 "AZURE_OPENAI_ENDPOINT=$\r$\n"
    FileWrite $0 "AZURE_OPENAI_API_KEY=$\r$\n"
    FileWrite $0 "AZURE_OPENAI_DEPLOYMENT=gpt-4o$\r$\n"
    FileWrite $0 "AZURE_OPENAI_API_VERSION=2024-02-01$\r$\n"
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
    FileWrite $0 "# Base de donnees$\r$\n"
    FileWrite $0 "DATABASE_URL=sqlite:///$INSTDIR\chu\data\hermes_chu.db$\r$\n"
    FileClose $0

    ; --- Creer les scripts .bat de lancement ---
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

    ; --- Raccourcis Menu Demarrer ---
    CreateShortcut "$SMPROGRAMS\HERMES CHU\HERMES CHU.lnk" \
        "$INSTDIR\scripts\Start-API-CHU.bat" "" \
        "$INSTDIR\assets\icon.ico" 0 \
        SW_SHOWMINIMIZED "" "Lancer HERMES CHU"

    CreateShortcut "$SMPROGRAMS\HERMES CHU\Configurer HERMES CHU.lnk" \
        "$INSTDIR\scripts\Configure-CHU.bat" "" \
        "$INSTDIR\assets\icon.ico" 0 \
        SW_SHOWNORMAL "" "Configurer HERMES CHU"

    CreateShortcut "$SMPROGRAMS\HERMES CHU\Installer les prerequis.lnk" \
        "$INSTDIR\scripts\Install-Prerequisites.bat" "" \
        "$INSTDIR\assets\icon.ico" 0 \
        SW_SHOWNORMAL "" "Installer les prerequis (Node.js, Python, Git)"

    CreateShortcut "$SMPROGRAMS\HERMES CHU\Documentation Wiki.lnk" \
        "https://github.com/Tarzzan/HERMES-CHU/wiki" "" "" 0

    CreateShortcut "$SMPROGRAMS\HERMES CHU\Desinstaller HERMES CHU.lnk" \
        "$INSTDIR\Uninstall.exe" "" "" 0

    ; --- Registre Windows ---
    WriteRegStr HKLM "Software\HERMES CHU" "InstallDir" "$INSTDIR"
    WriteRegStr HKLM "Software\HERMES CHU" "Version"    "1.3.0"

    WriteRegStr HKLM \
        "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES CHU" \
        "DisplayName"          "HERMES CHU 1.3.0"
    WriteRegStr HKLM \
        "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES CHU" \
        "DisplayVersion"       "1.3.0"
    WriteRegStr HKLM \
        "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES CHU" \
        "Publisher"            "William MERI - CHU de Guyane"
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

    ; Calculer la taille installee
    ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
    IntFmt $0 "0x%08X" $0
    WriteRegDWORD HKLM \
        "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES CHU" \
        "EstimatedSize" "$0"

    ; --- Ecrire le desinstallateur ---
    WriteUninstaller "$INSTDIR\Uninstall.exe"

SectionEnd

;--------------------------------
; Section : Variables d'environnement
;--------------------------------
Section "Variables d'environnement systeme" SecEnv
    WriteRegExpandStr HKLM \
        "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" \
        "HERMES_CHU_HOME" "$INSTDIR"
    SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000
SectionEnd

;--------------------------------
; Desinstallateur
;--------------------------------
Section "Uninstall"
    ; Arreter l'API CHU si en cours
    nsExec::Exec "taskkill /F /IM python.exe /FI $\"WINDOWTITLE eq HERMES CHU*$\""

    ; Supprimer les fichiers (conserver les donnees utilisateur)
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
    DetailPrint "Les donnees utilisateur (logs, configuration) sont conservees dans $INSTDIR\chu\"

    ; Supprimer les raccourcis
    Delete "$DESKTOP\HERMES CHU.lnk"
    RMDir /r "$SMPROGRAMS\HERMES CHU"

    ; Nettoyer le registre
    DeleteRegKey HKLM "Software\HERMES CHU"
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES CHU"
    DeleteRegValue HKLM \
        "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" \
        "HERMES_CHU_HOME"

    ; Tenter de supprimer le repertoire (echouera si des donnees sont presentes)
    RMDir "$INSTDIR"

SectionEnd
