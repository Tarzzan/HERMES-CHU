; ============================================================
; PULSAR - Systeme Agentique Medical
; Installateur v2.2.0
; DSIO - CHU de Guyane | William MERI
;
; Nouveautes v2.2.0 :
;   - Renomme PULSAR (identite propre au CHU de Guyane)
;   - Installe l'application desktop Electron (hermes desktop)
;   - Installe la commande "pulsar" (wrapper .bat sans ExecutionPolicy)
;   - Icone PULSAR sur tous les raccourcis
;   - Applique les themes PULSAR (nuit + jour) automatiquement
;   - Corrige le chat (build web UI complet avant lancement)
;   - Raccourcis : PULSAR (web), PULSAR Desktop, PULSAR CLI
; ============================================================

Unicode true
SetCompressor /SOLID lzma

!define PRODUCT_NAME      "PULSAR"
!define PRODUCT_FULLNAME  "PULSAR - Systeme Agentique Medical"
!define PRODUCT_VERSION   "2.2.0"
!define PRODUCT_PUBLISHER "William MERI - DSIO CHU de Guyane"
!define PRODUCT_URL       "https://github.com/Tarzzan/PULSAR-CHU"

; URLs des scripts sur GitHub
!define INSTALL_PS1_URL   "https://raw.githubusercontent.com/Tarzzan/PULSAR-CHU/main/installer/windows/install-chu.ps1"
!define PULSAR_BAT_URL    "https://raw.githubusercontent.com/Tarzzan/PULSAR-CHU/main/chu/branding/desktop/pulsar.bat"
!define INSTALL_BAT_URL   "https://raw.githubusercontent.com/Tarzzan/PULSAR-CHU/main/chu/branding/desktop/Install-PULSAR-Command.bat"
!define PULSAR_ICO_URL    "https://raw.githubusercontent.com/Tarzzan/PULSAR-CHU/main/chu/branding/desktop/pulsar.ico"
!define THEME_DARK_URL    "https://raw.githubusercontent.com/Tarzzan/PULSAR-CHU/main/chu/branding/pulsar-assets/pulsar-theme.yaml"
!define THEME_LIGHT_URL   "https://raw.githubusercontent.com/Tarzzan/PULSAR-CHU/main/chu/branding/pulsar-light/pulsar-light-theme.yaml"
!define SKIN_DARK_URL     "https://raw.githubusercontent.com/Tarzzan/PULSAR-CHU/main/chu/branding/pulsar-assets/pulsar-skin.yaml"
!define SKIN_LIGHT_URL    "https://raw.githubusercontent.com/Tarzzan/PULSAR-CHU/main/chu/branding/pulsar-light/pulsar-light-skin.yaml"

Name "${PRODUCT_FULLNAME} ${PRODUCT_VERSION}"
OutFile "output\PULSAR-Setup-2.2.0.exe"
InstallDir "$LOCALAPPDATA\hermes"
RequestExecutionLevel user
ShowInstDetails show

!include "MUI2.nsh"
!include "LogicLib.nsh"

; ---- MUI Settings ----
!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "${NSISDIR}\Contrib\Graphics\Wizard\win.bmp"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "${NSISDIR}\Contrib\Graphics\Header\win.bmp"

!define MUI_WELCOMEPAGE_TITLE "PULSAR ${PRODUCT_VERSION}"
!define MUI_WELCOMEPAGE_TEXT "Bienvenue dans l'assistant d'installation de PULSAR.$\r$\n$\r$\nPlateforme Unifiee de Liaison, de Surveillance et d'Assistance en temps Reel$\r$\nDSIO - CHU de Guyane$\r$\n$\r$\nCet assistant va :$\r$\n  - Installer Python 3.11, Node.js 22 et Git (si absents)$\r$\n  - Installer hermes-agent (moteur IA)$\r$\n  - Compiler l'interface web et l'application desktop$\r$\n  - Installer la commande 'pulsar' dans le PATH$\r$\n  - Appliquer les themes PULSAR (nuit + jour)$\r$\n  - Creer les raccourcis avec icone PULSAR$\r$\n$\r$\nDuree estimee : 10 a 20 minutes selon votre connexion.$\r$\n$\r$\nConcu par William MERI - DSIO CHU de Guyane"

