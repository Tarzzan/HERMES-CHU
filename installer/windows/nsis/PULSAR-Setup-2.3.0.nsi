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
; ============================================================================

Unicode true
SetCompressor /SOLID lzma

; ---- Constantes produit ----
!define PRODUCT_NAME        "PULSAR"
!define PRODUCT_VERSION     "2.3.0"
!define PRODUCT_FULLNAME    "PULSAR - DSIO CHU de Guyane"
!define PRODUCT_PUBLISHER   "DSIO - CHU de Guyane"
!define PRODUCT_URL         "https://github.com/Tarzzan/HERMES-CHU"
!define PRODUCT_REGKEY      "Software\PULSAR-CHU"

; ---- URLs distantes ----
!define INSTALL_PS1_URL     "https://raw.githubusercontent.com/Tarzzan/HERMES-CHU/main/installer/windows/install-chu.ps1"

Name "${PRODUCT_FULLNAME} ${PRODUCT_VERSION}"
OutFile "output\PULSAR-Setup-2.3.0.exe"
InstallDir "$LOCALAPPDATA\hermes"
RequestExecutionLevel user
ShowInstDetails show

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "nsDialogs.nsh"
!include "WinMessages.nsh"

; ============================================================================
; MUI — Apparence
; ============================================================================
!define MUI_ABORTWARNING
!define MUI_ICON    "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON  "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"

!define MUI_WELCOMEPAGE_TITLE   "PULSAR ${PRODUCT_VERSION}"
!define MUI_WELCOMEPAGE_TEXT    "Bienvenue dans l'assistant d'installation de PULSAR.$\r$\n$\r$\nPlateforme Unifiee de Liaison, de Surveillance et d'Assistance en temps Reel$\r$\nDSIO - CHU de Guyane$\r$\n$\r$\nCet assistant va vous proposer de choisir le type d'installation qui vous convient.$\r$\n$\r$\nConcu par William MERI - DSIO CHU de Guyane"

!define MUI_FINISHPAGE_TITLE    "PULSAR installe avec succes !"
!define MUI_FINISHPAGE_TEXT     "PULSAR ${PRODUCT_VERSION} est pret.$\r$\n$\r$\nRaccourcis disponibles sur le Bureau selon votre choix.$\r$\n$\r$\nCommandes disponibles dans tout terminal :$\r$\n  pulsar dashboard$\r$\n  pulsar desktop$\r$\n  pulsar chat$\r$\n$\r$\nWilliam MERI - DSIO CHU de Guyane"
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
Var Label_Titre
Var Label_Desc

; Mode choisi par l'utilisateur :
;   0 = Complet (CLI+Web+Desktop)   [défaut]
;   1 = CLI / Web uniquement
;   2 = Desktop uniquement
;   3 = Réparer
;   4 = Mettre à jour
;   5 = Désinstaller
Var ModeInstall

; Boutons radio
Var Radio_Complet
Var Radio_CLI
Var Radio_Desktop
Var Radio_Reparer
Var Radio_MAJ
Var Radio_Desinstaller

