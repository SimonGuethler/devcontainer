#!/bin/bash
# Configure the OpenCode edition only; leave provider authentication to LiteLLM.
set -euo pipefail
umask 077
MODEL="${OMO_MODEL:-}"
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        *) printf 'Unknown OpenAgent setup option: %s\n' "$1" >&2; exit 1 ;;
    esac
done
command -v jq >/dev/null
CONFIG_DIR="${HOME}/.omo"
CONFIG_FILE="${CONFIG_DIR}/omo.json"
if [[ -e "${CONFIG_DIR}/omo.jsonc" ]]; then
    printf 'Existing ~/.omo/omo.jsonc is preserved. Set [opencode].goal.enabled to false to avoid the OpenAgent 4.19.4 objective-length bug, then manage this JSONC configuration manually.\n' >&2
    exit 1
fi
EXISTING='{}'
[[ ! -e "$CONFIG_FILE" ]] || EXISTING="$(cat "$CONFIG_FILE")"
CONTENT="$(printf '%s' "$EXISTING" | jq -e -s --arg model "$MODEL" '
    if length != 1 or (.[0] | type) != "object" then error("Expected one object") else .[0] end
    | ."[opencode]" = ({
        goal: {enabled: false, auto_start: false, default_max_iterations: 100},
        team_mode: {enabled: false},
        codegraph: {enabled: true, auto_provision: true},
        background_task: {defaultConcurrency: 3},
        sisyphus_agent: {default_builder_enabled: true, replace_plan: false}
      } * (."[opencode]" // {}))
    | ."[opencode]" |= (
        # 4.19.4 treats ordinary messages as goals and throws above 2000 chars.
        # Override the old setup default on reruns, not just fresh installs.
        .goal.enabled = false
        | .disabled_mcps = (((.disabled_mcps // []) + ["context7"]) | unique)
        | if $model != "" then
            reduce ["sisyphus", "hephaestus", "prometheus", "oracle", "librarian", "explore", "multimodal-looker", "metis", "momus", "atlas", "sisyphus-junior"][] as $agent
                (.; .agents[$agent].model //= $model)
            | reduce ["visual-engineering", "ultrabrain", "deep", "artistry", "quick", "unspecified-low", "unspecified-high", "writing"][] as $category
                (.; .categories[$category].model //= $model)
          else . end
        | .telemetry //= false
      )
  ' 2>/dev/null)" || { printf 'Invalid OpenAgent configuration; no changes made.\n' >&2; exit 1; }
if [[ "$DRY_RUN" == true ]]; then
    printf 'Would default CodeGraph to enabled with automatic provisioning, disable the faulty OpenAgent goal hook, bound background concurrency, and preserve existing models.\n'
    exit 0
fi
mkdir -p "$CONFIG_DIR"
TEMP_FILE=""
trap '[[ -z "$TEMP_FILE" ]] || rm -f -- "$TEMP_FILE"' EXIT
if [[ ! -f "$CONFIG_FILE" ]] || ! cmp -s "$CONFIG_FILE" <(printf '%s\n' "$CONTENT"); then
    if [[ -f "$CONFIG_FILE" ]]; then
        BACKUP="$(mktemp "${CONFIG_FILE}.backup.XXXXXX")"
        cat "$CONFIG_FILE" > "$BACKUP"
    fi
    TEMP_FILE="$(mktemp "${CONFIG_FILE}.tmp.XXXXXX")"
    printf '%s\n' "$CONTENT" > "$TEMP_FILE"
    mv -f -- "$TEMP_FILE" "$CONFIG_FILE"
fi
printf 'OpenAgent configured. Restart OpenCode and give Sisyphus your task. The faulty /goal continuation hook is disabled.\n'
printf 'CodeGraph defaults to enabled with automatic provisioning at session start; existing explicit settings are preserved. After first provisioning, restart OpenCode if its MCP still shows disabled.\n'
if [[ -z "$MODEL" ]]; then
    printf 'No workspace model defaults applied. Check OpenAgent agent/category assignments; upstream defaults may require other providers.\n'
fi
