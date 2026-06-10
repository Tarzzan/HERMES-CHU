; ============================================================
; HERMES CHU - Bootstrap Installer v2.1.0
; Concu par William MERI - CHU de Guyane
; Telecharge et execute install-chu.ps1 (fork de NousResearch)
; v2.1.0 : Correction raccourcis - setup automatique au 1er lancement
; ============================================================

Unicode true
SetCompressor /SOLID lzma

!define PRODUCT_NAME      "HERMES CHU"
!define PRODUCT_VERSION   "2.1.0"
!define PRODUCT_PUBLISHER "William MERI - CHU de Guyane"
!define PRODUCT_URL       "https://github.com/Tarzzan/HERMES-CHU"
!define INSTALL_PS1_URL   "https://raw.githubusercontent.com/Tarzzan/HERMES-CHU/main/installer/windows/install-chu.ps1"
!define LAUNCH_PS1_URL    "https://raw.githubusercontent.com/Tarzzan/HERMES-CHU/main/installer/windows/scripts/Launch-HERMES-CHU.ps1"

Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "output\HERMES-CHU-Setup-2.1.0.exe"
InstallDir "$LOCALAPPDATA\hermes"
RequestExecutionLevel user
ShowInstDetails show

!include "MUI2.nsh"
!include "LogicLib.nsh"

; MUI Settings
!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "${NSISDIR}\Contrib\Graphics\Wizard\win.bmp"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "${NSISDIR}\Contrib\Graphics\Header\win.bmp"

!define MUI_WELCOMEPAGE_TITLE "HERMES CHU ${PRODUCT_VERSION}"
!define MUI_WELCOMEPAGE_TEXT "Bienvenue dans l'assistant d'installation de HERMES CHU.$\r$\n$\r$\nSysteme Agentique Hospitalier Souverain base sur Hermes (NousResearch).$\r$\n$\r$\nCet assistant va :$\r$\n  - Installer Python 3.11, Node.js 22 et Git (si absents)$\r$\n  - Cloner le depot HERMES-CHU depuis GitHub$\r$\n  - Installer toutes les dependances$\r$\n  - Appliquer les patches CHU (Privacy Engine RGPD)$\r$\n  - Configurer votre fournisseur LLM$\r$\n$\r$\nDuree estimee : 5 a 15 minutes selon votre connexion.$\r$\n$\r$\nConcu par William MERI - CHU de Guyane"

!define MUI_FINISHPAGE_TITLE "Installation terminee !"
!define MUI_FINISHPAGE_TEXT "HERMES CHU a ete installe avec succes.$\r$\n$\r$\nPremier demarrage :$\r$\n  Cliquez sur le raccourci 'HERMES CHU' sur le Bureau.$\r$\n  L'assistant de configuration se lancera automatiquement.$\r$\n$\r$\nVous choisirez votre fournisseur LLM :$\r$\n  - ChatGPT (abonnement, sans cle API)$\r$\n  - Azure OpenAI, OpenAI, Ollama...$\r$\n$\r$\nDocumentation : github.com/Tarzzan/HERMES-CHU/wiki$\r$\n$\r$\nWilliam MERI - CHU de Guyane"
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Ouvrir la documentation HERMES CHU"
!define MUI_FINISHPAGE_RUN_FUNCTION "OpenDocs"

; Pages
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "license.txt"
Page custom PageAPropos
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_LANGUAGE "French"

; Variables
Var Dialog
Var Label

; Page A Propos
Function PageAPropos
    !insertmacro MUI_HEADER_TEXT "A propos de HERMES CHU" "Conception et developpement"
    nsDialogs::Create 1018
    Pop $Dialog
    ${If} $Dialog == error
        Abort
    ${EndIf}

    ${NSD_CreateLabel} 0 0 100% 200u "HERMES CHU v${PRODUCT_VERSION}$\r$\n$\r$\nSysteme Agentique Hospitalier Souverain$\r$\nBase sur Hermes Agent (NousResearch)$\r$\n$\r$\n--- Conception & Architecture ---$\r$\nWilliam MERI$\r$\nCHU de Guyane$\r$\nhttps://github.com/Tarzzan$\r$\n$\r$\n--- Moteur IA ---$\r$\nHermes Agent - NousResearch$\r$\nhttps://github.com/NousResearch/hermes-agent$\r$\n$\r$\n--- Conformite ---$\r$\nISO 27001 | HDS | RGPD$\r$\nPrivacy Engine 7 flux couverts$\r$\n$\r$\n--- Licence ---$\r$\nApache 2.0 - Usage medical sous responsabilite du CHU"
    Pop $Label

    nsDialogs::Show
FunctionEnd