; Est-ce que PULSAR est déjà installé ?
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
    ${NSD_CreateLabel} 0 0 100% 20u "Que souhaitez-vous faire ?"
    Pop $Label_Titre
    SetCtlColors $Label_Titre "" "transparent"
    CreateFont $0 "Segoe UI" "10" "700"
    SendMessage $Label_Titre ${WM_SETFONT} $0 1

    ; ---- Description contextuelle ----
    ${If} $DejaInstalle == "1"
        ${NSD_CreateLabel} 0 22u 100% 18u "PULSAR est deja installe sur ce poste. Choisissez une action :"
    ${Else}
        ${NSD_CreateLabel} 0 22u 100% 18u "Premiere installation — choisissez la version a installer :"
    ${EndIf}
    Pop $Label_Desc
    SetCtlColors $Label_Desc "" "transparent"

    ; ---- Séparateur ----
    ${NSD_CreateHLine} 0 42u 100% 1u ""
    Pop $0

    ; ============================================================
    ; BLOC "Nouvelle installation" (toujours visible)
    ; ============================================================
    ${NSD_CreateLabel} 0 46u 100% 12u "--- Nouvelle installation ---"
    Pop $0
    SetCtlColors $0 "0x005A9E" "transparent"

    ; Radio : Complet (recommandé)
    ${NSD_CreateRadioButton} 10u 60u 100% 14u "Installation complete  (CLI + Web + Desktop)  — Recommande"
    Pop $Radio_Complet
    ${NSD_Check} $Radio_Complet   ; coché par défaut

    ${NSD_CreateLabel} 22u 75u 90% 12u "Installe le moteur IA, le dashboard web ET l'application native Electron."
    Pop $0
    SetCtlColors $0 "0x555555" "transparent"

    ; Radio : CLI / Web
    ${NSD_CreateRadioButton} 10u 90u 100% 14u "CLI / Web uniquement  (leger, sans application native)"
    Pop $Radio_CLI

    ${NSD_CreateLabel} 22u 105u 90% 12u "Acces via navigateur : http://localhost:9119  |  Commande : pulsar dashboard"
    Pop $0
    SetCtlColors $0 "0x555555" "transparent"

    ; Radio : Desktop
    ${NSD_CreateRadioButton} 10u 120u 100% 14u "Desktop uniquement  (application Electron native)"
    Pop $Radio_Desktop

    ${NSD_CreateLabel} 22u 135u 90% 12u "Fenetre autonome, sans navigateur. Ideal pour les postes de travail."
    Pop $0
    SetCtlColors $0 "0x555555" "transparent"

    ; ============================================================
    ; BLOC "Installation existante" (visible seulement si installé)
    ; ============================================================
    ${If} $DejaInstalle == "1"

        ${NSD_CreateHLine} 0 152u 100% 1u ""
        Pop $0

        ${NSD_CreateLabel} 0 156u 100% 12u "--- Installation existante detectee ---"
        Pop $0
        SetCtlColors $0 "0x8B0000" "transparent"

        ; Radio : Réparer
        ${NSD_CreateRadioButton} 10u 170u 100% 14u "Reparer  (reinstalle les dependances, recompile)"
        Pop $Radio_Reparer

        ${NSD_CreateLabel} 22u 185u 90% 12u "Conserve votre configuration, vos credentials et vos sessions."
        Pop $0
        SetCtlColors $0 "0x555555" "transparent"

        ; Radio : Mettre à jour
        ${NSD_CreateRadioButton} 10u 200u 100% 14u "Mettre a jour  (git pull + rebuild)"
        Pop $Radio_MAJ

        ${NSD_CreateLabel} 22u 215u 90% 12u "Recupere la derniere version depuis GitHub et reconstruit l'interface."
        Pop $0
        SetCtlColors $0 "0x555555" "transparent"

        ; Radio : Désinstaller
        ${NSD_CreateRadioButton} 10u 230u 100% 14u "Desinstaller PULSAR"
        Pop $Radio_Desinstaller

        ${NSD_CreateLabel} 22u 245u 90% 20u "Supprime PULSAR proprement. Vos donnees dans ~/.pulsar/ (Vault, config) ne seront PAS supprimees."
        Pop $0
        SetCtlColors $0 "0x555555" "transparent"

    ${EndIf}

    nsDialogs::Show
FunctionEnd

; ---- Lecture du choix au clic Suivant ----
Function PageChoixModeLeave
    StrCpy $ModeInstall "0"   ; défaut : Complet

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
            ; Confirmation avant désinstallation
            MessageBox MB_YESNO|MB_ICONQUESTION "Etes-vous sur de vouloir desinstaller PULSAR ?$\r$\n$\r$\nVos donnees dans ~/.pulsar/ (Vault, credentials, config) seront conservees." IDYES +2
            Abort
        ${EndIf}
    ${EndIf}
FunctionEnd

