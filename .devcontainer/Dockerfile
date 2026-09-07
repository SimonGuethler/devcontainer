# syntax=docker/dockerfile:1

FROM nvidia/cuda:13.3.1-cudnn-devel-ubuntu26.04

# Install uv without installing Python system-wide.
COPY --from=ghcr.io/astral-sh/uv:0.12.1 /uv /uvx /bin/

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
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path --profile default \
        --component clippy,rustfmt,rust-analyzer \
    && chmod -R a+w "$RUSTUP_HOME" "$CARGO_HOME" \
    && rustc --version \
    && cargo --version

# Install just and just-lsp as prebuilt binaries (faster than cargo install).
ARG JUST_VERSION=1.57.0
ARG JUST_LSP_VERSION=0.6.1
# The archives place the binaries at their root, but just-lsp uses a "./"
# prefix. --wildcards and --strip-components handle both layouts.
RUN curl -fsSL "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
        | tar -xz -C /usr/local/bin --wildcards --strip-components=0 '*just' \
    && curl -fsSL "https://github.com/terror/just-lsp/releases/download/${JUST_LSP_VERSION}/just-lsp-${JUST_LSP_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
        | tar -xz -C /usr/local/bin --wildcards --strip-components=0 '*just-lsp' \
    && chmod +x /usr/local/bin/just /usr/local/bin/just-lsp \
    && just --version \
    && just-lsp --version

RUN curl -fsSL https://getcroc.com | bash \
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
