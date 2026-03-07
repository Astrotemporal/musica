.PHONY: help build-rpi-image build-docker clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

build-rpi-image: ## Build image on a native arm64 Debian/Pi host
	./rpi-image-gen/rpi-image-gen build \
	  -S rpi-image \
	  -c rpi-image/config/musica-pi5.yaml

build-docker: ## Build image inside Docker (Apple Silicon / x86 via QEMU)
	docker build --platform linux/arm64 -t rpi-image-gen-builder -f rpi-image/Dockerfile.builder .
	mkdir -p output
	docker run --rm --privileged --platform linux/arm64 \
	  -e ZEROTIER_NETWORK_ID=$(ZEROTIER_NETWORK_ID) \
	  -v $(PWD)/rpi-image:/workspace/rpi-image \
	  -v $(PWD)/output:/workspace/output \
	  rpi-image-gen-builder \
	  bash -c "cd /workspace/rpi-image-gen && ./rpi-image-gen build \
	    -S /workspace/rpi-image \
	    -c /workspace/rpi-image/config/musica-pi5.yaml \
	    -o /workspace/output"

clean: ## Remove build artifacts
	rm -rf output/
