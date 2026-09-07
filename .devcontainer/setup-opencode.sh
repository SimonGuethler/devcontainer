#!/bin/bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ==================== CONFIGURATION ====================
CONFIG_DIR="${HOME}/.config/opencode"
CONFIG_FILE="${CONFIG_DIR}/opencode.json"
AGENTS_SOURCE="${SCRIPT_DIR}/AGENTS.md"
HARNESS_SOURCE="${SCRIPT_DIR}/setup-opencode-harness.sh"
# =======================================================

CONFIG_TEMP=""
AUTH_FILE=""
MCP_STTY_STATE=""
cleanup() {
    local status=$?
    [[ -z "$CONFIG_TEMP" ]] || rm -f -- "$CONFIG_TEMP"
    [[ -z "$AUTH_FILE" ]] || rm -f -- "$AUTH_FILE"
    if [[ -n "$MCP_STTY_STATE" ]]; then
        stty "$MCP_STTY_STATE" 2>/dev/null || true
        printf '\033[?25h'
    fi
    return "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Pretty printing helpers
if command -v tput &> /dev/null \
        && [[ -n "${TERM:-}" ]] \
        && [[ "$(tput colors 2>/dev/null || echo 0)" =~ ^[1-9][0-9]*$ ]]; then
    BOLD="$(tput bold 2>/dev/null || true)"
    DIM="$(tput dim 2>/dev/null || true)"
    GREEN="$(tput setaf 2 2>/dev/null || true)"
    BLUE="$(tput setaf 4 2>/dev/null || true)"
    YELLOW="$(tput setaf 3 2>/dev/null || true)"
    RED="$(tput setaf 1 2>/dev/null || true)"
    RESET="$(tput sgr0 2>/dev/null || true)"
else
    BOLD=""
    DIM=""
    GREEN=""
    BLUE=""
    YELLOW=""
    RED=""
    RESET=""
fi

info()    { echo "${BLUE}[INFO]${RESET}  $*"; }
success() { echo "${GREEN}[OK]${RESET}   $*"; }
warn()    { echo "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo "${RED}[ERROR]${RESET} $*"; }

print_section() {
    echo ""
    echo "${BOLD}==== $* ====${RESET}"
}

# Interactive multi-select checklist (raw ANSI escapes, no tput required).
# ↑/↓ move, Space toggles, Enter confirms. Indices selected by default are
# passed as a space-separated string (e.g. "0 2"). Stores the chosen
# indices (space-separated) in MCP_MENU_CHOICES.
multi_select_menu() {
    local title="$1"
    local preselected="$2"
    shift 2
    local labels=("$@")
    local n=${#labels[@]}
    local -a sel=()
    local i cur=0 key k2 k3 joined="" name
    MCP_MENU_CHOICES=""

    for ((i=0; i<n; i++)); do
        sel[i]=0
    done
    for i in ${preselected}; do
        sel[i]=1
    done

    # Non-canonical input (byte-by-byte, no echo) for arrow-key handling;
    # ISIG stays on, so Ctrl+C still works. Restore terminal and cursor
    # on any exit.
    MCP_STTY_STATE="$(stty -g 2>/dev/null || true)"
    stty -icanon -echo min 1 time 0 2>/dev/null || true

    echo ""
    echo "${BOLD}==== ${title} ====${RESET}"
    echo "Use ${BOLD}↑/↓${RESET} to move, ${BOLD}Space${RESET} to toggle, ${BOLD}Enter${RESET} to confirm:"
    echo -ne "\e[?25l"
    for ((i=0; i<n; i++)); do
        if [[ "${sel[i]}" == 1 ]]; then
            echo -e "${GREEN}   [x] ${labels[i]}${RESET}"
        else
            echo -e "   [ ] ${labels[i]}"
        fi
    done

    while :; do
        IFS= read -rn1 key || break
        case "${key}" in
            $'\e')
                IFS= read -rn1 -t 0.2 k2 || k2=""
                if [[ "$k2" == "[" ]]; then
                    IFS= read -rn1 -t 0.2 k3 || k3=""
                    case "$k3" in
                        A) cur=$(( (cur + n - 1) % n )) ;;
                        B) cur=$(( (cur + 1) % n )) ;;
                    esac
                fi
                ;;
            " ") sel[cur]=$(( 1 - sel[cur] )) ;;
            ""|$'\r'|$'\n') break ;;
        esac
        echo -ne "\e[${n}A"
        for ((i=0; i<n; i++)); do
            echo -ne "\e[2K"
            if [[ "${sel[i]}" == 1 ]]; then
                if [[ "$i" == "$cur" ]]; then
                    echo -e "${BOLD}${GREEN} > [x] ${labels[i]}${RESET}"
                else
                    echo -e "${GREEN}   [x] ${labels[i]}${RESET}"
                fi
            else
                if [[ "$i" == "$cur" ]]; then
                    echo -e "${BOLD} > [ ] ${labels[i]}${RESET}"
                else
                    echo -e "   [ ] ${labels[i]}"
                fi
            fi
        done
    done

    stty "${MCP_STTY_STATE:-sane}" 2>/dev/null || true
    MCP_STTY_STATE=""
    echo -ne "\e[?25h"
    for ((i=0; i<n; i++)); do
        if [[ "${sel[i]}" == 1 ]]; then
            MCP_MENU_CHOICES+="${i} "
            name="${labels[i]}"
            [[ -n "$joined" ]] && joined+=", "
            joined+="${name}"
        fi
    done
    echo -ne "\e[${n}A\e[J"
    if [[ -n "$joined" ]]; then
        echo "  ${GREEN}Selected: ${joined}${RESET}"
    else
        echo "  ${DIM}Selected: none${RESET}"
    fi
}

