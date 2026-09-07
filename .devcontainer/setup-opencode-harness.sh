#!/bin/bash
# Local-only installation. No credentials, downloads, or model calls required.
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${HOME}/.config/opencode"
DRY_RUN=false
LSP=""
CONTEXT7=""

fail() {
    printf 'Harness setup failed: %s\n' "$*" >&2
    exit 1
}

set_feature() {
    local name="$1" value="$2"
    [[ -z "${!name}" || "${!name}" == "$value" ]] || fail "Choose only one enable/disable flag for ${name,,}."
    printf -v "$name" '%s' "$value"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config-dir)
            [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || fail "--config-dir requires a path."
            CONFIG_DIR="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --lsp) set_feature LSP true; shift ;;
        --no-lsp) set_feature LSP false; shift ;;
        --context7) set_feature CONTEXT7 true; shift ;;
        --no-context7) set_feature CONTEXT7 false; shift ;;
        --help)
            cat <<'EOF'
Usage: bash setup-opencode-harness.sh [options]
Installs workspace-review and three on-demand skills; preserves other files.
  --config-dir <path>       OpenCode config directory (default ~/.config/opencode)
  --dry-run                 Preview without changing configuration or printing credentials
  --lsp / --no-lsp           Enable/disable native LSP; unchanged when omitted
  --context7 / --no-context7 Enable/disable Context7; unchanged when omitted
Existing changed files are backed up. Feature configuration requires jq.
EOF
            exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
done

CONFIG_DIR="$(realpath -m -- "$CONFIG_DIR")"
FILES=(
    agents/workspace-review.md
    skills/workspace-verification/SKILL.md
    skills/workspace-browser-check/SKILL.md
    skills/workspace-memory/SKILL.md
)

# Stage and validate all inputs before touching the destination.
STAGING="$(mktemp -d)"
trap 'rm -rf -- "$STAGING"' EXIT
for file in "${FILES[@]}"; do
    mkdir -p -- "${STAGING}/$(dirname "$file")"
    cp -- "${SCRIPT_DIR}/opencode/${file}" "${STAGING}/${file}"
done

if [[ -n "$LSP" || -n "$CONTEXT7" ]]; then
    command -v jq >/dev/null 2>&1 || fail "jq is required for LSP/Context7 configuration."
    [[ ! -e "${CONFIG_DIR}/opencode.jsonc" ]] || fail "opencode.jsonc exists; edit its LSP/MCP settings manually or run without feature flags."
    if [[ -e "${CONFIG_DIR}/opencode.json" ]]; then
        cp -- "${CONFIG_DIR}/opencode.json" "${STAGING}/input.json"
    else
        printf '%s\n' "{\"\$schema\":\"https://opencode.ai/config.json\"}" > "${STAGING}/input.json"
    fi
    # Slurp rejects empty input and multiple top-level JSON values. Suppress jq
    # errors because parser diagnostics can include fragments of credentials.
    if ! jq -e -s --arg lsp "$LSP" --arg context7 "$CONTEXT7" '
        if length != 1 or (.[0] | type) != "object" then error("Expected one object") else .[0] end
        | if $lsp == "true" then
            (if (.lsp | type) != "object" then .lsp = {} else . end)
            | .lsp.just //= {command: ["just-lsp"], extensions: [".just", ".justfile"]}
          elif $lsp == "false" then .lsp = false else . end
        | if $context7 != "" then
            if has("mcp") and (.mcp | type) != "object" then error("Invalid mcp") else . end
            | if (.mcp // {} | has("context7")) and (.mcp.context7 | type) != "object"
              then error("Invalid context7") else . end
            | .mcp.context7 //= {type: "remote", url: "https://mcp.context7.com/mcp"}
            | .mcp.context7.enabled = ($context7 == "true")
          else . end
    ' "${STAGING}/input.json" > "${STAGING}/opencode.json" 2>/dev/null; then
        fail "opencode.json must contain one valid JSON object with object-valued MCP settings; no files changed."
    fi
    FILES+=(opencode.json)
fi

TEMPORARY=""
trap '[[ -z "$TEMPORARY" ]] || rm -f -- "$TEMPORARY"; rm -rf -- "$STAGING"' EXIT
for file in "${FILES[@]}"; do
    source_file="${STAGING}/${file}"
    destination="${CONFIG_DIR}/${file}"
    if [[ -f "$destination" ]] && cmp -s -- "$source_file" "$destination"; then
        continue
    fi
    if [[ "$DRY_RUN" == true ]]; then
        printf 'Would install %s\n' "$destination"
        continue
    fi
    mkdir -p -- "$(dirname "$destination")"
    if [[ -e "$destination" ]]; then
        backup="$(mktemp "${destination}.backup.XXXXXX")"
        cat -- "$destination" > "$backup"
        printf 'Backed up %s to %s\n' "$destination" "$backup"
    fi
    TEMPORARY="$(mktemp "${destination}.tmp.XXXXXX")"
    cat -- "$source_file" > "$TEMPORARY"
    mv -f -- "$TEMPORARY" "$destination"
    TEMPORARY=""
    printf 'Installed %s\n' "$destination"
done

if [[ "$DRY_RUN" == true ]]; then
    printf 'Preview complete; no files changed.\n'
else
    printf 'Harness ready. Start a new OpenCode session.\n'
fi
