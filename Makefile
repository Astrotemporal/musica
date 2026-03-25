.PHONY: help setup up down dab config build-rpi-image build-docker clean

DEPLOY := deployment
COMPOSE := docker compose -f $(DEPLOY)/docker-compose.yml
ENV_FILE := $(DEPLOY)/.env

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

# ── Deployment ──────────────────────────────────────────────────────────

setup: $(ENV_FILE) config ## First-time setup: .env + data dirs + DAB config
	@mkdir -p $(DEPLOY)/data/{navidrome,dab-config,lidarr,slskd,downloads} $(DEPLOY)/music
	@echo "✓ Data directories created. Edit $(ENV_FILE) then run: make up"

$(ENV_FILE):
	cp $(DEPLOY)/.env.example $(ENV_FILE)
	@echo "✓ Created $(ENV_FILE) — fill in your secrets"

config: $(ENV_FILE) ## Generate DAB config.json from .env + template (no secrets in git)
	@set -a && . $(ENV_FILE) && set +a && \
	sed \
	  -e "s|__NAVIDROME_ADMIN_USER__|$${NAVIDROME_ADMIN_USER}|g" \
	  -e "s|__NAVIDROME_ADMIN_PASS__|$${NAVIDROME_ADMIN_PASS}|g" \
	  $(DEPLOY)/dab-config.template.json > $(DEPLOY)/data/dab-config/config.json
	@echo "✓ DAB config.json generated from .env"

up: ## Start core services (navidrome + musicgrabber + lidarr + slskd)
	$(COMPOSE) up -d navidrome musicgrabber lidarr slskd

up-public: up ## Start all services including Caddy (public HTTPS)
	$(COMPOSE) --profile public up -d caddy

down: ## Stop all services
	$(COMPOSE) --profile public --profile cli down

dab-search: ## Search DAB interactively. Usage: make dab-search q="Artist or Song"
	$(COMPOSE) --profile cli run --rm -it dab search "$(q)"

dab-download: ## Download by ID. Usage: make dab-download id="<track-id>"
	$(COMPOSE) --profile cli run --rm dab download "$(id)"

dab-status: ## Check DAB login status
	$(COMPOSE) --profile cli run --rm dab status

dab-login: ## Login to DAB. Usage: make dab-login email="you@email.com" pass="password"
	$(COMPOSE) --profile cli run --rm dab login "$(email)" "$(pass)"

dab: ## Run arbitrary DAB command. Usage: make dab cmd="search Radiohead"
	$(COMPOSE) --profile cli run --rm -it dab $(cmd)

# ── RPi Image Build ────────────────────────────────────────────────────

build-rpi-image: ## Build image on a native arm64 Debian/Pi host
	./rpi-image-gen/rpi-image-gen build \
	  -S rpi-image/config \
	  -c rpi-image/config/musica-pi5.yaml

build-docker: ## Build image inside Docker (Apple Silicon / x86 via QEMU)
	docker build --platform linux/arm64 -t rpi-image-gen-builder -f rpi-image/Dockerfile.builder .
	mkdir -p output
	docker volume rm musica-build-vol 2>/dev/null || true
	docker volume create musica-build-vol
	docker run --rm --privileged --platform linux/arm64 \
	  -v $(PWD)/rpi-image:/workspace/rpi-image \
	  -v musica-build-vol:/rpi-output \
	  rpi-image-gen-builder \
	  bash -c "mkdir -p /rpi-output && cd /workspace/rpi-image-gen && ./rpi-image-gen build \
	    -S /workspace/rpi-image/config \
	    -c /workspace/rpi-image/config/musica-pi5.yaml \
	    -B /rpi-output"
	docker run --rm \
	  -v musica-build-vol:/src:ro \
	  -v $(PWD)/output:/dst \
	  alpine sh -c 'find /src -name "*.img" -exec cp {} /dst/ \;'
	docker volume rm musica-build-vol

clean: ## Remove build artifacts
	docker volume rm musica-build-vol 2>/dev/null || true
	rm -rf output/
