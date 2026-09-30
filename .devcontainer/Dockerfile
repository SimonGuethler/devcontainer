# syntax=docker/dockerfile:1

FROM nvidia/cuda:13.3.1-cudnn-devel-ubuntu26.04

# Disable supported telemetry during image builds and in all container processes.
ENV DO_NOT_TRACK=1 \
    OMO_DISABLE_POSTHOG=1 \
    OMO_SEND_ANONYMOUS_TELEMETRY=0 \
    CODEGRAPH_TELEMETRY=0 \
    OTEL_SDK_DISABLED=true

# Install uv without installing Python system-wide.
COPY --from=ghcr.io/astral-sh/uv:0.12.12 /uv /uvx /bin/

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash \
        bat \
        bc \
        build-essential \
        ca-certificates \
        clang \
        cmake \
        coreutils \
        curl \
        fd-find \
        fzf \
        git \
        git-lfs \
        gnupg \
        htop \
        iperf3 \
        jq \
        libssl-dev \
        locales \
        nano \
        ncdu \
        openssh-client \
        pkg-config \
        ripgrep \
        shellcheck \
        sqlite3 \
        tar \
        tmux \
        tree \
        unzip \
        wget \
        zip \
        zsh \
    && git lfs install --system \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

# Node.js (current LTS, official nodejs.org binary, including npm).
# Intentionally track v24 updates so fresh builds receive LTS fixes.
# Resolve the version from SHASUMS256.txt in the latest-v24.x directory and
# verify it with SHA-256; no third-party curl-to-shell installer is used.
RUN NODE_DIST="https://nodejs.org/dist/latest-v24.x" \
    && cd /tmp \
    && NODE_TARBALL="$(curl -fsSL "${NODE_DIST}/SHASUMS256.txt" | awk '/linux-x64\.tar\.xz$/ { print $2 }' | head -n1)" \
    && curl -fsSL "${NODE_DIST}/SHASUMS256.txt" -o SHASUMS256.txt \
    && curl -fsSL "${NODE_DIST}/${NODE_TARBALL}" -o "${NODE_TARBALL}" \
    && grep " ${NODE_TARBALL}" SHASUMS256.txt | sha256sum -c - \
    && tar -xJf "${NODE_TARBALL}" -C /usr/local --strip-components=1 \
    && rm -rf "/tmp/${NODE_TARBALL}" /tmp/SHASUMS256.txt \
    && node --version \
    && npm --version

# Python diagnostics without a system-wide Python installation. Project Python
# environments remain managed by uv; Pyright's CLI and LSP run on Node.
ARG PYRIGHT_VERSION=1.1.413
RUN npm install --global "pyright@${PYRIGHT_VERSION}" \
    && pyright --version

# Install the Rust toolchain (rustc, cargo, clippy, rustfmt, rust-analyzer) system-wide.
# Intentionally track stable for this development image; projects can pin their
# own toolchain with rust-toolchain.toml.
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path --profile default --default-toolchain stable \
        --component clippy,rustfmt,rust-analyzer \
    && chmod -R a+w "$RUSTUP_HOME" "$CARGO_HOME" \
    && rustc --version \
    && cargo --version

# Install just and just-lsp as prebuilt binaries (faster than cargo install).
# SHA-256 digests are from the GitHub release assets; update with each version.
ARG JUST_VERSION=1.57.0
ARG JUST_SHA256=45b548094283cb9739af8f13273b8cddeee869f5b4ef2bb631b1f311cb566155
ARG JUST_LSP_VERSION=0.6.1
ARG JUST_LSP_SHA256=0fc4680d5c19a94a3b133bc1de479f5bf9cc23dd5ef1283863c9b2c083b62820
# The archives place the binaries at their root, but just-lsp uses a "./"
# prefix. --wildcards and --strip-components handle both layouts.
RUN curl -fsSL "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
        -o /tmp/just.tar.gz \
    && printf '%s  %s\n' "$JUST_SHA256" /tmp/just.tar.gz | sha256sum -c - \
    && tar -xzf /tmp/just.tar.gz -C /usr/local/bin --wildcards --strip-components=0 '*just' \
    && curl -fsSL "https://github.com/terror/just-lsp/releases/download/${JUST_LSP_VERSION}/just-lsp-${JUST_LSP_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
        -o /tmp/just-lsp.tar.gz \
    && printf '%s  %s\n' "$JUST_LSP_SHA256" /tmp/just-lsp.tar.gz | sha256sum -c - \
    && tar -xzf /tmp/just-lsp.tar.gz -C /usr/local/bin --wildcards --strip-components=0 '*just-lsp' \
    && chmod +x /usr/local/bin/just /usr/local/bin/just-lsp \
    && rm -f /tmp/just.tar.gz /tmp/just-lsp.tar.gz \
    && just --version \
    && just-lsp --version

ARG CROC_VERSION=11.5.2
ARG CROC_SHA256=8048f12941c68ccb1f35812a73e18b14fd39278c23fa73efca6b0478003f6fc1
RUN curl -fsSL "https://github.com/schollz/croc/releases/download/v${CROC_VERSION}/croc_v${CROC_VERSION}_Linux-64bit.tar.gz" \
        -o /tmp/croc.tar.gz \
    && printf '%s  %s\n' "$CROC_SHA256" /tmp/croc.tar.gz | sha256sum -c - \
    && tar -xzf /tmp/croc.tar.gz -C /usr/local/bin croc \
    && chmod +x /usr/local/bin/croc \
    && rm -f /tmp/croc.tar.gz \
    && croc --version

# Prevent hard-link warnings between the uv cache and mounted repositories.
ENV UV_LINK_MODE=copy

# Locale configuration (C.UTF-8 is available without locale-gen).
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Install the Zsh configuration in the image. postCreateCommand also syncs it
# from the mounted workspace.
COPY setup-zsh.sh .zshrc /tmp/zsh-setup/
RUN ZSHRC_SOURCE=/tmp/zsh-setup/.zshrc sh /tmp/zsh-setup/setup-zsh.sh \
    && rm -rf /tmp/zsh-setup

WORKDIR /workspace

# Local agents and on-demand skills; no provider credentials or MCP downloads.
COPY setup-opencode-harness.sh /tmp/opencode-harness/setup-opencode-harness.sh
COPY opencode /tmp/opencode-harness/opencode
RUN bash /tmp/opencode-harness/setup-opencode-harness.sh \
    && rm -rf /tmp/opencode-harness

CMD ["sleep", "infinity"]