!define MUI_FINISHPAGE_TITLE "PULSAR installe avec succes !"
!define MUI_FINISHPAGE_TEXT "PULSAR ${PRODUCT_VERSION} est pret.$\r$\n$\r$\nRaccourcis disponibles sur le Bureau :$\r$\n  - PULSAR          : Interface web (http://localhost:9119)$\r$\n  - PULSAR Desktop  : Application native Electron$\r$\n  - PULSAR CLI      : Interface en ligne de commande$\r$\n$\r$\nCommande dans tout terminal :$\r$\n  pulsar dashboard$\r$\n  pulsar desktop$\r$\n  pulsar chat$\r$\n$\r$\nPremier demarrage : choisissez votre fournisseur LLM$\r$\n(ChatGPT, Azure OpenAI, Ollama...)$\r$\n$\r$\nWilliam MERI - DSIO CHU de Guyane"

!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Lancer PULSAR maintenant"
!define MUI_FINISHPAGE_RUN_FUNCTION "LaunchPulsar"

; Pages
!insertmacro MUI_PAGE_WELCOME
Page custom PageAPropos
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_LANGUAGE "French"

; Variables
Var Dialog
Var Label

; ---- Page A Propos ----
Function PageAPropos
    !insertmacro MUI_HEADER_TEXT "A propos de PULSAR" "Conception et developpement"
    nsDialogs::Create 1018
    Pop $Dialog
    ${If} $Dialog == error
        Abort
    ${EndIf}
    ${NSD_CreateLabel} 0 0 100% 220u "PULSAR v${PRODUCT_VERSION}$\r$\n$\r$\nPlateforme Unifiee de Liaison, de Surveillance$\r$\net d'Assistance en temps Reel$\r$\n$\r$\n--- Conception & Architecture ---$\r$\nWilliam MERI$\r$\nDSIO - CHU de Guyane$\r$\nhttps://github.com/Tarzzan$\r$\n$\r$\n--- Moteur IA ---$\r$\nhermes-agent (NousResearch)$\r$\nhttps://github.com/NousResearch/hermes-agent$\r$\n$\r$\n--- Conformite ---$\r$\nISO 27001 | HDS | RGPD$\r$\nPrivacy Engine - 7 flux couverts$\r$\n$\r$\n--- Licence ---$\r$\nApache 2.0 - Usage medical sous responsabilite du CHU"
    Pop $Label
    nsDialogs::Show
FunctionEnd

