; ============================================================================
; PULSAR-Setup-2.3.0.nsi
; Installateur graphique PULSAR — DSIO CHU de Guyane
;
; Fonctionnalités :
;   - Détection automatique d'une installation existante
;   - Page de choix graphique : CLI/Web | Desktop | Complet
;   - Mode Réparer / Mettre à jour / Désinstaller si déjà installé
;   - Tout en français
;   - Conçu par William MERI — DSIO CHU de Guyane
;
; NOTE : Ce script évite volontairement SetCtlColors, SendMessage et
;        CreateFont pour ne pas déclencher les heuristiques antivirus.
; ============================================================================

Unicode true
SetCompressor /SOLID lzma

; ---- Constantes produit ----
!define PRODUCT_NAME        "PULSAR"
!define PRODUCT_VERSION     "2.3.0"
!define PRODUCT_FULLNAME    "PULSAR - DSIO CHU de Guyane"
!define PRODUCT_PUBLISHER   "DSIO - CHU de Guyane"
!define PRODUCT_URL         "https://github.com/Tarzzan/PULSAR-CHU"
!define PRODUCT_REGKEY      "Software\PULSAR-CHU"

; ---- URLs distantes ----
!define INSTALL_PS1_URL "https://raw.githubusercontent.com/Tarzzan/PULSAR-CHU/main/installer/windows/install-chu.ps1"

Name "${PRODUCT_FULLNAME} ${PRODUCT_VERSION}"
OutFile "output\PULSAR-Setup-2.3.0.exe"
InstallDir "$LOCALAPPDATA\hermes"
RequestExecutionLevel user
ShowInstDetails show

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "nsDialogs.nsh"

; ============================================================================
; MUI — Apparence
; ============================================================================
!define MUI_ABORTWARNING
!define MUI_ICON    "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON  "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"

!define MUI_WELCOMEPAGE_TITLE "PULSAR ${PRODUCT_VERSION}"
!define MUI_WELCOMEPAGE_TEXT "Bienvenue dans l'assistant d'installation de PULSAR.$\r$\n$\r$\nPlateforme Unifiee de Liaison, de Surveillance et d'Assistance en temps Reel$\r$\nDSIO - CHU de Guyane$\r$\n$\r$\nCet assistant va vous proposer de choisir le type d'installation.$\r$\n$\r$\nConcu par William MERI - DSIO CHU de Guyane"

!define MUI_FINISHPAGE_TITLE "PULSAR installe avec succes !"
!define MUI_FINISHPAGE_TEXT "PULSAR ${PRODUCT_VERSION} est pret.$\r$\n$\r$\nCommandes disponibles dans tout terminal :$\r$\n  pulsar dashboard$\r$\n  pulsar desktop$\r$\n  pulsar chat$\r$\n$\r$\nWilliam MERI - DSIO CHU de Guyane"
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Lancer PULSAR maintenant"
!define MUI_FINISHPAGE_RUN_FUNCTION "LaunchPulsar"

; ============================================================================
; Pages
; ============================================================================
!insertmacro MUI_PAGE_WELCOME
Page custom PageChoixMode PageChoixModeLeave
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "French"

; ============================================================================
; Variables globales
; ============================================================================
Var Dialog

; Mode choisi :
;   0 = Complet (CLI+Web+Desktop)
;   1 = CLI / Web uniquement
;   2 = Desktop uniquement
;   3 = Reparer
;   4 = Mettre a jour
;   5 = Desinstaller
Var ModeInstall

Var Radio_Complet
Var Radio_CLI
Var Radio_Desktop
Var Radio_Reparer
Var Radio_MAJ
Var Radio_Desinstaller

Var DejaInstalle

; ============================================================================
; Détection d'une installation existante
; ============================================================================
Function DetecterInstallation
    StrCpy $DejaInstalle "0"
    ${If} ${FileExists} "$LOCALAPPDATA\hermes\hermes-chu\hermes_cli\__init__.py"
        StrCpy $DejaInstalle "1"
    ${EndIf}
    ${If} ${FileExists} "$LOCALAPPDATA\hermes\hermes-agent\hermes_cli\__init__.py"
        StrCpy $DejaInstalle "1"
    ${EndIf}
FunctionEnd

