#!/bin/bash
# Optional integration check using an installed OpenCode and OpenAgent bundle.
# Usage: bash test-opencode-agent-display.sh /path/to/opencode /path/to/dist/index.js
set -euo pipefail
umask 077
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCODE_BIN="$(realpath -- "${1:?Pass the installed OpenCode executable}")"
OPENAGENT_BUNDLE="$(realpath -- "${2:?Pass the installed OpenAgent dist/index.js}")"
[[ -x "$OPENCODE_BIN" && -f "$OPENAGENT_BUNDLE" ]]
command -v jq >/dev/null
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export HOME="${TEST_ROOT}/home"
export XDG_CONFIG_HOME="${TEST_ROOT}/config" XDG_DATA_HOME="${TEST_ROOT}/data"
export XDG_CACHE_HOME="${TEST_ROOT}/cache" XDG_STATE_HOME="${TEST_ROOT}/state"
export OPENCODE_CONFIG_DIR="${XDG_CONFIG_HOME}/opencode"
export OPENCODE_DISABLE_DEFAULT_PLUGINS=true OPENCODE_DISABLE_MODELS_FETCH=true
unset OPENCODE_CONFIG OPENCODE_CONFIG_CONTENT OMO_MODEL
mkdir -p "$HOME" "${TEST_ROOT}/project"
cd "${TEST_ROOT}/project"
bash "${SCRIPT_DIR}/setup-opencode-harness.sh" --config-dir "$OPENCODE_CONFIG_DIR" >/dev/null
bash "${SCRIPT_DIR}/setup-openagent.sh" >/dev/null
# Disable external services; this check never sends a model prompt.
jq '."[opencode]".disabled_mcps = ["context7", "websearch", "grep_app"]' \
    "$HOME/.omo/omo.json" > "${TEST_ROOT}/omo.json"
cp "${TEST_ROOT}/omo.json" "$HOME/.omo/omo.json"
jq -n --arg plugin "file://${OPENAGENT_BUNDLE}" '{
    plugin: [$plugin], default_agent: "apollo-analyzer",
    agent: {"apollo-analyzer": {model: "litellm/test-model", variant: "low"}}
}' > "${OPENCODE_CONFIG_DIR}/opencode.json"
timeout 60 "$OPENCODE_BIN" debug config </dev/null > "${TEST_ROOT}/resolved.json"
jq -e '.default_agent == "Apollo - Analyzer"
    and .agent["Apollo - Analyzer"].name == "Apollo - Analyzer"
    and .agent["Apollo - Analyzer"].mode == "primary"
    and .agent["Apollo - Analyzer"].model == "litellm/test-model"
    and .agent["Apollo - Analyzer"].variant == "low"
    and (.agent["apollo-analyzer"] == null or .agent["apollo-analyzer"].name == "Apollo - Analyzer")
    and .agent["Hephaestus - Deep Agent"].mode == "subagent"
    and .agent.plan.mode == "subagent"' "${TEST_ROOT}/resolved.json" >/dev/null || {
    jq '{default_agent, agents: (.agent | with_entries(.value |= {name, mode, model, variant}))}' \
        "${TEST_ROOT}/resolved.json" >&2
    exit 1
}
timeout 60 "$OPENCODE_BIN" agent list </dev/null > "${TEST_ROOT}/agents.txt"
grep -Fx 'Apollo - Analyzer (primary)' "${TEST_ROOT}/agents.txt" >/dev/null
printf 'PASS: runtime Apollo display name, default agent, model, variant, and primary/subagent modes\n'