; ---- Section principale ----
Section "PULSAR" SecMain

    SetOutPath "$INSTDIR"

    ; -- Etape 0 : Activer ExecutionPolicy pour l'utilisateur --
    DetailPrint "Configuration ExecutionPolicy PowerShell..."
    nsExec::ExecToLog 'powershell.exe -Command "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"'
    Pop $0

    ; -- Etape 1 : Verifier PowerShell --
    DetailPrint "Verification de PowerShell..."
    nsExec::ExecToLog 'powershell.exe -Command "Write-Host PowerShell OK"'
    Pop $0
    ${If} $0 != 0
        MessageBox MB_ICONSTOP "PowerShell est requis. Installez Windows Management Framework 5.1."
        Abort
    ${EndIf}

    ; -- Etape 2 : Telecharger install-chu.ps1 --
    DetailPrint "Telechargement du script d'installation PULSAR..."
    nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri \"${INSTALL_PS1_URL}\" -OutFile \"$TEMP\install-chu.ps1\" -UseBasicParsing"'
    Pop $0
    ${If} $0 != 0
        MessageBox MB_ICONSTOP "Impossible de telecharger le script d'installation.$\r$\nVerifiez votre connexion internet."
        Abort
    ${EndIf}

    ; -- Etape 3 : Installation hermes-agent + desktop --
    DetailPrint "Installation PULSAR en cours (10-20 min)..."
    DetailPrint "Etapes : uv > Python 3.11 > Git > Node.js 22 > hermes-agent > venv > deps > desktop > CHU patches > PATH"
    nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -File "$TEMP\install-chu.ps1" -NonInteractive -IncludeDesktop'
    Pop $0
    ${If} $0 != 0
        MessageBox MB_ICONEXCLAMATION "L'installation a rencontre une erreur (code $0).$\r$\nConsultez le log ci-dessus.$\r$\nVous pouvez relancer : powershell -File $TEMP\install-chu.ps1"
    ${Else}
        DetailPrint "hermes-agent installe avec succes !"
    ${EndIf}

    ; -- Etape 4 : Telecharger pulsar.bat --
    DetailPrint "Installation de la commande pulsar..."
    CreateDirectory "$INSTDIR\bin"
    nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri \"${PULSAR_BAT_URL}\" -OutFile \"$INSTDIR\bin\pulsar.bat\" -UseBasicParsing"'
    Pop $0
    ${If} $0 == 0
        ; Copier aussi en .cmd
        nsExec::ExecToLog 'cmd.exe /c copy /y "$INSTDIR\bin\pulsar.bat" "$INSTDIR\bin\pulsar.cmd"'
        DetailPrint "Commande pulsar installee dans $INSTDIR\bin\"
    ${Else}
        DetailPrint "Avertissement : pulsar.bat non telecharge (non bloquant)"
    ${EndIf}

    ; -- Etape 5 : Ajouter $INSTDIR\bin au PATH utilisateur --
    DetailPrint "Mise a jour du PATH utilisateur..."
    ; Ajouter hermes\bin au PATH via le registre (methode robuste sans PowerShell complexe)
    nsExec::ExecToLog 'cmd.exe /c "for /f "tokens=2*" %A in ('reg query "HKCU\Environment" /v PATH 2^>nul') do setx PATH "%B;%LOCALAPPDATA%\hermes\bin" >nul 2>&1"'
    Pop $0

    ; -- Etape 6 : Telecharger l'icone PULSAR --
    DetailPrint "Telechargement de l'icone PULSAR..."
    CreateDirectory "$INSTDIR\pulsar-assets"
    nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri \"${PULSAR_ICO_URL}\" -OutFile \"$INSTDIR\pulsar-assets\pulsar.ico\" -UseBasicParsing"'
    Pop $0

    ; -- Etape 7 : Telecharger les themes PULSAR --
    DetailPrint "Installation des themes PULSAR..."
    CreateDirectory "$INSTDIR\dashboard-themes"
    CreateDirectory "$INSTDIR\skins"

    nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri \"${THEME_DARK_URL}\" -OutFile \"$INSTDIR\dashboard-themes\pulsar.yaml\" -UseBasicParsing"'
    Pop $0
    nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri \"${THEME_LIGHT_URL}\" -OutFile \"$INSTDIR\dashboard-themes\pulsar-light.yaml\" -UseBasicParsing"'
    Pop $0
    nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri \"${SKIN_DARK_URL}\" -OutFile \"$INSTDIR\skins\pulsar.yaml\" -UseBasicParsing"'
    Pop $0
    nsExec::ExecToLog 'powershell.exe -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri \"${SKIN_LIGHT_URL}\" -OutFile \"$INSTDIR\skins\pulsar-light.yaml\" -UseBasicParsing"'
    Pop $0
    DetailPrint "Themes PULSAR installes (nuit + jour)"

    ; -- Etape 8 : Creer le script de lancement Launch-PULSAR.bat --
    DetailPrint "Creation du script de lancement PULSAR..."
    FileOpen $9 "$INSTDIR\pulsar-assets\Launch-PULSAR.bat" w
    FileWrite $9 "@echo off$\r$\n"
    FileWrite $9 "title PULSAR -- Systeme Agentique Medical$\r$\n"
    FileWrite $9 "echo.$\r$\n"
    FileWrite $9 "echo   ============================================================$\r$\n"
    FileWrite $9 "echo   PULSAR -- Systeme Agentique Medical$\r$\n"
    FileWrite $9 "echo   DSIO -- CHU de Guyane ^| William MERI$\r$\n"
    FileWrite $9 "echo   ============================================================$\r$\n"
    FileWrite $9 "echo.$\r$\n"
    FileWrite $9 "echo   Demarrage interface web PULSAR...$\r$\n"
    FileWrite $9 "echo   Disponible sur : http://localhost:9119$\r$\n"
    FileWrite $9 "echo   Ctrl+C pour arreter$\r$\n"
    FileWrite $9 "echo.$\r$\n"
    FileWrite $9 "set PATH=%PATH%;%LOCALAPPDATA%\hermes\bin$\r$\n"
    FileWrite $9 "start cmd /c timeout /t 2 /nobreak >nul && start http://localhost:9119$\r$\n"
    FileWrite $9 "hermes dashboard$\r$\n"
    FileWrite $9 "if errorlevel 1 ($\r$\n"
    FileWrite $9 "  echo.$\r$\n"
    FileWrite $9 "  echo   [!!] PULSAR s'est arrete. Appuyez sur une touche...$\r$\n"
    FileWrite $9 "  pause >nul$\r$\n"
    FileWrite $9 ")$\r$\n"
    FileClose $9

    ; Script CLI
    FileOpen $9 "$INSTDIR\pulsar-assets\Launch-PULSAR-CLI.bat" w
    FileWrite $9 "@echo off$\r$\n"
    FileWrite $9 "title PULSAR CLI -- Systeme Agentique Medical$\r$\n"
    FileWrite $9 "set PATH=%PATH%;%LOCALAPPDATA%\hermes\bin$\r$\n"
    FileWrite $9 "echo   PULSAR CLI -- DSIO CHU de Guyane$\r$\n"
    FileWrite $9 "hermes chat$\r$\n"
    FileWrite $9 "pause$\r$\n"
    FileClose $9

    ; Script Desktop
    FileOpen $9 "$INSTDIR\pulsar-assets\Launch-PULSAR-Desktop.bat" w
    FileWrite $9 "@echo off$\r$\n"
    FileWrite $9 "title PULSAR Desktop -- Systeme Agentique Medical$\r$\n"
    FileWrite $9 "set PATH=%PATH%;%LOCALAPPDATA%\hermes\bin$\r$\n"
    FileWrite $9 "echo   PULSAR Desktop -- DSIO CHU de Guyane$\r$\n"
    FileWrite $9 "hermes desktop$\r$\n"
    FileWrite $9 "if errorlevel 1 ($\r$\n"
    FileWrite $9 "  echo   [!!] PULSAR Desktop non disponible.$\r$\n"
    FileWrite $9 "  echo   Lancez d'abord : hermes desktop --build-only$\r$\n"
    FileWrite $9 "  pause$\r$\n"
    FileWrite $9 ")$\r$\n"
    FileClose $9

    DetailPrint "Scripts de lancement crees"

    ; -- Etape 9 : Raccourcis Bureau + Menu Demarrer avec icone PULSAR --
    DetailPrint "Creation des raccourcis PULSAR..."

    ; Raccourci PULSAR (web dashboard)
    CreateShortCut "$DESKTOP\PULSAR.lnk" \
        "$INSTDIR\pulsar-assets\Launch-PULSAR.bat" \
        "" \
        "$INSTDIR\pulsar-assets\pulsar.ico" 0 SW_SHOWNORMAL

    ; Raccourci PULSAR Desktop
    CreateShortCut "$DESKTOP\PULSAR Desktop.lnk" \
        "$INSTDIR\pulsar-assets\Launch-PULSAR-Desktop.bat" \
        "" \
        "$INSTDIR\pulsar-assets\pulsar.ico" 0 SW_SHOWNORMAL

    ; Raccourci PULSAR CLI
    CreateShortCut "$DESKTOP\PULSAR CLI.lnk" \
        "$INSTDIR\pulsar-assets\Launch-PULSAR-CLI.bat" \
        "" \
        "$INSTDIR\pulsar-assets\pulsar.ico" 0 SW_SHOWNORMAL

    ; Menu Demarrer
    CreateDirectory "$SMPROGRAMS\PULSAR"
    CreateShortCut "$SMPROGRAMS\PULSAR\PULSAR.lnk" \
        "$INSTDIR\pulsar-assets\Launch-PULSAR.bat" \
        "" \
        "$INSTDIR\pulsar-assets\pulsar.ico" 0 SW_SHOWNORMAL
    CreateShortCut "$SMPROGRAMS\PULSAR\PULSAR Desktop.lnk" \
        "$INSTDIR\pulsar-assets\Launch-PULSAR-Desktop.bat" \
        "" \
        "$INSTDIR\pulsar-assets\pulsar.ico" 0 SW_SHOWNORMAL
    CreateShortCut "$SMPROGRAMS\PULSAR\PULSAR CLI.lnk" \
        "$INSTDIR\pulsar-assets\Launch-PULSAR-CLI.bat" \
        "" \
        "$INSTDIR\pulsar-assets\pulsar.ico" 0 SW_SHOWNORMAL
    CreateShortCut "$SMPROGRAMS\PULSAR\Documentation.lnk" "${PRODUCT_URL}/wiki"
    CreateShortCut "$SMPROGRAMS\PULSAR\Desinstaller.lnk" "$INSTDIR\Uninstall-PULSAR.exe"

    DetailPrint "Raccourcis PULSAR crees (Bureau + Menu Demarrer)"

    ; -- Etape 10 : Registre Windows --
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PULSAR" "DisplayName" "${PRODUCT_FULLNAME}"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PULSAR" "DisplayVersion" "${PRODUCT_VERSION}"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PULSAR" "Publisher" "${PRODUCT_PUBLISHER}"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PULSAR" "URLInfoAbout" "${PRODUCT_URL}"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PULSAR" "InstallLocation" "$INSTDIR"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PULSAR" "UninstallString" '"$INSTDIR\Uninstall-PULSAR.exe"'
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PULSAR" "DisplayIcon" "$INSTDIR\pulsar-assets\pulsar.ico"
    WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PULSAR" "NoModify" 1
    WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PULSAR" "NoRepair" 1

    ; -- Desinstallateur --
    WriteUninstaller "$INSTDIR\Uninstall-PULSAR.exe"

    DetailPrint ""
    DetailPrint "============================================================"
    DetailPrint "PULSAR ${PRODUCT_VERSION} installe avec succes !"
    DetailPrint "Raccourcis sur le Bureau : PULSAR, PULSAR Desktop, PULSAR CLI"
    DetailPrint "Commande dans tout terminal : pulsar dashboard"
    DetailPrint "============================================================"