# Official installer puts the binary at ~/.opencode/bin/opencode and only
# appends a PATH line to the shell rc *if* that dir is not already on the
# current session's PATH. That breaks the reinstall-after-uninstall flow:
# uninstall removes the rc lines but leaves a stale PATH entry, so the
# installer skips writing the rc, and a fresh shell can't find `opencode`.
# We always re-assert PATH ourselves (rc files + ~/.local/bin symlink).
OPENCODE_BIN_DIR="${HOME}/.opencode/bin"
# Keep variables literal for the shell startup file.
# shellcheck disable=SC2016
OPENCODE_PATH_EXPORT='export PATH="$HOME/.opencode/bin:$PATH"'
OPENCODE_ON_PATH_AT_START=false
if command -v opencode >/dev/null 2>&1; then
    OPENCODE_ON_PATH_AT_START=true
fi

opencode_path_reload_command() {
    case "${SHELL##*/}" in
        zsh)  echo "source ~/.zshrc && rehash" ;;
        bash) echo "source ~/.bashrc && hash -r" ;;
        *)    echo "$OPENCODE_PATH_EXPORT" ;;
    esac
}

ensure_opencode_on_path() {
    export PATH="${OPENCODE_BIN_DIR}:${PATH}"
    hash -r 2>/dev/null || true

    # Prefer a symlink into ~/.local/bin — already on PATH via .profile/.bashrc
    # for virtually every Ubuntu/WSL install, and survives the installer's
    # "already in PATH → skip rc write" heuristic.
    mkdir -p "${HOME}/.local/bin"
    if [[ -x "${OPENCODE_BIN_DIR}/opencode" ]]; then
        ln -sfn "${OPENCODE_BIN_DIR}/opencode" "${HOME}/.local/bin/opencode"
    fi

    # Also keep an explicit PATH export in common shell rc files so users
    # without ~/.local/bin on PATH still work. Create a missing rc file
    # (e.g. ~/.zshrc on a fresh zsh-only setup) instead of skipping it —
    # otherwise a freshly installed zsh never gets opencode on PATH.
    local rc
    for rc in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
        if [[ ! -f "$rc" ]]; then
            : > "$rc"
            info "Created ${rc} (did not exist)"
        fi
        if grep -qxF "$OPENCODE_PATH_EXPORT" "$rc" 2>/dev/null; then
            continue
        fi
        {
            echo ""
            echo "# BEGIN devcontainer opencode"
            echo "${OPENCODE_PATH_EXPORT}"
            echo "# END devcontainer opencode"
        } >> "$rc"
        info "Added OpenCode to PATH in ${rc}"
    done
}

