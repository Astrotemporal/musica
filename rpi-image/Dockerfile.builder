# rpi-image/Dockerfile.builder
# Debian Bookworm arm64 container with rpi-image-gen and its dependencies.
# Must be run with --privileged (mmdebstrap needs CAP_SYS_ADMIN).
#
# Build:  docker build --platform linux/arm64 -t rpi-image-gen-builder -f rpi-image/Dockerfile.builder .
# Run:    docker run --rm --privileged --platform linux/arm64 rpi-image-gen-builder

FROM --platform=linux/arm64 debian:bookworm-slim

# Install rpi-image-gen dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    sudo \
    curl \
    ca-certificates \
    mmdebstrap \
    binfmt-support \
    qemu-user-static \
    debootstrap \
    dosfstools \
    e2fsprogs \
    parted \
    rsync \
    zip \
    xz-utils \
    file \
    gnupg \
    python3 \
    python3-jinja2 \
    genimage \
    fdisk \
    && rm -rf /var/lib/apt/lists/*

# Clone rpi-image-gen (pin to a known-good commit in production)
RUN git clone --depth 1 https://github.com/raspberrypi/rpi-image-gen.git /workspace/rpi-image-gen

WORKDIR /workspace/rpi-image-gen

# Install rpi-image-gen's own tool dependencies
RUN sudo ./install_deps.sh

# Default command — override in CI
CMD ["./rpi-image-gen", "--help"]