; ============================================================================
; Page de choix du mode d'installation
; ============================================================================
Function PageChoixMode
    Call DetecterInstallation

    !insertmacro MUI_HEADER_TEXT "Type d'installation" "Choisissez ce que vous souhaitez faire"

    nsDialogs::Create 1018
    Pop $Dialog
    ${If} $Dialog == error
        Abort
    ${EndIf}

    ; ---- Titre ----
    ${NSD_CreateLabel} 0 0 100% 14u "Que souhaitez-vous faire ?"

    ; ---- Description ----
    ${If} $DejaInstalle == "1"
        ${NSD_CreateLabel} 0 16u 100% 14u "PULSAR est deja installe. Choisissez une action :"
    ${Else}
        ${NSD_CreateLabel} 0 16u 100% 14u "Premiere installation - choisissez la version a installer :"
    ${EndIf}

    ${NSD_CreateHLine} 0 33u 100% 1u ""

    ; ---- Nouvelle installation ----
    ${NSD_CreateLabel} 0 37u 100% 12u "Nouvelle installation :"

    ${NSD_CreateRadioButton} 10u 51u 100% 12u "Installation complete (CLI + Web + Desktop) - Recommande"
    Pop $Radio_Complet
    ${NSD_Check} $Radio_Complet

    ${NSD_CreateLabel} 22u 64u 90% 10u "Installe le moteur IA, le dashboard web et l'application native."

    ${NSD_CreateRadioButton} 10u 76u 100% 12u "CLI / Web uniquement (leger, sans application native)"
    Pop $Radio_CLI

    ${NSD_CreateLabel} 22u 89u 90% 10u "Acces via navigateur : http://localhost:9119"

    ${NSD_CreateRadioButton} 10u 101u 100% 12u "Desktop uniquement (application Electron native)"
    Pop $Radio_Desktop

    ${NSD_CreateLabel} 22u 114u 90% 10u "Fenetre autonome, sans navigateur. Ideal pour les postes de travail."

    ; ---- Installation existante ----
    ${If} $DejaInstalle == "1"

        ${NSD_CreateHLine} 0 127u 100% 1u ""
        ${NSD_CreateLabel} 0 131u 100% 12u "Installation existante detectee :"

        ${NSD_CreateRadioButton} 10u 145u 100% 12u "Reparer (reinstalle les dependances, recompile)"
        Pop $Radio_Reparer

        ${NSD_CreateLabel} 22u 158u 90% 10u "Conserve votre configuration, vos credentials et vos sessions."

        ${NSD_CreateRadioButton} 10u 170u 100% 12u "Mettre a jour (git pull + rebuild)"
        Pop $Radio_MAJ

        ${NSD_CreateLabel} 22u 183u 90% 10u "Recupere la derniere version depuis GitHub."

        ${NSD_CreateRadioButton} 10u 195u 100% 12u "Desinstaller PULSAR"
        Pop $Radio_Desinstaller

        ${NSD_CreateLabel} 22u 208u 90% 14u "Supprime PULSAR. Vos donnees ~/.pulsar/ (Vault, config) sont conservees."

    ${EndIf}

    nsDialogs::Show
FunctionEnd

; ---- Lecture du choix ----
Function PageChoixModeLeave
    StrCpy $ModeInstall "0"

    ${NSD_GetState} $Radio_CLI $0
    ${If} $0 == ${BST_CHECKED}
        StrCpy $ModeInstall "1"
    ${EndIf}

    ${NSD_GetState} $Radio_Desktop $0
    ${If} $0 == ${BST_CHECKED}
        StrCpy $ModeInstall "2"
    ${EndIf}

    ${If} $DejaInstalle == "1"
        ${NSD_GetState} $Radio_Reparer $0
        ${If} $0 == ${BST_CHECKED}
            StrCpy $ModeInstall "3"
        ${EndIf}

        ${NSD_GetState} $Radio_MAJ $0
        ${If} $0 == ${BST_CHECKED}
            StrCpy $ModeInstall "4"
        ${EndIf}

        ${NSD_GetState} $Radio_Desinstaller $0
        ${If} $0 == ${BST_CHECKED}
            StrCpy $ModeInstall "5"
            MessageBox MB_YESNO|MB_ICONQUESTION "Etes-vous sur de vouloir desinstaller PULSAR ?$\r$\n$\r$\nVos donnees ~/.pulsar/ seront conservees." IDYES +2
            Abort
        ${EndIf}
    ${EndIf}
FunctionEnd