remove_opencode_from_path() {
    # GNU sed: -i ; BSD/macOS sed: -i ''
    if sed --version >/dev/null 2>&1; then
        SED_IN=(-i)
    else
        SED_IN=(-i '')
    fi
    local rc
    for rc in "${HOME}/.bashrc" "${HOME}/.zshrc" "${HOME}/.bash_profile" "${HOME}/.profile"; do
        if [[ ! -f "$rc" ]]; then
            continue
        fi
        # Only strip the block the official installer / this script write —
        # not every line that happens to contain the word "opencode".
        # Match literal variables written by previous versions of the installer.
        # shellcheck disable=SC2016
        sed "${SED_IN[@]}" \
            -e '/^# BEGIN devcontainer opencode$/,/^# END devcontainer opencode$/d' \
            -e '/^# opencode$/d' \
            -e '/^export PATH="$HOME\/\.opencode\/bin:$PATH"$/d' \
            "$rc" 2>/dev/null || true
    done

    # Remove our symlink only if it points at the OpenCode binary.
    if [[ -L "${HOME}/.local/bin/opencode" ]]; then
        local target
        target="$(readlink -f "${HOME}/.local/bin/opencode" 2>/dev/null || true)"
        if [[ "$target" == *'/.opencode/bin/opencode' ]] || [[ ! -e "${HOME}/.local/bin/opencode" ]]; then
            rm -f "${HOME}/.local/bin/opencode"
        fi
    fi
}

usage() {
    cat <<EOF
${BOLD}Usage:${RESET} $0 [OPTIONS]

${BOLD}One-time setup script for OpenCode + LiteLLM proxy.${RESET}

${BOLD}OPTIONS${RESET}
    --install           Install OpenCode if not present
    --uninstall         Remove OpenCode installation and all config
    --key <API_KEY>     Your LiteLLM API key (required; also: LITELLM_API_KEY env)
    --base-url <URL>    LiteLLM proxy base URL (required) (also: LITELLM_BASE_URL env)
    --pdf-mcp           Enable the pdf-reader MCP server (skip prompt)
    --no-pdf-mcp        Disable the pdf-reader MCP server (skip prompt)
    --playwright-mcp    Enable the Playwright browser automation MCP server (skip prompt)
    --no-playwright-mcp Disable the Playwright browser automation MCP server (skip prompt)
    --litellm-mcp       Enable the LiteLLM MCP gateway (skip prompt)
    --no-litellm-mcp    Disable the LiteLLM MCP gateway (skip prompt)
    --extension         Install the custom coding guidelines (AGENTS.md) (skip prompt)
    --no-extension      Skip the custom coding guidelines (skip prompt)
    --lsp               Enable native LSP diagnostics (skip prompt)
    --no-lsp            Disable native LSP diagnostics (skip prompt)
    --context7          Enable Context7 documentation MCP (skip prompt)
    --no-context7       Disable Context7 documentation MCP (skip prompt)
    --dry-run           Preview config only (don't write)
    -h, --help          Show this help

${BOLD}EXAMPLES${RESET}
    $0 --install --key sk-abc123... --base-url https://your-proxy.example/v1
    $0 --key sk-abc123... --base-url http://gpu-server:4000/v1
EOF
    exit 0
}

fail() { error "$*" >&2; exit 1; }
require_value() {
    [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || fail "$1 requires a value."
}
set_option() {
    local name="$1" value="$2"
    [[ -z "${!name}" || "${!name}" == "$value" ]] || fail "Conflicting enable/disable options for ${name,,}."
    printf -v "$name" '%s' "$value"
}

INSTALL=false
UNINSTALL=false
DRY_RUN=false
API_KEY="${LITELLM_API_KEY:-}"
BASE_URL="${LITELLM_BASE_URL:-}"
PDF_MCP_FLAG=""
PLAYWRIGHT_MCP_FLAG=""
LITELLM_MCP_FLAG=""
EXTENSION_FLAG=""
LSP_FLAG=""
CONTEXT7_FLAG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install) INSTALL=true; shift ;;
        --uninstall) UNINSTALL=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --key) require_value "$@"; API_KEY="$2"; shift 2 ;;
        --base-url) require_value "$@"; BASE_URL="$2"; shift 2 ;;
        --pdf-mcp) set_option PDF_MCP_FLAG yes; shift ;;
        --no-pdf-mcp) set_option PDF_MCP_FLAG no; shift ;;
        --playwright-mcp) set_option PLAYWRIGHT_MCP_FLAG yes; shift ;;
        --no-playwright-mcp) set_option PLAYWRIGHT_MCP_FLAG no; shift ;;
        --litellm-mcp) set_option LITELLM_MCP_FLAG yes; shift ;;
        --no-litellm-mcp) set_option LITELLM_MCP_FLAG no; shift ;;
        --extension) set_option EXTENSION_FLAG yes; shift ;;
        --no-extension) set_option EXTENSION_FLAG no; shift ;;
        --lsp) set_option LSP_FLAG yes; shift ;;
        --no-lsp) set_option LSP_FLAG no; shift ;;
        --context7) set_option CONTEXT7_FLAG yes; shift ;;
        --no-context7) set_option CONTEXT7_FLAG no; shift ;;
        -h|--help) usage ;;
        *) fail "Unknown option: $1" ;;
    esac
