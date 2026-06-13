# ============================================================================
# PULSAR — Agent de Recette
# ----------------------------------------------------------------------------
# Tourne dans la session interactive du poste de test. Récupère les commandes
# de recette depuis le serveur (Abux), les exécute, et renvoie résultats +
# captures d'écran. La fenêtre console est le coupe-circuit : la fermer (ou
# Ctrl+C) arrête immédiatement l'agent.
#
# Jeton lu depuis agent-token.txt (même dossier). LAN strict.
# ============================================================================

$ErrorActionPreference = 'Stop'
$Serveur    = 'https://192.168.1.55:9333'
$Machine    = $env:COMPUTERNAME
$Intervalle = 3

# Relay en HTTPS avec certificat auto-signe (LAN interne) : lui faire confiance.
# (Chiffrement du canal ; le pinning/mTLS sera la prochaine etape de durcissement.)
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $PSDefaultParameterValues['Invoke-RestMethod:SkipCertificateCheck'] = $true
    $PSDefaultParameterValues['Invoke-WebRequest:SkipCertificateCheck']  = $true
} else {
    try {
        Add-Type -TypeDefinition @"
using System.Net; using System.Security.Cryptography.X509Certificates;
public class PulsarTrustAll : ICertificatePolicy {
  public bool CheckValidationResult(ServicePoint s, X509Certificate c, WebRequest r, int p) { return true; }
}
"@ -ErrorAction SilentlyContinue
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object PulsarTrustAll
    } catch {}
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
}

# Instance unique : terminer d'eventuels anciens agents (utile lors d'une bascule).
try {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'agent-recette' -and $_.ProcessId -ne $PID } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
} catch {}

$tokenFile = Join-Path $PSScriptRoot 'agent-token.txt'
if (-not (Test-Path $tokenFile)) {
    Write-Host "Jeton introuvable : $tokenFile" -ForegroundColor Red
    Write-Host "Appuie sur une touche pour fermer." ; [void][System.Console]::ReadKey($true) ; exit 1
}
$Token = (Get-Content $tokenFile -Raw).Trim()

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Capturer-Ecran {
    # Écrit la capture dans un fichier temporaire et renvoie son chemin.
    # (Upload binaire ensuite : évite la limite MaxJsonLength de PS 5.1.)
    $z   = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $bmp = New-Object System.Drawing.Bitmap $z.Width, $z.Height
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($z.Location, [System.Drawing.Point]::Empty, $z.Size)
    $tmp = Join-Path $env:TEMP ("pulsar-capture-" + [Guid]::NewGuid().ToString('N') + ".png")
    $bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose() ; $bmp.Dispose()
    return $tmp
}

function Executer($cmd) {
    $msg = '' ; $cap = $null
    $p = $cmd.params
    switch ($cmd.action) {

        'checkin' {
            $msg = "Agent en ligne sur $Machine`nOS : $([System.Environment]::OSVersion.VersionString)`nUtilisateur : $env:USERNAME"
            $cap = Capturer-Ecran
        }

        'screenshot' { $msg = 'Capture d''écran.' ; $cap = Capturer-Ecran }

        'shell' {
            $out = & powershell -NoProfile -Command $p.script 2>&1 | Out-String
            $msg = "PS> $($p.script)`n`n$out"
        }

        'download' {
            New-Item -ItemType Directory -Force -Path (Split-Path $p.dest) | Out-Null
            Invoke-WebRequest -Uri $p.url -OutFile $p.dest -UseBasicParsing
            $sz = (Get-Item $p.dest).Length
            $msg = "Téléchargé`n  $($p.url)`n  -> $($p.dest)  ($sz octets)"
        }

        'sha256' {
            $h = (Get-FileHash -Path $p.path -Algorithm SHA256).Hash
            $msg = "SHA256 $($p.path)`n  = $h"
        }

        'http' {
            try {
                $r = Invoke-WebRequest -Uri $p.url -UseBasicParsing -TimeoutSec 15
                $body = [string]$r.Content
                if ($body.Length -gt 800) { $body = $body.Substring(0,800) + ' …(tronqué)' }
                $msg = "GET $($p.url)`n  -> HTTP $($r.StatusCode)`n$body"
            } catch {
                $msg = "GET $($p.url)`n  -> ÉCHEC : $($_.Exception.Message)"
            }
        }

        'exists' { $msg = "Test-Path $($p.path) = $([bool](Test-Path $p.path))" }

        'tail' {
            $n = if ($p.lignes) { [int]$p.lignes } else { 40 }
            if (Test-Path $p.path) {
                $msg = "Fin de $($p.path) ($n lignes) :`n" + ((Get-Content $p.path -Tail $n) -join "`n")
            } else { $msg = "Fichier absent : $($p.path)" }
        }

        'installer' {
            $a = @{ FilePath = $p.path ; PassThru = $true ; Wait = $true }
            if ($p.args) { $a.ArgumentList = $p.args }
            $proc = Start-Process @a
            Start-Sleep -Seconds 2
            $msg = "Exécuté $($p.path)`n  args : $($p.args)`n  code de sortie : $($proc.ExitCode)"
            $cap = Capturer-Ecran
        }

        default { $msg = "Action inconnue : $($cmd.action)" }
    }
    return @{ message = $msg ; capture = $cap }
}