; Installation
Section "HERMES CHU" SecMain
    SetOutPath "$INSTDIR"

    DetailPrint "Verification de PowerShell..."
    nsExec::ExecToLog 'powershell.exe -Command "Write-Host PowerShell OK"'
    Pop $0
    ${If} $0 != 0
        MessageBox MB_ICONSTOP "PowerShell est requis. Installez Windows Management Framework 5.1."
        Abort
    ${EndIf}

    DetailPrint "Telechargement de install-chu.ps1 depuis GitHub..."
    nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri \"${INSTALL_PS1_URL}\" -OutFile \"$TEMP\install-chu.ps1\" -UseBasicParsing"'
    Pop $0
    ${If} $0 != 0
        MessageBox MB_ICONSTOP "Impossible de telecharger install-chu.ps1. Verifiez votre connexion internet."
        Abort
    ${EndIf}

    DetailPrint "Telechargement de Launch-HERMES-CHU.ps1 depuis GitHub..."
    nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri \"${LAUNCH_PS1_URL}\" -OutFile \"$INSTDIR\Launch-HERMES-CHU.ps1\" -UseBasicParsing"'
    Pop $0
    ${If} $0 != 0
        DetailPrint "Avertissement : impossible de telecharger Launch-HERMES-CHU.ps1 (non bloquant)"
    ${EndIf}

    DetailPrint "Lancement de l'installation HERMES CHU (10-15 min)..."
    DetailPrint "Etapes : uv > Python 3.11 > Git > Node.js 22 > clone > venv > deps > CHU patches > PATH"
    nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -File "$TEMP\install-chu.ps1" -NonInteractive -IncludeDesktop'
    Pop $0
    ${If} $0 != 0
        MessageBox MB_ICONEXCLAMATION "L'installation a rencontre une erreur (code $0).$\r$\nConsultez le log ci-dessus pour le detail.$\r$\nVous pouvez relancer manuellement :$\r$\n  powershell -File $TEMP\install-chu.ps1"
    ${Else}
        DetailPrint "Installation HERMES CHU terminee avec succes !"
    ${EndIf}

    ; Ecriture des infos de desinstallation dans le registre
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES-CHU" "DisplayName" "${PRODUCT_NAME}"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES-CHU" "DisplayVersion" "${PRODUCT_VERSION}"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES-CHU" "Publisher" "${PRODUCT_PUBLISHER}"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES-CHU" "URLInfoAbout" "${PRODUCT_URL}"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES-CHU" "InstallLocation" "$INSTDIR"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES-CHU" "UninstallString" '"$INSTDIR\Uninstall-HERMES-CHU.exe"'
    WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES-CHU" "NoModify" 1
    WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES-CHU" "NoRepair" 1

    ; Desinstallateur
    WriteUninstaller "$INSTDIR\Uninstall-HERMES-CHU.exe"

    ; -------------------------------------------------------
    ; Raccourcis corriges v2.1.0 :
    ; Pointent vers Launch-HERMES-CHU.ps1 qui :
    ;   1. Recharge le PATH
    ;   2. Lance hermes setup si non configure
    ;   3. Lance hermes web
    ;   4. Garde la fenetre ouverte en cas d'erreur
    ; -------------------------------------------------------

    ; Raccourci Bureau
    CreateShortCut "$DESKTOP\HERMES CHU.lnk" \
        "powershell.exe" \
        '-ExecutionPolicy Bypass -NoExit -File "$INSTDIR\Launch-HERMES-CHU.ps1"' \
        "" "" SW_SHOWNORMAL

    ; Raccourcis Menu Demarrer
    CreateDirectory "$SMPROGRAMS\HERMES CHU"
    CreateShortCut "$SMPROGRAMS\HERMES CHU\HERMES CHU.lnk" \
        "powershell.exe" \
        '-ExecutionPolicy Bypass -NoExit -File "$INSTDIR\Launch-HERMES-CHU.ps1"' \
        "" "" SW_SHOWNORMAL
    CreateShortCut "$SMPROGRAMS\HERMES CHU\Documentation.lnk" "${PRODUCT_URL}/wiki"
    CreateShortCut "$SMPROGRAMS\HERMES CHU\Desinstaller.lnk" "$INSTDIR\Uninstall-HERMES-CHU.exe"

SectionEnd

; Desinstallation
Section "Uninstall"
    RMDir /r "$LOCALAPPDATA\hermes\hermes-chu"
    Delete "$INSTDIR\Launch-HERMES-CHU.ps1"
    Delete "$INSTDIR\Uninstall-HERMES-CHU.exe"
    Delete "$DESKTOP\HERMES CHU.lnk"
    RMDir /r "$SMPROGRAMS\HERMES CHU"
    DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\HERMES-CHU"
    MessageBox MB_ICONINFORMATION "HERMES CHU a ete desinstalle."
SectionEnd

Function OpenDocs
    ExecShell "open" "${PRODUCT_URL}/wiki"
FunctionEnd
