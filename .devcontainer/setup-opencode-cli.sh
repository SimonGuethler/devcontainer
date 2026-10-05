#!/bin/bash
# Install optional CLI integrations privately, without changing global packages.
set -euo pipefail
umask 077
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${HOME}/.config/opencode"
PLAYWRIGHT=no
PAPER_SEARCH=no
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config-dir|--playwright|--paper-search)
            [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { echo "$1 requires a value" >&2; exit 1; }
            case "$1" in
                --config-dir) CONFIG_DIR="$2" ;;
                --playwright) PLAYWRIGHT="$2" ;;
                --paper-search) PAPER_SEARCH="$2" ;;
            esac
            shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "Unknown CLI setup option: $1" >&2; exit 1 ;;
    esac
done
for mode in "$PLAYWRIGHT" "$PAPER_SEARCH"; do
    [[ "$mode" == yes || "$mode" == no || "$mode" == mcp ]] || { echo "Invalid CLI mode" >&2; exit 1; }
done
CONFIG_DIR="$(realpath -m -- "$CONFIG_DIR")"
TOOLS_DIR="${CONFIG_DIR}/tools"
SKILL_SOURCE="${SCRIPT_DIR}/opencode/optional-skills"
for skill in playwright-cli paper-search; do
    [[ -f "${SKILL_SOURCE}/${skill}/SKILL.md" ]] || { echo "Missing ${skill} skill" >&2; exit 1; }
done
for source in "${SKILL_SOURCE}/playwright-cli/scripts/run.sh" "${SCRIPT_DIR}/opencode/playwright-cli.config.json"; do
    [[ -f "$source" ]] || { echo "Missing CLI setup input: $source" >&2; exit 1; }
done
if [[ "$DRY_RUN" == true ]]; then
    printf 'CLI skills: Playwright=%s; Paper Search=%s (yes=CLI, mcp=MCP fallback, no=disabled).\n' "$PLAYWRIGHT" "$PAPER_SEARCH"
    printf 'The main setup disables old MCP entries in CLI mode. Playwright uses %s; Paper Search uses the uvx cache.\n' "$TOOLS_DIR"
    exit 0
fi

# Validate required executables before making changes.
[[ "$PLAYWRIGHT" != yes ]] || command -v npm >/dev/null || { echo "npm is required for the Playwright CLI integration" >&2; exit 1; }
[[ "$PLAYWRIGHT" != yes ]] || command -v npx >/dev/null || { echo "npx is required to install the Playwright browser" >&2; exit 1; }
[[ "$PAPER_SEARCH" != yes ]] || command -v uvx >/dev/null || { echo "uvx is required for the Paper Search CLI integration" >&2; exit 1; }

TEMPORARY=""
trap '[[ -z "$TEMPORARY" ]] || rm -f -- "$TEMPORARY"' EXIT
install_file() {
    local source="$1" destination="$2" backup
    [[ ! -f "$destination" ]] || ! cmp -s "$source" "$destination" || return 0
    mkdir -p "$(dirname "$destination")"
    if [[ -e "$destination" ]]; then
        backup="$(mktemp "${destination}.backup.XXXXXX")"
        cat "$destination" > "$backup"
    fi
    TEMPORARY="$(mktemp "${destination}.tmp.XXXXXX")"
    cat "$source" > "$TEMPORARY"
    mv -f -- "$TEMPORARY" "$destination"
    TEMPORARY=""
}

if [[ "$PLAYWRIGHT" == yes ]]; then
    # Resolve the agent CLI and browser installer from the same release.
    version="$(npm view @playwright/cli version)"
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]] || { echo 'Could not resolve Playwright CLI version' >&2; exit 1; }
    browser_version="$(npm view "@playwright/cli@${version}" dependencies.playwright)"
    [[ "$browser_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]] || { echo 'Could not resolve matching Playwright browser version' >&2; exit 1; }
    printf 'Installing @playwright/cli@%s with playwright@%s Chromium.\n' "$version" "$browser_version"
    npm install --prefix "${TOOLS_DIR}/playwright" --no-audit --no-fund --save-exact "@playwright/cli@${version}"
    npx -y "playwright@${browser_version}" install --with-deps chromium
    "${TOOLS_DIR}/playwright/node_modules/.bin/playwright-cli" --help >/dev/null
    # Preserve user-edited launch settings on reruns.
    if [[ ! -e "${TOOLS_DIR}/playwright/cli.config.json" ]]; then
        install_file "${SCRIPT_DIR}/opencode/playwright-cli.config.json" "${TOOLS_DIR}/playwright/cli.config.json"
    fi
fi
if [[ "$PAPER_SEARCH" == yes ]]; then
    # Warm and verify the exact environment used by the skill; no global install.
    uvx --with 'mcp<2' --from paper-search-mcp==0.1.4 paper-search --help >/dev/null
fi

# Expose only the selected CLI skills. Backups retain customized instructions,
# but have no SKILL.md filename and therefore are not discovered as active skills.
for skill in playwright-cli paper-search; do
    mode="$PLAYWRIGHT"
    [[ "$skill" != paper-search ]] || mode="$PAPER_SEARCH"
    destination="${CONFIG_DIR}/skills/${skill}/SKILL.md"
    if [[ "$mode" == yes ]]; then
        install_file "${SKILL_SOURCE}/${skill}/SKILL.md" "$destination"
        if [[ "$skill" == playwright-cli ]]; then
            install_file "${SKILL_SOURCE}/${skill}/scripts/run.sh" "${CONFIG_DIR}/skills/${skill}/scripts/run.sh"
        fi
    elif [[ -f "$destination" ]]; then
        backup="$(mktemp "${destination}.backup.XXXXXX")"
        mv -f -- "$destination" "$backup"
    fi
done
printf 'CLI integrations configured. Restart OpenCode to refresh skills and tools.\n'