function Renvoyer($id, $lib, $scn, $res) {
    # 1) résultat texte (JSON léger) -> récupère l'id du ticket créé
    $body = @{
        token = $Token ; machine = $Machine ; commande_id = $id
        libelle = $lib ; scenario = $scn ; message = $res.message
    } | ConvertTo-Json -Depth 4
    # PS 5.1 encode sinon le corps en cp1252 -> on force UTF-8 sur le fil
    $octets = [System.Text.Encoding]::UTF8.GetBytes($body)
    $rep = Invoke-RestMethod -Uri "$Serveur/api/agent/resultat" -Method Post -Body $octets -ContentType 'application/json; charset=utf-8'

    # 2) capture éventuelle -> upload binaire brut rattaché au ticket
    if ($res.capture -and (Test-Path $res.capture)) {
        $u = "$Serveur/api/agent/capture?token=$Token" + '&' + "ticket=$($rep.ticket)" + '&' + "nom=capture.png"
        try {
            Invoke-RestMethod -Uri $u -Method Post -InFile $res.capture -ContentType 'application/octet-stream' | Out-Null
        } finally {
            Remove-Item $res.capture -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "   PULSAR — Agent de Recette" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " Serveur : $Serveur" -ForegroundColor Gray
Write-Host " Poste   : $Machine" -ForegroundColor Gray
Write-Host " Ferme cette fenêtre (ou Ctrl+C) pour ARRÊTER l'agent." -ForegroundColor Yellow
Write-Host ""

try {
    $res = Executer @{ action = 'checkin' ; params = @{} }
    Renvoyer 'checkin' 'Démarrage agent' '' $res
    Write-Host "[$(Get-Date -Format HH:mm:ss)] Check-in envoyé — agent EN LIGNE." -ForegroundColor Green
} catch {
    Write-Host "[$(Get-Date -Format HH:mm:ss)] Serveur injoignable : $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Vérifie que le pare-feu d'Abux (192.168.1.55) autorise le port 9333 en entrée." -ForegroundColor Red
}

while ($true) {
    try {
        $uri = "$Serveur/api/agent/commandes?token=$Token" + '&' + "machine=$Machine"
        $r = Invoke-RestMethod -Uri $uri -TimeoutSec 15
        foreach ($c in $r.commandes) {
            $lib = if ($c.libelle) { $c.libelle } else { $c.action }
            Write-Host "[$(Get-Date -Format HH:mm:ss)] Commande $($c.id) : $lib" -ForegroundColor White
            try {
                $res = Executer $c
                Renvoyer $c.id $lib $c.scenario $res
                Write-Host "      -> résultat renvoyé." -ForegroundColor DarkGray
            } catch {
                Renvoyer $c.id $lib $c.scenario @{ message = "ERREUR : $($_.Exception.Message)" ; capture = $null }
                Write-Host "      -> erreur : $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "[$(Get-Date -Format HH:mm:ss)] Serveur injoignable, nouvelle tentative…" -ForegroundColor DarkYellow
    }
    Start-Sleep -Seconds $Intervalle
}
