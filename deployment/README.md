# musica deployment

Standalone deployment for running the musica stack on an existing host.
For Raspberry Pi image builds, see the root [README](../README.md).

## Quick start

```bash
cd deployment
cp .env.example .env        # fill in secrets
make -C .. setup             # creates data dirs + DAB config from .env
make -C .. up                # starts navidrome + lidarr + slskd
make -C .. up-public         # also starts Caddy for music.plai.do HTTPS
```

## Services

| Service | Port | Purpose | Access |
|---|---|---|---|
| **Navidrome** | 4533 | Music server + web UI | `http://<ip>:4533` |
| **Lidarr** | 8686 | Music library manager (automated downloads) | `http://<ip>:8686` |
| **slskd** | 5030 | Soulseek P2P daemon + web UI | `http://<ip>:5030` |
| **DAB** | CLI | On-demand FLAC downloader | `make -C .. dab search "query"` |
| **Caddy** | 80/443 | HTTPS reverse proxy for `music.plai.do` | `--profile public` only |

## DAB usage

DAB is a CLI tool, not a long-running server. Use interactively:

```bash
# Interactive search (needs TTY)
docker compose --profile cli run --rm -it dab search "Radiohead"

# Direct download by ID
docker compose --profile cli run --rm dab download <track-id>

# Login (first time)
docker compose --profile cli run --rm dab login your@email.com yourpassword

# Check status
docker compose --profile cli run --rm dab status
```

## Windows + WSL2 networking

> **Important:** On Windows hosts running WSL2, services inside WSL are not
> directly reachable from LAN or ZeroTier. Windows must forward ports into WSL.

WSL2 uses a virtual NAT — its IP is only reachable from the Windows host.
External devices (LAN, ZeroTier peers) connect to the Windows IP, which must
proxy traffic into WSL.

### Setup (one-time, run as Administrator)

From **Windows PowerShell (Admin)**, using the WSL path:

```powershell
powershell -ExecutionPolicy Bypass -File "\\wsl$\NixOS\home\nixos\musica\deployment\musica-portproxy.ps1" -Register
```

This does three things:
1. Creates portproxy rules forwarding ports 4533, 8686, 5030, 80, 443 from
   all Windows interfaces → WSL2 IP
2. Creates firewall rules allowing inbound traffic on those ports
3. `-Register` creates a scheduled task that re-applies the rules on each
   Windows boot (WSL2's IP changes on restart)

### Re-apply after WSL restart

If WSL restarts mid-session (IP changes), re-run without `-Register`:

```powershell
powershell -ExecutionPolicy Bypass -File "\\wsl$\NixOS\home\nixos\musica\deployment\musica-portproxy.ps1"
```

### Verify

```powershell
netsh interface portproxy show v4tov4
```

After setup, access from any device:
- **LAN:** `http://<windows-lan-ip>:4533`
- **ZeroTier:** `http://<ms02-zt-ip>:4533`
- **Public:** `https://music.plai.do` (requires DNS + router port forward for 80/443)

## Secrets

All secrets live in `.env` (gitignored). The `.env.example` documents every
variable. DAB's `config.json` is generated from `.env` via `make config` —
never commit `data/dab-config/config.json`.

## Data directories

All runtime state lives under `data/` (gitignored):

```
data/
  navidrome/     # Navidrome database + cache
  lidarr/        # Lidarr config + database
  slskd/         # slskd config + state
  dab-config/    # DAB config.json + session token
  downloads/     # slskd downloads (Lidarr imports from here)
  caddy/         # Caddy TLS certs + state
music/           # shared music library (Navidrome reads, downloaders write)
```