done

[[ "$INSTALL" != true || "$UNINSTALL" != true ]] || fail "Choose either --install or --uninstall."
if [[ "$UNINSTALL" == true ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        info "Would remove OpenCode installation, configuration, data, and shell PATH entries."
        exit 0
    fi
    info "Removing OpenCode configuration..."
    rm -rf ~/.opencode
    rm -rf ~/.config/opencode
    rm -rf ~/.local/share/opencode
    remove_opencode_from_path
    success "OpenCode has been completely uninstalled."
    exit 0
fi

[[ -n "$API_KEY" ]] || fail "--key is required (or set LITELLM_API_KEY)."
[[ -n "$BASE_URL" ]] || fail "--base-url is required (or set LITELLM_BASE_URL)."
[[ "$BASE_URL" =~ ^https?://[^/[:space:]]+ ]] || fail "--base-url must be an HTTP(S) URL."
command -v jq >/dev/null 2>&1 || fail "jq is required."
[[ ! -e "${CONFIG_DIR}/opencode.jsonc" ]] || fail "opencode.jsonc exists; edit it manually instead."
EXISTING_CONFIG='{}'
if [[ -e "$CONFIG_FILE" ]]; then
    EXISTING_CONFIG="$(cat "$CONFIG_FILE")"
fi
# Reject malformed settings before installation, downloads, or writes. Do not
# print jq diagnostics: they may contain fragments of credentials.
if ! printf '%s' "$EXISTING_CONFIG" | jq -e -s '
    length == 1 and (.[0] | type == "object"
      and ((has("provider") | not) or (.provider | type == "object"))
      and ((.provider // {} | has("litellm") | not) or (.provider.litellm | type == "object"))
      and ((.provider.litellm // {} | has("options") | not) or (.provider.litellm.options | type == "object"))
      and ((has("mcp") | not) or (.mcp | type == "object" and all(.[]; type == "object")))
      and ((has("plugin") | not) or (.plugin | type == "array" and all(.[]; type == "string"))))
' >/dev/null 2>&1; then
    fail "Invalid OpenCode JSON configuration; no changes made."
fi

echo ""
echo "${BOLD}OpenCode with LiteLLM AutoSetup${RESET}"
echo "${DIM}------------------------------${RESET}"
echo "    Proxy URL: configured"
echo "    API key:  [redacted]"
echo ""

select_addons() {
    local i choice variable
    local -a menu_flags=() menu_labels=()
    EXTENSION_AVAILABLE=false
    [[ ! -f "$AGENTS_SOURCE" ]] || EXTENSION_AVAILABLE=true
    [[ "$EXTENSION_FLAG" != yes || "$EXTENSION_AVAILABLE" == true ]] || fail "--extension requires ${AGENTS_SOURCE}."
    [[ "$EXTENSION_AVAILABLE" == true ]] || EXTENSION_FLAG=no

    local -a flags=(LSP_FLAG CONTEXT7_FLAG LITELLM_MCP_FLAG PDF_MCP_FLAG PLAYWRIGHT_MCP_FLAG EXTENSION_FLAG)
    local -a labels=(
        "LSP diagnostics (requires project language servers)"
        "Context7 documentation (queries an external service)"
        "LiteLLM MCP gateway (MCP tools registered on the proxy)"
        "PDF / document reading (pdf-reader MCP)"
        "Playwright browser automation (downloads Chromium and system dependencies)"
        "Custom coding guidelines (AGENTS.md)"
    )
    local preselected=""
    for i in "${!flags[@]}"; do
        variable="${flags[i]}"
        if [[ -z "${!variable}" ]]; then
            preselected+="${#menu_flags[@]} "
            menu_flags+=("$variable")
            menu_labels+=("${labels[i]}")
            printf -v "$variable" '%s' yes
        fi
    done
    # Every available add-on defaults to selected, including unattended setup.
    if [[ ${#menu_flags[@]} -gt 0 && "$DRY_RUN" != true && -t 0 ]]; then
        multi_select_menu "Optional Add-ons" "$preselected" "${menu_labels[@]}"
        for variable in "${menu_flags[@]}"; do
            printf -v "$variable" '%s' no
        done
        for choice in $MCP_MENU_CHOICES; do
            printf -v "${menu_flags[choice]}" '%s' yes
        done
    fi
    PDF_MCP_ENABLED=false
    PLAYWRIGHT_MCP_ENABLED=false
    LITELLM_MCP_ENABLED=false
    EXTENSION_ENABLED=false
    [[ "$PDF_MCP_FLAG" != yes ]] || PDF_MCP_ENABLED=true
    [[ "$PLAYWRIGHT_MCP_FLAG" != yes ]] || PLAYWRIGHT_MCP_ENABLED=true
    [[ "$LITELLM_MCP_FLAG" != yes ]] || LITELLM_MCP_ENABLED=true
    [[ "$EXTENSION_FLAG" != yes ]] || EXTENSION_ENABLED=true
}
select_addons

# Reuse the harness for optional features after writing the provider config.
# Check its inputs before installation or config replacement can begin.
HARNESS_ARGS=()
[[ "$LSP_FLAG" == "yes" ]] && HARNESS_ARGS+=(--lsp)
[[ "$LSP_FLAG" == "no" ]] && HARNESS_ARGS+=(--no-lsp)
[[ "$CONTEXT7_FLAG" == "yes" ]] && HARNESS_ARGS+=(--context7)
[[ "$CONTEXT7_FLAG" == "no" ]] && HARNESS_ARGS+=(--no-context7)
if [[ ${#HARNESS_ARGS[@]} -gt 0 ]]; then
    if [[ ! -f "$HARNESS_SOURCE" ]]; then
        error "LSP/Context7 setup requires ${HARNESS_SOURCE}"
        exit 1
    fi
    bash "$HARNESS_SOURCE" --config-dir "$CONFIG_DIR" "${HARNESS_ARGS[@]}" --dry-run
fi

# Preview before registry queries, installation, cache changes, or config writes.
if [[ "$DRY_RUN" == true ]]; then
    info "Would merge LiteLLM provider settings and back up changed configuration."
    info "Install OpenCode: $INSTALL; PDF: $PDF_MCP_ENABLED; Playwright: $PLAYWRIGHT_MCP_ENABLED; gateway: $LITELLM_MCP_ENABLED; guidelines: $EXTENSION_ENABLED"
    info "LSP: ${LSP_FLAG:-unchanged}; Context7: ${CONTEXT7_FLAG:-unchanged}"
    exit 0
fi

# Resolve Playwright MCP and its Playwright dependency together. Browser
# revisions are version-specific, so installing an unrelated playwright@latest
# can leave the MCP package looking for a different Chromium executable.
PLAYWRIGHT_MCP_SPEC=""
PLAYWRIGHT_CLI_SPEC=""
PLAYWRIGHT_OUTPUT_DIR="${HOME}/.cache/opencode/playwright-mcp"
if [[ "$PLAYWRIGHT_MCP_ENABLED" == true ]]; then
    if ! command -v npm >/dev/null 2>&1; then
        error "npm is required for Playwright MCP but was not found"
        exit 1
    fi
    PLAYWRIGHT_MCP_VERSION="$(npm view @playwright/mcp version 2>/dev/null || true)"
    if [[ ! "$PLAYWRIGHT_MCP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]]; then
        error "Could not resolve the current @playwright/mcp version from npm"
        exit 1
    fi
    PLAYWRIGHT_VERSION="$(npm view "@playwright/mcp@${PLAYWRIGHT_MCP_VERSION}" dependencies.playwright 2>/dev/null || true)"
    if [[ ! "$PLAYWRIGHT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]]; then
        error "Could not resolve the Playwright version required by @playwright/mcp@${PLAYWRIGHT_MCP_VERSION}"
        exit 1
    fi
    PLAYWRIGHT_MCP_SPEC="@playwright/mcp@${PLAYWRIGHT_MCP_VERSION}"
    PLAYWRIGHT_CLI_SPEC="playwright@${PLAYWRIGHT_VERSION}"
    info "Pinning ${PLAYWRIGHT_MCP_SPEC} with ${PLAYWRIGHT_CLI_SPEC}"
fi

install_dependencies() {
    # Install OpenCode if requested
    if [[ "$INSTALL" == true ]]; then
        print_section "Installing OpenCode"

        if [[ -x "${OPENCODE_BIN_DIR}/opencode" ]]; then
            info "OpenCode binary already present at ${OPENCODE_BIN_DIR}/opencode"
        elif command -v opencode &> /dev/null; then
            info "OpenCode is already installed ($(command -v opencode))"
        else
            info "Running official installer..."
            if ! curl -fsSL https://opencode.ai/install | bash; then
                error "OpenCode installation command failed"
                exit 1
            fi
        fi

        # Always re-assert PATH / symlink. Do not rely on the official installer
        # alone — it silently skips rc writes when the install dir is already on
        # the *current* session PATH (common after uninstall-then-reinstall).
        ensure_opencode_on_path

        if command -v opencode &> /dev/null; then
            success "OpenCode installed successfully ($(opencode --version 2>/dev/null || echo ok))"
            info "Resolved as: $(command -v opencode)"
        elif [[ -x "${OPENCODE_BIN_DIR}/opencode" ]]; then
            success "OpenCode binary installed at ${OPENCODE_BIN_DIR}/opencode"
            warn "Not on PATH in this shell yet — open a new terminal, or run:"
            warn "  $(opencode_path_reload_command)"
        else
            error "OpenCode installation finished but binary not found at ${OPENCODE_BIN_DIR}/opencode"
            exit 1
        fi
    fi

    # Install the browser binary and Linux libraries required by Playwright MCP.
    # The explicit Chromium/headless/no-sandbox configuration matches Microsoft's
    # Playwright MCP container and works without a desktop session in devcontainers.
    if [[ "$PLAYWRIGHT_MCP_ENABLED" == true ]]; then
        print_section "Installing Playwright Chromium"
        if ! command -v npx >/dev/null 2>&1; then
            error "npx is required for Playwright MCP but was not found"
            exit 1
        fi
        mkdir -p "${PLAYWRIGHT_OUTPUT_DIR}"
        chmod 700 "${PLAYWRIGHT_OUTPUT_DIR}" 2>/dev/null || true
        info "Installing Chromium and its system dependencies (this may download a few hundred MB)..."
        if ! npx -y "${PLAYWRIGHT_CLI_SPEC}" install --with-deps chromium; then
            error "Could not install Playwright Chromium and its system dependencies"
            error "Re-run as a user with permission to install system packages, or disable it with --no-playwright-mcp"
            exit 1
        fi
        success "Playwright Chromium installed"
    fi

}
install_dependencies

write_configuration() {
    # Resolve the plugin version and merge configuration.
    # OpenCode caches plugins by the literal specifier string. `pkg@latest`
    # is a folder name, not a dist-tag refresh — once it exists, OpenCode
    # never asks npm again (stuck this host on 0.5.0). Resolve the current
    # registry version here, pin that exact version (so a later setup run
    # is a new cache key). Existing cache entries are retained.
    # Floor is 0.8.0: first release that GET /v1/model/info and writes
    # modalities. Do not pre-declare provider.litellm.models — the plugin
    # will not overwrite a hand-declared id.
    LITELLM_PLUGIN_MIN="0.8.0"
    LITELLM_PLUGIN_VER=""
    if command -v npm >/dev/null 2>&1; then
        LITELLM_PLUGIN_VER="$(npm view opencode-plugin-litellm version 2>/dev/null || true)"
    fi
    if [[ ! "${LITELLM_PLUGIN_VER}" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        LITELLM_PLUGIN_VER="${LITELLM_PLUGIN_MIN}"
        warn "Could not query npm for opencode-plugin-litellm; pinning ${LITELLM_PLUGIN_VER}"
    elif [[ "$(printf '%s\n' "${LITELLM_PLUGIN_VER}" "${LITELLM_PLUGIN_MIN}" | sort -V | head -n1)" != "${LITELLM_PLUGIN_MIN}" ]]; then
        warn "npm latest is ${LITELLM_PLUGIN_VER}, older than required ${LITELLM_PLUGIN_MIN}; pinning the floor"
        LITELLM_PLUGIN_VER="${LITELLM_PLUGIN_MIN}"
    else
        info "Pinning opencode-plugin-litellm@${LITELLM_PLUGIN_VER} (current npm latest)"
    fi
    # Merge only setup-owned fields. Pass the key through the environment rather
    # than command-line arguments, and let jq escape all strings.
    CONFIG_CONTENT="$(printf '%s' "$EXISTING_CONFIG" | \
        SETUP_API_KEY="$API_KEY" jq --arg base "$BASE_URL" --arg version "$LITELLM_PLUGIN_VER" \
        --argjson pdf "$PDF_MCP_ENABLED" --arg pdf_choice "$PDF_MCP_FLAG" \
        --argjson browser "$PLAYWRIGHT_MCP_ENABLED" --arg browser_choice "$PLAYWRIGHT_MCP_FLAG" \
        --argjson gateway "$LITELLM_MCP_ENABLED" --arg gateway_choice "$LITELLM_MCP_FLAG" \
        --arg browser_spec "$PLAYWRIGHT_MCP_SPEC" --arg output "$PLAYWRIGHT_OUTPUT_DIR" '
        def configure($name; $enabled; $choice; $defaults):
            if $choice == "no" then
                if (.mcp // {} | has($name)) then .mcp[$name].enabled = false else . end
            elif $enabled then
                .mcp[$name] = ($defaults * (.mcp[$name] // {}))
                | if $choice == "yes" then .mcp[$name].enabled = true else . end
            else . end;
        ."$schema" //= "https://opencode.ai/config.json"
        | .plugin = (((.plugin // []) | map(select(. != "opencode-plugin-litellm" and (startswith("opencode-plugin-litellm@") | not)))) + ["opencode-plugin-litellm@" + $version])
        | .provider.litellm.npm //= "@ai-sdk/openai-compatible"
        | .provider.litellm.name //= "LiteLLM"
        | .provider.litellm.options.baseURL = $base
        | .provider.litellm.options.apiKey = env.SETUP_API_KEY
        | configure("pdf-reader"; $pdf; $pdf_choice; {type: "local", command: ["npx", "-y", "@sylphx/pdf-reader-mcp@latest"], enabled: true})
        | configure("playwright"; $browser; $browser_choice; {type: "local", command: ["npx", "-y", $browser_spec, "--browser", "chromium", "--headless", "--no-sandbox", "--output-dir", $output], enabled: true})
        | if $browser and (.mcp.playwright.command | type) == "array"
              and (.mcp.playwright.command[2] | type) == "string"
              and (.mcp.playwright.command[2] | startswith("@playwright/mcp@"))
          then .mcp.playwright.command[2] = $browser_spec else . end
        | configure("litellm-tools"; $gateway; $gateway_choice; {type: "remote", oauth: false, enabled: true})
        | if $gateway then
            .mcp["litellm-tools"].url = (($base | rtrimstr("/") | rtrimstr("/v1")) + "/mcp")
            | .mcp["litellm-tools"].headers["x-litellm-api-key"] = ("Bearer " + env.SETUP_API_KEY)
          else . end
    ' 2>/dev/null)" || fail "Could not merge OpenCode configuration."

    mkdir -p "$CONFIG_DIR"
    chmod 700 "$CONFIG_DIR"
    if [[ ! -f "$CONFIG_FILE" ]] || ! cmp -s "$CONFIG_FILE" <(printf '%s\n' "$CONFIG_CONTENT"); then
        if [[ -f "$CONFIG_FILE" ]]; then
            CONFIG_BACKUP="$(mktemp "${CONFIG_FILE}.backup.XXXXXX")"
            cat "$CONFIG_FILE" > "$CONFIG_BACKUP"
            info "Previous configuration saved to ${CONFIG_BACKUP}"
        fi
        CONFIG_TEMP="$(mktemp "${CONFIG_FILE}.tmp.XXXXXX")"
        printf '%s\n' "$CONFIG_CONTENT" > "$CONFIG_TEMP"
        mv -f -- "$CONFIG_TEMP" "$CONFIG_FILE"
    fi
    success "Config ready at ${CONFIG_FILE}"
}
write_configuration

if [[ ${#HARNESS_ARGS[@]} -gt 0 ]]; then
    print_section "LSP and Documentation Setup"
    bash "$HARNESS_SOURCE" --config-dir "$CONFIG_DIR" "${HARNESS_ARGS[@]}"
fi

# ==================== VERIFY PROXY CONNECTION ====================
# Read the Authorization header from a temp file so the key never shows
# up in `ps` output.
print_section "Verifying Proxy Connection"
AUTH_FILE="$(mktemp)"
chmod 600 "$AUTH_FILE"
printf 'Authorization: Bearer %s\n' "${API_KEY}" > "$AUTH_FILE"
if curl -fsS --connect-timeout 5 --max-time 15 "${BASE_URL}/models" \
        -H "@${AUTH_FILE}" -o /dev/null 2>/dev/null; then
    success "Proxy reachable and API key accepted (${BASE_URL}/models)"
else
    warn "Could not reach ${BASE_URL}/models with this key"
    warn "Check your network/VPN and that the key is valid — OpenCode will still start, models just won't load."
fi
rm -f "$AUTH_FILE"
AUTH_FILE=""

# ==================== CUSTOM EXTENSION ====================
# Decided in the add-ons checklist above (or via --extension / --no-extension).
if [[ "$EXTENSION_ENABLED" == true ]]; then
    print_section "Custom Extension"
    info "Installing custom coding guidelines (AGENTS.md)..."
    AGENTS_FILE="${CONFIG_DIR}/AGENTS.md"
    if [[ -f "$AGENTS_FILE" ]] && ! cmp -s "$AGENTS_SOURCE" "$AGENTS_FILE"; then
        AGENTS_BACKUP="$(mktemp "${AGENTS_FILE}.backup.XXXXXX")"
        cp "$AGENTS_FILE" "$AGENTS_BACKUP"
        info "Previous coding guidelines saved to ${AGENTS_BACKUP}"
    fi
    cp "$AGENTS_SOURCE" "$AGENTS_FILE"
    chmod 600 "$AGENTS_FILE"
    success "Coding guidelines installed to ${AGENTS_FILE}"
fi

# ==================== FINAL SUMMARY ====================
print_section "Setup Complete"
echo ""
success "Start OpenCode with: ${BOLD}opencode${RESET}"
echo ""
echo "    Models and capabilities come from the LiteLLM proxy at startup"
echo "    (${DIM}/v1/models${RESET} + ${DIM}/v1/model/info${RESET}). Restart OpenCode after a proxy model change."
echo "    LiteLLM plugin pinned to ${BOLD}${LITELLM_PLUGIN_VER}${RESET} — re-run this script to pick up a newer plugin."
echo ""
if [[ "$OPENCODE_ON_PATH_AT_START" == true ]]; then
    info "opencode was already on PATH when setup started."
elif [[ -x "${OPENCODE_BIN_DIR}/opencode" ]]; then
    warn "OpenCode is installed, but this script cannot change the PATH of its parent shell."
    warn "To use it now without restarting the terminal, run:"
    warn "  $(opencode_path_reload_command)"
else
    warn "OpenCode is not installed. Re-run this setup with --install:"
    warn "  $0 --install --key <LITELLM_API_KEY>"
fi
echo ""