; ============================================================================
; Section principale — dispatch selon le mode choisi
; ============================================================================
Section "PULSAR" SecMain
    SetOutPath "$INSTDIR"

    ; ---- Activation ExecutionPolicy ----
    DetailPrint "Configuration ExecutionPolicy PowerShell..."
    nsExec::ExecToLog 'powershell.exe -Command "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"'
    Pop $0

    ; ---- Vérification PowerShell ----
    DetailPrint "Verification de PowerShell..."
    nsExec::ExecToLog 'powershell.exe -Command "Write-Host PowerShell OK"'
    Pop $0
    ${If} $0 != 0
        MessageBox MB_ICONSTOP "PowerShell est requis. Installez Windows Management Framework 5.1."
        Abort
    ${EndIf}

    ; ---- Téléchargement du script PS1 ----
    DetailPrint "Telechargement du script d'installation PULSAR..."
    nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri \"${INSTALL_PS1_URL}\" -OutFile \"$TEMP\install-chu.ps1\" -UseBasicParsing"'
    Pop $0
    ${If} $0 != 0
        MessageBox MB_ICONSTOP "Impossible de telecharger le script.$\r$\nVerifiez votre connexion internet."
        Abort
    ${EndIf}

    ; ============================================================
    ; Dispatch selon le mode choisi
    ; ============================================================

    ; --- Mode 0 : Complet (CLI + Web + Desktop) ---
    ${If} $ModeInstall == "0"
        DetailPrint "Mode : Installation complete (CLI + Web + Desktop)"
        DetailPrint "Etapes : uv > Python 3.11 > Git > Node.js 22 > hermes-agent > venv > deps > build web > desktop > CHU patches > Vault > PATH"
        nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -File "$TEMP\install-chu.ps1" -NonInteractive -IncludeDesktop'
        Pop $0
        Goto CheckResult
    ${EndIf}

    ; --- Mode 1 : CLI / Web uniquement ---
    ${If} $ModeInstall == "1"
        DetailPrint "Mode : CLI / Web uniquement (sans Desktop)"
        DetailPrint "Etapes : uv > Python 3.11 > Git > Node.js 22 > hermes-agent > venv > deps > build web > CHU patches > Vault > PATH"
        nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -File "$TEMP\install-chu.ps1" -NonInteractive'
        Pop $0
        Goto CheckResult
    ${EndIf}

    ; --- Mode 2 : Desktop uniquement ---
    ${If} $ModeInstall == "2"
        DetailPrint "Mode : Desktop uniquement (application Electron native)"
        DetailPrint "Etapes : uv > Python 3.11 > Git > Node.js 22 > hermes-agent > venv > deps > desktop > CHU patches > PATH"
        nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -File "$TEMP\install-chu.ps1" -NonInteractive -IncludeDesktop'
        Pop $0
        Goto CheckResult
    ${EndIf}

    ; --- Mode 3 : Réparer ---
    ${If} $ModeInstall == "3"
        DetailPrint "Mode : Reparation de l'installation existante"
        DetailPrint "Reinstallation des dependances et recompilation de l'interface..."
        nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -File "$TEMP\install-chu.ps1" -NonInteractive -PostInstall'
        Pop $0
        Goto CheckResult
    ${EndIf}

    ; --- Mode 4 : Mettre à jour ---
    ${If} $ModeInstall == "4"
        DetailPrint "Mode : Mise a jour (git pull + rebuild)"
        DetailPrint "Recuperation de la derniere version depuis GitHub..."
        nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -Command "& { cd \"$LOCALAPPDATA\hermes\hermes-chu\"; git pull origin main; cd web; npm run build }"'
        Pop $0
        Goto CheckResult
    ${EndIf}

    ; --- Mode 5 : Désinstaller ---
    ${If} $ModeInstall == "5"
        DetailPrint "Mode : Desinstallation de PULSAR"
        Call UninstallPulsar
        Goto Done
    ${EndIf}

    CheckResult:
    ${If} $0 != 0
        MessageBox MB_ICONEXCLAMATION "L'operation a rencontre une erreur (code $0).$\r$\nConsultez le journal ci-dessus.$\r$\n$\r$\nPour relancer manuellement :$\r$\n  powershell -File $TEMP\install-chu.ps1"
    ${Else}
        DetailPrint "Operation terminee avec succes."
    ${EndIf}

    Done:
    ; ---- Raccourcis Bureau ----
    ${If} $ModeInstall != "5"
    ${AndIf} $ModeInstall != "3"
        Call CreerRaccourcis
    ${EndIf}

    ; ---- Registre ----
    WriteRegStr HKCU "${PRODUCT_REGKEY}" "Version"    "${PRODUCT_VERSION}"
    WriteRegStr HKCU "${PRODUCT_REGKEY}" "InstallDir" "$INSTDIR"
    WriteRegStr HKCU "${PRODUCT_REGKEY}" "Mode"       "$ModeInstall"
    WriteUninstaller "$INSTDIR\uninstall-pulsar.exe"

