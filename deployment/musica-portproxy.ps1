# musica-portproxy.ps1 — Windows portproxy + firewall for musica services
# Run as Administrator. Idempotent — safe to re-run.
#
# Forwards musica ports from Windows interfaces (LAN + ZeroTier) into WSL2.
# WSL2's IP changes on restart; run this script after each boot or register
# it as a scheduled task (see below).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File deployment\musica-portproxy.ps1
#
# Register as startup task (one-time, run as admin):
#   powershell -ExecutionPolicy Bypass -File deployment\musica-portproxy.ps1 -Register

param(
    [switch]$Register   # register as a scheduled task that runs at startup
)

$ErrorActionPreference = "Stop"

function Ok   { param($msg) Write-Host "  [OK]   $msg" -ForegroundColor Green }
function Warn { param($msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Info { param($msg) Write-Host "  [INFO] $msg" }

Write-Host ""
Write-Host "musica portproxy — Windows → WSL2" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

# ── Get WSL2 IP ────────────────────────────────────────────────────────
$wslIp = (wsl hostname -I 2>$null)
if ($wslIp) { $wslIp = $wslIp.Trim().Split()[0] }

if (-not $wslIp) {
    Warn "WSL2 is not running — cannot configure portproxy."
    Write-Host "  Start WSL first: wsl"
    exit 1
}
Info "WSL2 IP: $wslIp"

# ── Ports to forward ──────────────────────────────────────────────────
$ports = @(
    @{ listen=4533;  connect=4533;  name="Musica Navidrome";   desc="Navidrome music server" },
    @{ listen=8686;  connect=8686;  name="Musica Lidarr";      desc="Lidarr music manager" },
    @{ listen=5030;  connect=5030;  name="Musica slskd";       desc="Soulseek daemon" },
    @{ listen=8080;  connect=8080;  name="Musica DAB";         desc="DAB Downloader (if web mode)" },
    @{ listen=80;    connect=80;    name="Musica Caddy HTTP";  desc="Caddy HTTP (ACME)" },
    @{ listen=443;   connect=443;   name="Musica Caddy HTTPS"; desc="Caddy HTTPS (music.plai.do)" }
)

# ── Portproxy rules ───────────────────────────────────────────────────
Write-Host ""
Write-Host "Portproxy rules:" -ForegroundColor Cyan
foreach ($p in $ports) {
    netsh interface portproxy delete v4tov4 listenport=$($p.listen) listenaddress=0.0.0.0 2>$null | Out-Null
    netsh interface portproxy add    v4tov4 listenport=$($p.listen) listenaddress=0.0.0.0 `
        connectport=$($p.connect) connectaddress=$wslIp | Out-Null
    Ok "$($p.name): 0.0.0.0:$($p.listen) → ${wslIp}:$($p.connect)"
}

# ── Firewall rules (idempotent) ───────────────────────────────────────
Write-Host ""
Write-Host "Firewall rules:" -ForegroundColor Cyan
foreach ($p in $ports) {
    $existing = Get-NetFirewallRule -DisplayName $p.name -ErrorAction SilentlyContinue
    if ($existing) {
        Ok "$($p.name) (port $($p.listen)) already exists"
    } else {
        New-NetFirewallRule -DisplayName $p.name -Direction Inbound -Protocol TCP `
            -LocalPort $p.listen -Action Allow -Description $p.desc | Out-Null
        Ok "$($p.name) (port $($p.listen)) added"
    }
}

# ── Scheduled task registration ───────────────────────────────────────
if ($Register) {
    Write-Host ""
    Write-Host "Scheduled task:" -ForegroundColor Cyan
    $taskName = "Musica-WSL2-PortProxy"
    $scriptPath = $MyInvocation.MyCommand.Path
    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existing) {
        Ok "Task '$taskName' already registered"
    } else {
        $action    = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
        $trigger   = New-ScheduledTaskTrigger -AtStartup
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
            -Principal $principal -Description "Refresh musica WSL2 portproxy on boot" | Out-Null
        Ok "Task '$taskName' registered (runs at startup as SYSTEM)"
    }
}

# ── Summary ───────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Done. Musica services accessible from LAN and ZeroTier:" -ForegroundColor Green
Write-Host "  Navidrome:  http://<ip>:4533"
Write-Host "  Lidarr:     http://<ip>:8686"
Write-Host "  slskd:      http://<ip>:5030"
Write-Host "  music.plai: https://music.plai.do (after DNS + router forward)"
Write-Host ""
if (-not $Register) {
    Write-Host "Tip: run with -Register to auto-refresh on each Windows boot." -ForegroundColor Yellow
}
