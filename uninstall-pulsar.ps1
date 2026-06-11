# ============================================================
# PULSAR — Script de desinstallation complete
# DSIO — CHU de Guyane | William MERI
# ============================================================
# Executez ce script en tant qu'Administrateur :
#   powershell -ExecutionPolicy Bypass -File uninstall-pulsar.ps1
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  PULSAR — Desinstallation complete" -ForegroundColor Cyan
Write-Host "  DSIO — CHU de Guyane" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/7] Arret des processus PULSAR/Hermes..." -ForegroundColor Yellow
Get-Process -Name "PULSAR","Hermes","hermes*" -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process | Where-Object { $_.MainWindowTitle -like "*PULSAR*" -or $_.MainWindowTitle -like "*Hermes*" } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-Host "  OK" -ForegroundColor Green

Write-Host "[2/7] Suppression de l'installation PULSAR..." -ForegroundColor Yellow
$installPaths = @("$env:LOCALAPPDATA\Programs\PULSAR","$env:LOCALAPPDATA\Programs\Hermes","$env:ProgramFiles\PULSAR","$env:ProgramFiles\Hermes","${env:ProgramFiles(x86)}\PULSAR","${env:ProgramFiles(x86)}\Hermes")
foreach ($p in $installPaths) { if (Test-Path $p) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue; Write-Host "  Supprime: $p" -ForegroundColor Gray } }
Write-Host "  OK" -ForegroundColor Green

Write-Host "[3/7] Suppression des donnees utilisateur..." -ForegroundColor Yellow
$dataPaths = @("$env:APPDATA\PULSAR","$env:APPDATA\Hermes","$env:APPDATA\hermes-desktop","$env:LOCALAPPDATA\PULSAR","$env:LOCALAPPDATA\Hermes","$env:LOCALAPPDATA\hermes-desktop","$env:USERPROFILE\.hermes","$env:USERPROFILE\.pulsar")
foreach ($p in $dataPaths) { if (Test-Path $p) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue; Write-Host "  Supprime: $p" -ForegroundColor Gray } }
Write-Host "  OK" -ForegroundColor Green

Write-Host "[4/7] Suppression de la base d'authentification..." -ForegroundColor Yellow
$dbPaths = @("$env:USERPROFILE\.hermes\*.db","$env:USERPROFILE\.pulsar\*.db","$env:APPDATA\PULSAR\*.db","$env:APPDATA\Hermes\*.db")
foreach ($p in $dbPaths) { Remove-Item $p -Force -ErrorAction SilentlyContinue }
Write-Host "  OK" -ForegroundColor Green

Write-Host "[5/7] Nettoyage du registre Windows..." -ForegroundColor Yellow
@("HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*") | ForEach-Object {
    Get-ItemProperty $_ -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*PULSAR*" -or $_.DisplayName -like "*Hermes*" } | ForEach-Object { Remove-Item $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue; Write-Host "  Registre: $($_.DisplayName)" -ForegroundColor Gray }
}
Write-Host "  OK" -ForegroundColor Green

Write-Host "[6/7] Suppression des raccourcis..." -ForegroundColor Yellow
@("$env:APPDATA\Microsoft\Windows\Start Menu\Programs","$env:PUBLIC\Desktop","$env:USERPROFILE\Desktop") | ForEach-Object {
    Get-ChildItem $_ -Filter "*.lnk" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*PULSAR*" -or $_.Name -like "*Hermes*" } | Remove-Item -Force -ErrorAction SilentlyContinue
}
Write-Host "  OK" -ForegroundColor Green

Write-Host "[7/7] Nettoyage du cache navigateur..." -ForegroundColor Yellow
Write-Host "  Ouvrez Chrome > F12 > Console > tapez:" -ForegroundColor Gray
Write-Host "    localStorage.clear(); sessionStorage.clear(); location.reload();" -ForegroundColor White
Write-Host "  OK" -ForegroundColor Green

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Desinstallation terminee ! Redemarrez le PC." -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Appuyez sur une touche pour fermer..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