SectionEnd

; ============================================================================
; Création des raccourcis Bureau
; ============================================================================
Function CreerRaccourcis
    DetailPrint "Creation des raccourcis Bureau..."

    ; PULSAR Dashboard (Web)
    ${If} $ModeInstall != "2"
        CreateShortCut "$DESKTOP\PULSAR.lnk" \
            "cmd.exe" \
            '/c start "" "http://localhost:9119" && powershell -ExecutionPolicy Bypass -Command "& { cd ''$LOCALAPPDATA\hermes\hermes-chu''; .venv\Scripts\pulsar.exe dashboard }"' \
            "$INSTDIR\favicon.ico" 0
    ${EndIf}

    ; PULSAR Desktop (Electron)
    ${If} $ModeInstall != "1"
        ${If} ${FileExists} "$LOCALAPPDATA\hermes\hermes-chu\apps\desktop\PULSAR.exe"
            CreateShortCut "$DESKTOP\PULSAR Desktop.lnk" \
                "$LOCALAPPDATA\hermes\hermes-chu\apps\desktop\PULSAR.exe" \
                "" "$LOCALAPPDATA\hermes\hermes-chu\apps\desktop\PULSAR.exe" 0
        ${EndIf}
    ${EndIf}

    ; PULSAR CLI (terminal)
    CreateShortCut "$DESKTOP\PULSAR CLI.lnk" \
        "cmd.exe" \
        '/k "$LOCALAPPDATA\hermes\hermes-chu\.venv\Scripts\pulsar.exe" chat' \
        "" 0
FunctionEnd

; ============================================================================
; Désinstallation propre
; ============================================================================
Function UninstallPulsar
    DetailPrint "Suppression des raccourcis Bureau..."
    Delete "$DESKTOP\PULSAR.lnk"
    Delete "$DESKTOP\PULSAR Desktop.lnk"
    Delete "$DESKTOP\PULSAR CLI.lnk"

    DetailPrint "Suppression des cles de registre..."
    DeleteRegKey HKCU "${PRODUCT_REGKEY}"

    DetailPrint "Suppression des fichiers PULSAR (hors donnees utilisateur)..."
    RMDir /r "$LOCALAPPDATA\hermes\hermes-chu"
    RMDir /r "$LOCALAPPDATA\hermes\hermes-agent"

    DetailPrint "Note : vos donnees (~/.pulsar/ : Vault, config, sessions) sont conservees."
    MessageBox MB_ICONINFORMATION "PULSAR a ete desinstalle.$\r$\n$\r$\nVos donnees dans ~/.pulsar/ (Vault, credentials, configuration) ont ete conservees.$\r$\nSupprimez ce dossier manuellement si vous souhaitez une desinstallation complete."
FunctionEnd

; ============================================================================
; Lancement PULSAR au clic sur "Lancer maintenant"
; ============================================================================
Function LaunchPulsar
    ${If} $ModeInstall == "2"
        ; Desktop uniquement
        ${If} ${FileExists} "$LOCALAPPDATA\hermes\hermes-chu\apps\desktop\PULSAR.exe"
            Exec '"$LOCALAPPDATA\hermes\hermes-chu\apps\desktop\PULSAR.exe"'
        ${EndIf}
    ${Else}
        ; Web dashboard
        ExecShell "open" "http://localhost:9119"
        nsExec::Exec 'powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -Command "& { cd ''$LOCALAPPDATA\hermes\hermes-chu''; .venv\Scripts\pulsar.exe dashboard }"'
    ${EndIf}
FunctionEnd

; ============================================================================
; Section désinstallateur (appelée par uninstall-pulsar.exe)
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
