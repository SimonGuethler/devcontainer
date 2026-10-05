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
[[ -z "$MODEL" || "$MODEL" == */?* ]] || { printf 'OMO_MODEL requires provider/model.\n' >&2; exit 1; }
command -v jq >/dev/null || { printf 'jq is required to configure OpenAgent.\n' >&2; exit 1; }
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
        team_mode: {enabled: true},
        background_task: {defaultConcurrency: 3},
        sisyphus_agent: {default_builder_enabled: false, replace_plan: true}
      } * (."[opencode]" // {}))
    | ."[opencode]" |= (
        # 4.19.4 treats ordinary messages as goals and throws above 2000 chars.
        # Override the old setup default on reruns, not just fresh installs.
        .goal.enabled = false
        # Apollo - Analyzer is the OpenCode default. OMO ranks it first, followed by these
        # core agents. default_builder_enabled = false keeps the native build agent as a
        # hidden subagent instead of a selectable primary agent.
        | .agent_order = ["sisyphus", "prometheus", "atlas"]
        | .sisyphus_agent.default_builder_enabled = false
        | .sisyphus_agent.planner_enabled = true
        | .sisyphus_agent.replace_plan = true
        | .agents.hephaestus.mode = "subagent"
        | .agents["apollo-analyzer"].displayName = "Apollo - Analyzer"
        | .disabled_mcps = (((.disabled_mcps // []) + ["context7"]) | unique)
        | del(.codegraph)
        | if $model != "" then
            reduce ["sisyphus", "hephaestus", "prometheus", "oracle", "librarian", "explore", "multimodal-looker", "metis", "momus", "atlas", "sisyphus-junior"][] as $agent
                (.; .agents[$agent].model = $model)
            # Keep legacy deep for older supported releases; 5.1.x splits that lane.
            | reduce ["visual-engineering", "ultrabrain", "deep", "deep-low", "deep-high", "artistry", "quick", "unspecified-low", "unspecified-high", "writing"][] as $category
                (.; .categories[$category].model = $model)
          else . end
        | .telemetry = false
      )
  ' 2>/dev/null)" || { printf 'Invalid OpenAgent configuration; no changes made.\n' >&2; exit 1; }
if [[ "$DRY_RUN" == true ]]; then
    printf 'Would disable OpenAgent and telemetry, remove the retired codegraph key, and bound background concurrency.\n'
    printf 'Would configure the primary cycle: Apollo - Analyzer -> Sisyphus -> Prometheus -> Atlas.\n'
    if [[ -n "$MODEL" ]]; then
        printf 'Would switch built-in OpenAgent agent/category models to %s.\n' "$MODEL"
    else
        printf 'Would preserve existing model assignments.\n'
    fi
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
printf 'OpenAgent configured. With setup-opencode.sh, new sessions start on Apollo - Analyzer; cycle through Sisyphus, Prometheus, and Atlas. Restart OpenCode. The faulty /goal continuation hook is disabled.\n'
printf 'OpenAgent telemetry is disabled, including previously enabled settings. The retired codegraph key is removed.\n'
if [[ -z "$MODEL" ]]; then
    printf 'No workspace model defaults applied. Check OpenAgent agent/category assignments; upstream defaults may require other providers.\n'
else
    printf 'Built-in OpenAgent agent/category models set to %s. Restart OpenCode to apply the change.\n' "$MODEL"
fi