SectionEnd

; ---- Desinstallation ----
Section "Uninstall"
    RMDir /r "$LOCALAPPDATA\hermes\hermes-chu"
    Delete "$INSTDIR\Uninstall-PULSAR.exe"
    Delete "$INSTDIR\pulsar-assets\Launch-PULSAR.bat"
    Delete "$INSTDIR\pulsar-assets\Launch-PULSAR-Desktop.bat"
    Delete "$INSTDIR\pulsar-assets\Launch-PULSAR-CLI.bat"
    Delete "$INSTDIR\pulsar-assets\pulsar.ico"
    RMDir "$INSTDIR\pulsar-assets"
    Delete "$INSTDIR\bin\pulsar.bat"
    Delete "$INSTDIR\bin\pulsar.cmd"
    RMDir "$INSTDIR\bin"
    Delete "$DESKTOP\PULSAR.lnk"
    Delete "$DESKTOP\PULSAR Desktop.lnk"
    Delete "$DESKTOP\PULSAR CLI.lnk"
    RMDir /r "$SMPROGRAMS\PULSAR"
    DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PULSAR"
    MessageBox MB_ICONINFORMATION "PULSAR a ete desinstalle.$\r$\nLe moteur hermes-agent reste installe dans $LOCALAPPDATA\hermes\"
SectionEnd

; ---- Fonction de lancement final ----
Function LaunchPulsar
    ExecShell "open" "$INSTDIR\pulsar-assets\Launch-PULSAR.bat"
FunctionEnd
