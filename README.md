# musica

Self-hosted music streaming on a Raspberry Pi 5.
Combines Navidrome (music server), DAB Downloader (yt-dlp frontend), and ZeroTier (remote access VPN)
into a minimal Debian Bookworm arm64 image built with [rpi-image-gen](https://github.com/raspberrypi/rpi-image-gen).

---

## What the image includes

| Component | How it gets there |
|---|---|
| Debian Bookworm arm64 base | `bookworm-minbase` built-in profile |
| Docker CE + compose plugin | `docker` layer |
| ZeroTier One VPN | `zerotier` layer — joins your network on first boot |
| SSH enabled | `ssh-enable` layer |
| musica `docker-compose.yml` | `musica-bootstrap` layer |
| First-boot stack start | `musica-start.service` (systemd oneshot) |

Music lives at `/opt/musica/data/music` on the Pi's local storage initially.
Mount a USB drive there (`/etc/fstab`) for persistence across re-flashes.
NFS is a planned alternative for multi-device setups.

---

## Service breakdown

| Service | Image | Purpose | Access |
|---|---|---|---|
| **Navidrome** | `deluan/navidrome:latest` | SubSonic-compatible music server with web UI | `http://<zerotier-ip>:4533` |
| **DAB Downloader** | `ghcr.io/prathxmop/dab-downloader:latest` | yt-dlp frontend; downloads to the shared music dir | `http://<zerotier-ip>:8080` |
| **Caddy** | `caddy:2-alpine` | Reverse proxy stub — **commented out by default** | Uncomment for public HTTPS |
| **ZeroTier** | system service | Remote access VPN; no port forwarding required | `zerotier-cli listnetworks` |

> **Anna's Archive downloader wrapper** (batch import from library exports) is planned as a future companion tool.

---

## Building

### Option A — On your existing Raspberry Pi 5 (recommended, fastest)

rpi-image-gen is officially supported on native Debian Bookworm/Trixie arm64.

```bash
# On the Pi — clone both repos side by side
git clone https://github.com/raspberrypi/rpi-image-gen.git
git clone https://github.com/your-org/musica.git

# Install rpi-image-gen dependencies
cd rpi-image-gen && sudo ./install_deps.sh && cd ..

# Build
ZEROTIER_NETWORK_ID=yournetworkid16hex \
  make -C musica build-rpi-image

# Flash
sudo rpi-imager --cli musica/output/musica-pi5.img /dev/mmcblk0
```

### Option B — Docker on Apple Silicon or x86 (via QEMU, ~30-60 min)

Requires Docker Desktop (Mac) or Docker + `qemu-user-static` (Linux).

```bash
# Register arm64 binfmt handlers (Linux only — Docker Desktop does this automatically)
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Build image
make build-docker ZEROTIER_NETWORK_ID=yournetworkid16hex

# Output
ls output/musica-pi5.img
```

### Option C — GitHub Actions CI

Push to `main` or open a PR touching `rpi-image/**` to trigger
`.github/workflows/build-image.yml`. The workflow runs Option B on an x86 runner via QEMU.

Add your ZeroTier network ID as a GitHub Actions secret named `ZEROTIER_NETWORK_ID`.

The built image is uploaded as an artifact (retained 7 days) on `main` branch pushes.

---

## First boot checklist

1. Flash `output/musica-pi5.img` to an SD card with Raspberry Pi Imager.
2. Mount the boot/root partition and edit `/opt/musica/.env` (copied from `.env.template` on first boot if absent):
   ```env
   LASTFM_ENABLED=true
   LASTFM_APIKEY=your_key
   LASTFM_SECRET=your_secret
   NAVIDROME_ADMIN_PASS=a_strong_password
   ```
3. Boot the Pi. On first boot:
   - `zerotier-join-network.service` — joins your ZeroTier network (oneshot, self-disabling)
   - `musica-start.service` — pulls Docker images and starts the stack (oneshot)
4. Approve the device in [ZeroTier Central](https://my.zerotier.com).
5. Access Navidrome at `http://<zerotier-ip>:4533` from any device on your ZeroTier network.
6. Check `docker ps` on the Pi to confirm `navidrome` and `dab` are running.

---

## Data persistence

All application data lives under `/opt/musica/data/`.
For durability across re-flashes, mount an external USB drive there before first boot:

```bash
# Find your USB drive's UUID
lsblk -o NAME,UUID,FSTYPE

# Add to /etc/fstab on the Pi:
UUID=your-usb-uuid  /opt/musica/data  ext4  defaults,nofail  0  2
```

---

## Repo structure

```
musica/
  rpi-image/
    config/
      musica-pi5.yaml              # top-level rpi-image-gen config
      layer/
        docker.yaml                # Docker CE via official apt repo
        zerotier.yaml              # ZeroTier install + first-boot join service
        musica-bootstrap.yaml      # drops compose + Caddyfile + first-boot systemd service
    Dockerfile.builder             # arm64 Debian container for building on Mac/CI
  deployment/
    docker-compose.yml             # standalone compose for dev / existing Pi
  .github/
    workflows/
      build-image.yml              # CI: QEMU build + smoke test
  Makefile
  README.md
```

The `private/unifi` branch extends this with a UniFi Network Application layer
(`unifi.yaml`) for managing Ubiquiti switches/APs from the same Pi.

---

## Development (existing Pi or local Docker)

```bash
# Copy and edit the env file
cp deployment/.env.example deployment/.env

# Start services (set MUSIC_DIR to your local music library path)
MUSIC_DIR=/path/to/music docker compose -f deployment/docker-compose.yml up -d

# View logs
docker compose -f deployment/docker-compose.yml logs -f
```