; ============================================================================
; Section principale
; ============================================================================
Section "PULSAR" SecMain
    SetOutPath "$INSTDIR"

    ; Activation ExecutionPolicy
    DetailPrint "Configuration ExecutionPolicy PowerShell..."
    nsExec::ExecToLog 'powershell.exe -Command "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"'
    Pop $0

    ; Verification PowerShell
    DetailPrint "Verification de PowerShell..."
    nsExec::ExecToLog 'powershell.exe -Command "Write-Host PowerShell OK"'
    Pop $0
    ${If} $0 != 0
        MessageBox MB_ICONSTOP "PowerShell est requis. Installez Windows Management Framework 5.1."
        Abort
    ${EndIf}

    ; Telechargement du script PS1
    DetailPrint "Telechargement du script d'installation PULSAR..."
    nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri \"${INSTALL_PS1_URL}\" -OutFile \"$TEMP\install-chu.ps1\" -UseBasicParsing"'
    Pop $0
    ${If} $0 != 0
        MessageBox MB_ICONSTOP "Impossible de telecharger le script.$\r$\nVerifiez votre connexion internet."
        Abort
    ${EndIf}

    ; Dispatch selon le mode
    ${If} $ModeInstall == "0"
        DetailPrint "Mode : Installation complete (CLI + Web + Desktop)"
        nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -File "$TEMP\install-chu.ps1" -NonInteractive -IncludeDesktop'
        Pop $0
        Goto CheckResult
    ${EndIf}

    ${If} $ModeInstall == "1"
        DetailPrint "Mode : CLI / Web uniquement"
        nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -File "$TEMP\install-chu.ps1" -NonInteractive'
        Pop $0
        Goto CheckResult
    ${EndIf}

    ${If} $ModeInstall == "2"
        DetailPrint "Mode : Desktop uniquement"
        nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -File "$TEMP\install-chu.ps1" -NonInteractive -IncludeDesktop'
        Pop $0
        Goto CheckResult
    ${EndIf}

    ${If} $ModeInstall == "3"
        DetailPrint "Mode : Reparation"
        nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -File "$TEMP\install-chu.ps1" -NonInteractive -PostInstall'
        Pop $0
        Goto CheckResult
    ${EndIf}

    ${If} $ModeInstall == "4"
        DetailPrint "Mode : Mise a jour (git pull + rebuild)"
        nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -Command "& { Set-Location \"$LOCALAPPDATA\hermes\hermes-chu\"; git pull origin main; Set-Location web; npm run build }"'
        Pop $0
        Goto CheckResult
    ${EndIf}

    ${If} $ModeInstall == "5"
        DetailPrint "Mode : Desinstallation"
        Call UninstallPulsar
        Goto Done
    ${EndIf}

    CheckResult:
    ${If} $0 != 0
        MessageBox MB_ICONEXCLAMATION "L'operation a rencontre une erreur (code $0).$\r$\nConsultez le journal ci-dessus.$\r$\n$\r$\nPour relancer :$\r$\n  powershell -File $TEMP\install-chu.ps1"
    ${Else}
        DetailPrint "Operation terminee avec succes."
    ${EndIf}

    Done:
    ${If} $ModeInstall != "5"
        Call CreerRaccourcis
    ${EndIf}

    WriteRegStr HKCU "${PRODUCT_REGKEY}" "Version"    "${PRODUCT_VERSION}"
    WriteRegStr HKCU "${PRODUCT_REGKEY}" "InstallDir" "$INSTDIR"
    WriteUninstaller "$INSTDIR\uninstall-pulsar.exe"

SectionEnd

; ============================================================================
; Raccourcis Bureau
; ============================================================================
Function CreerRaccourcis
    DetailPrint "Creation des raccourcis Bureau..."

    ${If} $ModeInstall != "2"
        CreateShortCut "$DESKTOP\PULSAR.lnk" "cmd.exe" "/c start http://localhost:9119"
    ${EndIf}

    ${If} $ModeInstall != "1"
        ${If} ${FileExists} "$LOCALAPPDATA\hermes\hermes-chu\apps\desktop\PULSAR.exe"
            CreateShortCut "$DESKTOP\PULSAR Desktop.lnk" "$LOCALAPPDATA\hermes\hermes-chu\apps\desktop\PULSAR.exe"
        ${EndIf}
    ${EndIf}

    CreateShortCut "$DESKTOP\PULSAR CLI.lnk" "cmd.exe" "/k pulsar chat"
FunctionEnd

; ============================================================================
; Désinstallation
; ============================================================================
Function UninstallPulsar
    DetailPrint "Suppression des raccourcis Bureau..."
    Delete "$DESKTOP\PULSAR.lnk"
    Delete "$DESKTOP\PULSAR Desktop.lnk"
    Delete "$DESKTOP\PULSAR CLI.lnk"

    DetailPrint "Suppression des cles de registre..."
    DeleteRegKey HKCU "${PRODUCT_REGKEY}"

    DetailPrint "Suppression des fichiers PULSAR..."
    RMDir /r "$LOCALAPPDATA\hermes\hermes-chu"
    RMDir /r "$LOCALAPPDATA\hermes\hermes-agent"

    MessageBox MB_ICONINFORMATION "PULSAR a ete desinstalle.$\r$\n$\r$\nVos donnees ~/.pulsar/ (Vault, credentials, config) ont ete conservees."
FunctionEnd

; ============================================================================
; Lancement PULSAR
; ============================================================================
Function LaunchPulsar
    ${If} $ModeInstall == "2"
        ${If} ${FileExists} "$LOCALAPPDATA\hermes\hermes-chu\apps\desktop\PULSAR.exe"
            Exec '"$LOCALAPPDATA\hermes\hermes-chu\apps\desktop\PULSAR.exe"'
        ${EndIf}
    ${Else}
        ExecShell "open" "http://localhost:9119"
    ${EndIf}
FunctionEnd

; ============================================================================
; Section désinstallateur
; ============================================================================
Section "Uninstall"
    Delete "$DESKTOP\PULSAR.lnk"
    Delete "$DESKTOP\PULSAR Desktop.lnk"
    Delete "$DESKTOP\PULSAR CLI.lnk"
    DeleteRegKey HKCU "${PRODUCT_REGKEY}"
    RMDir /r "$LOCALAPPDATA\hermes\hermes-chu"
    RMDir /r "$LOCALAPPDATA\hermes\hermes-agent"
    MessageBox MB_ICONINFORMATION "PULSAR desinstalle. Vos donnees ~/.pulsar/ sont conservees."
SectionEnd
