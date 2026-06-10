# Patch-PULSAR-Full.ps1
# PULSAR v3.0 - Patch Global Branding
# DSIO - CHU de Guyane

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  PULSAR v3.0 - Patch Global Branding" -ForegroundColor Cyan
Write-Host "  DSIO - CHU de Guyane" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PatchScript = Join-Path $ScriptDir "patch_pulsar_full.py"

if (-not (Test-Path $PatchScript)) {
    Write-Host "[ERREUR] patch_pulsar_full.py introuvable dans $ScriptDir" -ForegroundColor Red
    exit 1
}

python $PatchScript

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Patch termine. Lancez maintenant :" -ForegroundColor Green
Write-Host ""
Write-Host "  cd `$env:LOCALAPPDATA\hermes\hermes-agent\web" -ForegroundColor Yellow
Write-Host "  npm run build" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Puis relancez : pulsar dashboard" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Green
