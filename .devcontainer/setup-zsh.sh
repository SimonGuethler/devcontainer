#!/bin/sh
# One-time Zsh + Oh My Zsh setup for the GPU workspace devcontainer.
# Kept idempotent so it is safe to re-run on an existing container.
set -eu

fail() {
    echo "==> ERROR: $*" >&2
    exit 1
}

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "==> Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
        || fail "Oh My Zsh installation failed"
    [ -d "$HOME/.oh-my-zsh" ] || fail "Oh My Zsh directory missing after install"
else
    echo "==> Oh My Zsh already installed"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    if [ ! -d "${ZSH_CUSTOM}/plugins/${plugin}" ]; then
        echo "==> Installing zsh plugin ${plugin}..."
        git clone --depth 1 "https://github.com/zsh-users/${plugin}" "${ZSH_CUSTOM}/plugins/${plugin}" \
            || fail "Failed to clone plugin ${plugin}"
    else
        echo "==> Plugin ${plugin} already installed"
    fi
done

# Copy the repository's base Oh My Zsh configuration. If setup-opencode.sh ran
# first, ~/.zshrc also contained the OpenCode PATH block; restore it so rerunning
# this setup does not remove OpenCode from PATH.
ZSHRC_SOURCE="${ZSHRC_SOURCE:-/workspace/.devcontainer/.zshrc}"
if [ ! -f "$ZSHRC_SOURCE" ]; then
    fail "${ZSHRC_SOURCE} not found"
fi
# Compare the final configuration, including the PATH block, so reruns do not
# create redundant backups. Keep the original before replacing custom settings.
ZSHRC_TEMP="$(mktemp "$HOME/.zshrc.tmp.XXXXXX")"
trap 'rm -f -- "$ZSHRC_TEMP"' 0
trap 'exit 130' INT
trap 'exit 143' TERM
cat "$ZSHRC_SOURCE" > "$ZSHRC_TEMP"
if [ -x "$HOME/.opencode/bin/opencode" ]; then
    # Keep variables literal for the next shell session.
    # shellcheck disable=SC2016
    printf '\n# BEGIN devcontainer opencode\nexport PATH="$HOME/.opencode/bin:$PATH"\n# END devcontainer opencode\n' >> "$ZSHRC_TEMP"
fi
if ! cmp -s "$ZSHRC_TEMP" "$HOME/.zshrc"; then
    if [ -f "$HOME/.zshrc" ]; then
        ZSHRC_BACKUP="$(mktemp "$HOME/.zshrc.backup.XXXXXX")"
        cat "$HOME/.zshrc" > "$ZSHRC_BACKUP"
        echo "==> Previous Zsh configuration saved to ${ZSHRC_BACKUP}"
    fi
    mv -f "$ZSHRC_TEMP" "$HOME/.zshrc"
fi

# chsh fails as root in containers because of PAM; usermod updates /etc/passwd
# directly and works reliably here.
USER_SHELL="$(command -v zsh)"
if command -v usermod >/dev/null 2>&1; then
    usermod -s "$USER_SHELL" "$(id -un)"
else
    chsh -s "$USER_SHELL"
fi

CURRENT_SHELL="$(getent passwd "$(id -un)" | cut -d: -f7)"
if [ "$CURRENT_SHELL" != "$USER_SHELL" ]; then
    fail "Default shell is still ${CURRENT_SHELL}, expected ${USER_SHELL}"
fi

echo "==> Zsh setup complete. Default shell: ${CURRENT_SHELL}"
