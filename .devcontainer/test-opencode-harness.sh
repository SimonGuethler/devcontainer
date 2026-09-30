#!/bin/bash
# Run in isolation with dummy credentials; never use the caller's OpenCode config.
set -euo pipefail
umask 077
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/setup-opencode-harness.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
trap 'printf "FAIL at line %s\n" "$LINENO" >&2' ERR
command -v jq >/dev/null
shopt -s nullglob

# Exercise reload hints without running setup or touching user configuration.
(
    # shellcheck disable=SC1090 # Load only the helper, without executing setup.
    source <(sed -n '/^opencode_path_reload_command() {$/,/^}$/p' "${SCRIPT_DIR}/setup-opencode.sh")
    # shellcheck disable=SC2016
    OPENCODE_PATH_EXPORT='export PATH="$HOME/.opencode/bin:$PATH"'
    unset SHELL
    [[ "$(opencode_path_reload_command)" == "$OPENCODE_PATH_EXPORT" ]]
    SHELL=''
    [[ "$(opencode_path_reload_command)" == "$OPENCODE_PATH_EXPORT" ]]
    SHELL=/bin/zsh
    [[ "$(opencode_path_reload_command)" == 'source ~/.zshrc && rehash' ]]
    SHELL=/bin/bash
    [[ "$(opencode_path_reload_command)" == 'source ~/.bashrc && hash -r' ]]
    SHELL=/bin/fish
    [[ "$(opencode_path_reload_command)" == "$OPENCODE_PATH_EXPORT" ]]
)
printf 'PASS: reload hints handle unset, empty, and supported shell values\n'

fixture() {
    CONFIG_DIR="${TEST_ROOT}/$1/config with spaces"
    CONFIG_FILE="${CONFIG_DIR}/opencode.json"
}
run() {
    bash "$SCRIPT" --config-dir "$CONFIG_DIR" "$@" > "${TEST_ROOT}/output" 2>&1
}
expect_failure() {
    if run "$@"; then
        printf 'Expected failure\n' >&2
        exit 1
    fi
}
check() {
    jq -e "$1" "$CONFIG_FILE" >/dev/null
}
check_output() {
    if grep -q 'sk-test-only' "${TEST_ROOT}/output"; then
        printf 'Credentials appeared in output\n' >&2
        exit 1
    fi
}

fixture defaults
run
[[ ! -e "$CONFIG_FILE" ]]
grep -q 'mode: subagent' "${CONFIG_DIR}/agents/workspace-review.md"
skills=("${CONFIG_DIR}"/skills/*)
[[ ${#skills[@]} -eq 3 ]]
run
agents=("${CONFIG_DIR}"/agents/*)
[[ ${#agents[@]} -eq 1 ]]
printf 'PASS: default installation and rerun\n'

fixture preservation
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_FILE" <<'EOF'
{
  "model": "litellm/test-model",
  "plugin": ["example@1.0.0"],
  "provider": {"litellm": {"options": {"apiKey": "sk-test-only"}}},
  "lsp": {"rust": {"command": ["rust-analyzer"]}},
  "mcp": {
    "custom": {"type": "remote", "url": "https://example.invalid/mcp"},
    "context7": {"type": "remote", "url": "https://example.invalid/docs", "headers": {"key": "test-only"}}
  }
}
EOF
cp "$CONFIG_FILE" "${TEST_ROOT}/original.json"
run --lsp --context7
jq -e --slurpfile original "${TEST_ROOT}/original.json" '
    del(.lsp.just) == ($original[0] | .mcp.context7.enabled = true)
' "$CONFIG_FILE" >/dev/null
check_output
backups=("${CONFIG_FILE}".backup.*)
[[ ${#backups[@]} -eq 1 ]]
cmp -s "${backups[0]}" "${TEST_ROOT}/original.json"
[[ "$(stat -c %a "$CONFIG_FILE")" == 600 ]]
[[ "$(stat -c %a "${backups[0]}")" == 600 ]]
run --no-lsp --no-context7
check '.lsp == false and .mcp.context7.enabled == false'
printf 'PASS: configuration preservation, private backups, and disabling\n'

fixture preview
run --dry-run --lsp --context7
[[ ! -e "$CONFIG_DIR" ]]
fixture preservation
cp "$CONFIG_FILE" "${TEST_ROOT}/before-preview.json"
backups_before=("${CONFIG_FILE}".backup.*)
run --dry-run --lsp --context7
cmp -s "$CONFIG_FILE" "${TEST_ROOT}/before-preview.json"
backups_after=("${CONFIG_FILE}".backup.*)
[[ ${#backups_before[@]} -eq ${#backups_after[@]} ]]
check_output
printf 'PASS: dry-run leaves new and existing configurations untouched\n'

fixture features
run --lsp --context7
check '.lsp.just == {command: ["just-lsp"], extensions: [".just", ".justfile"]} and .mcp.context7 == {type: "remote", url: "https://mcp.context7.com/mcp", enabled: true}'
run --lsp --context7
backups=("${CONFIG_FILE}".backup.*)
[[ ${#backups[@]} -eq 0 ]]
printf 'PASS: fresh features and idempotent rerun\n'

jq '.lsp.just = {command: ["custom-just-lsp"], extensions: ["/workspace/project/justfile"], disabled: true}' \
    "$CONFIG_FILE" > "${TEST_ROOT}/custom-just.json"
cp "${TEST_ROOT}/custom-just.json" "$CONFIG_FILE"
run --lsp
cmp -s "$CONFIG_FILE" "${TEST_ROOT}/custom-just.json"
printf 'PASS: custom Just command, filename selector, and disabled state preserved\n'

printf 'custom reviewer' > "${CONFIG_DIR}/agents/workspace-review.md"
printf 'personal agent' > "${CONFIG_DIR}/agents/personal.md"
run
backups=("${CONFIG_DIR}"/agents/workspace-review.md.backup.*)
[[ ${#backups[@]} -eq 1 && "$(cat "${backups[0]}")" == 'custom reviewer' ]]
[[ "$(cat "${CONFIG_DIR}/agents/personal.md")" == 'personal agent' ]]
printf 'PASS: changed agent backed up; unrelated agents retained\n'

index=0
for contents in '{ "apiKey": "sk-test-only",' null '[]' '{"mcp":false}' '{"mcp":null}' '{"mcp":{"context7":false}}' '{"mcp":{"context7":null}}' '' '{} {}'; do
    fixture "invalid-$index"
    index=$((index + 1))
    mkdir -p "$CONFIG_DIR"
    printf '%s' "$contents" > "$CONFIG_FILE"
    expect_failure --context7
    [[ ! -e "${CONFIG_DIR}/agents" && "$(cat "$CONFIG_FILE")" == "$contents" ]]
    check_output
done
fixture jsonc
mkdir -p "$CONFIG_DIR"
printf '// personal config' > "${CONFIG_DIR}/opencode.jsonc"
expect_failure --lsp
[[ ! -e "${CONFIG_DIR}/agents" ]]
run
printf 'PASS: invalid JSON and JSONC rejected before installation\n'

fixture flags
expect_failure --lsp --no-lsp
expect_failure --context7 --no-context7
expect_failure --unknown
expect_failure --config-dir
[[ ! -e "$CONFIG_DIR" ]]
printf 'PASS: invalid flags leave no configuration\n'

# Exercise the shell entry point with real jq and mocked network commands.
mkdir -p "${TEST_ROOT}/bin"
install_npm_mock() {
    printf '%s\n' "$1" > "${TEST_ROOT}/npm-version"
    cat > "${TEST_ROOT}/bin/npm" <<'EOF'
#!/bin/bash
if [[ "$1" == install && "$2" == --prefix ]]; then
    mkdir -p "$3/node_modules/.bin"
    printf '#!/bin/bash\nexit 0\n' > "$3/node_modules/.bin/playwright-cli"
    chmod +x "$3/node_modules/.bin/playwright-cli"
else
    cat "$(dirname "$0")/../npm-version"
fi
EOF
    chmod +x "${TEST_ROOT}/bin/npm"
}
printf '#!/bin/bash\nexit 0\n' > "${TEST_ROOT}/bin/uvx"
install_npm_mock 0.8.0
printf '#!/bin/bash\nexit 0\n' > "${TEST_ROOT}/bin/curl"
printf '#!/bin/bash\nexit 0\n' > "${TEST_ROOT}/bin/npx"
chmod +x "${TEST_ROOT}/bin/"*
for state in enabled disabled; do
    flags=(--lsp --context7)
    [[ "$state" != disabled ]] || flags=(--no-lsp --no-context7)
    isolated_home="${TEST_ROOT}/integration-${state}"
    env HOME="$isolated_home" PATH="${TEST_ROOT}/bin:${PATH}" LITELLM_API_KEY=sk-test-only \
        bash "${SCRIPT_DIR}/setup-opencode.sh" --base-url https://example.invalid/v1 \
        --no-pdf-mcp --no-playwright-mcp --no-litellm-mcp --no-extension "${flags[@]}" \
        </dev/null > "${TEST_ROOT}/output" 2>&1
    CONFIG_FILE="${isolated_home}/.config/opencode/opencode.json"
    expected=true
    [[ "$state" != disabled ]] || expected=false
    check "(.lsp != false) == $expected and .mcp.context7.enabled == $expected"
    check '.provider.litellm.options.apiKey == "sk-test-only"'
    check '.agent.build.color == "#60A5FA" and .agent.plan.color == "#FB923C"'
done
printf 'PASS: setup entry point enables and disables harness features\n'

main_run() {
    env HOME="$isolated_home" PATH="${TEST_ROOT}/bin:${PATH}" \
        LITELLM_API_KEY=sk-test-only LITELLM_BASE_URL=https://example.invalid/v1 \
        bash "${SCRIPT_DIR}/setup-opencode.sh" "$@" \
        </dev/null > "${TEST_ROOT}/output" 2>&1
}
isolated_home="${TEST_ROOT}/main-preservation"
CONFIG_FILE="${isolated_home}/.config/opencode/opencode.json"
mkdir -p "$(dirname "$CONFIG_FILE")"
jq '.mcp.context7.enabled = true | .lsp.just = {command: ["just-lsp"], extensions: [".just", ".justfile"]}
    | .agent = {build: {color: "#123456", model: "custom/model"}, plan: {color: "warning", permission: {edit: "deny"}}}' \
    "${TEST_ROOT}/original.json" > "${TEST_ROOT}/updated-original.json"
cp "${TEST_ROOT}/updated-original.json" "${TEST_ROOT}/original.json"
cp "${TEST_ROOT}/original.json" "$CONFIG_FILE"
main_run --no-extension
jq -e --slurpfile original "${TEST_ROOT}/original.json" '
    .model == $original[0].model and .lsp == $original[0].lsp
    and .agent == $original[0].agent
    and .mcp.custom == $original[0].mcp.custom
    and .mcp.context7 == $original[0].mcp.context7
    and (.plugin | index("example@1.0.0") != null)
' "$CONFIG_FILE" >/dev/null
backups=("${CONFIG_FILE}".backup.*)
[[ ${#backups[@]} -eq 1 ]]
cmp -s "${backups[0]}" "${TEST_ROOT}/original.json"
[[ "$(stat -c %a "${backups[0]}")" == 600 ]]
main_run --no-extension
backups=("${CONFIG_FILE}".backup.*)
[[ ${#backups[@]} -eq 1 ]]
main_run --no-extension --no-litellm-mcp --no-pdf-mcp
check '.mcp["litellm-tools"].enabled == false and .mcp["pdf-reader"].enabled == false'
check '(.mcp["paper-search"].enabled // false) == false'
[[ -f "${isolated_home}/.config/opencode/skills/paper-search/SKILL.md" ]]
main_run --paper-search-mcp
check '.mcp["paper-search"] == {type: "local", command: ["uvx", "--with", "mcp<2", "paper-search-mcp==0.1.4"], enabled: true}'
[[ ! -f "${isolated_home}/.config/opencode/skills/paper-search/SKILL.md" ]]
main_run --no-paper-search-mcp
check '(.mcp["paper-search"].enabled // false) == false'
jq '.mcp["paper-search"].command = ["/custom/uvx", "paper-search-mcp"]' "$CONFIG_FILE" > "${TEST_ROOT}/paper-custom"
cp "${TEST_ROOT}/paper-custom" "$CONFIG_FILE"
main_run --paper-search-mcp
check '.mcp["paper-search"].enabled == true and .mcp["paper-search"].command == ["/custom/uvx", "paper-search-mcp"]'
check_output
printf 'PASS: main setup preserves configuration, backs up changes, and disables MCPs\n'
main_run --playwright-mcp --paper-search-mcp
check '.mcp.playwright.enabled == true and .mcp["paper-search"].enabled == true'
cp "$CONFIG_FILE" "${TEST_ROOT}/before-cli-migration"
main_run --playwright --paper-search
jq -e --slurpfile previous "${TEST_ROOT}/before-cli-migration" '
    .mcp.playwright == ($previous[0].mcp.playwright | .enabled = false)
    and .mcp["paper-search"] == ($previous[0].mcp["paper-search"] | .enabled = false)
' "$CONFIG_FILE" >/dev/null
for skill in playwright-cli paper-search; do
    [[ -f "${isolated_home}/.config/opencode/skills/${skill}/SKILL.md" ]]
done
cli_config="${isolated_home}/.config/opencode/tools/playwright/cli.config.json"
jq -e '.browser.browserName == "chromium" and .browser.launchOptions.headless == true and .browser.launchOptions.chromiumSandbox == false' "$cli_config" >/dev/null
printf '{"browser":{"launchOptions":{"headless":false}}}\n' > "$cli_config"
main_run --playwright --paper-search
jq -e '.browser.launchOptions.headless == false' "$cli_config" >/dev/null
main_run --no-playwright --no-paper-search
for skill in playwright-cli paper-search; do
    [[ ! -f "${isolated_home}/.config/opencode/skills/${skill}/SKILL.md" ]]
done
check '.mcp.playwright.enabled == false and .mcp["paper-search"].enabled == false'
main_run --playwright-mcp --paper-search-mcp
check '.mcp.playwright.enabled == true and .mcp["paper-search"].enabled == true'
printf 'PASS: CLI migration, custom MCP preservation, launch config preservation, disable and MCP fallback\n'
# A failed CLI install must not disable the still-working MCP configuration.
cp "$CONFIG_FILE" "${TEST_ROOT}/before-cli-failure"
printf '#!/bin/bash\nexit 1\n' > "${TEST_ROOT}/bin/uvx"
if main_run --paper-search --no-playwright; then exit 1; fi
cmp -s "$CONFIG_FILE" "${TEST_ROOT}/before-cli-failure"
printf '#!/bin/bash\nexit 0\n' > "${TEST_ROOT}/bin/uvx"
for pair in 'playwright playwright-mcp' 'paper-search paper-search-mcp'; do
    read -r cli_flag mcp_flag <<< "$pair"
    if main_run "--$cli_flag" "--$mcp_flag"; then exit 1; fi
    if main_run --all "--$mcp_flag"; then exit 1; fi
done
printf 'PASS: failed CLI installation preserves MCP config; conflicting modes rejected\n'

# The installed launcher preserves argument boundaries and respects project and
# explicit configuration overrides, including config paths containing spaces.
main_run --playwright --no-paper-search
launcher="${isolated_home}/.config/opencode/skills/playwright-cli/scripts/run.sh"
cli_binary="${isolated_home}/.config/opencode/tools/playwright/node_modules/.bin/playwright-cli"
cat > "$cli_binary" <<'EOF'
#!/bin/bash
printf '%s\n' "$@"
EOF
mkdir -p "${TEST_ROOT}/browser project/.playwright"
(
    cd "${TEST_ROOT}/browser project"
    bash "$launcher" -s=own-session open 'https://example.invalid/a b' > "${TEST_ROOT}/launch-args"
    expected_config="${isolated_home}/.config/opencode/tools/playwright/cli.config.json"
    printf '%s\n' --config "$expected_config" -s=own-session open 'https://example.invalid/a b' > "${TEST_ROOT}/expected-args"
    cmp -s "${TEST_ROOT}/launch-args" "${TEST_ROOT}/expected-args"
    bash "$launcher" -s=own-session run-code 'async page => page.title()' > "${TEST_ROOT}/launch-args"
    printf '%s\n' -s=own-session run-code 'async page => page.title()' > "${TEST_ROOT}/expected-args"
    cmp -s "${TEST_ROOT}/launch-args" "${TEST_ROOT}/expected-args"
    bash "$launcher" --config 'custom config.json' open > "${TEST_ROOT}/launch-args"
    printf '%s\n' --config 'custom config.json' open > "${TEST_ROOT}/expected-args"
    cmp -s "${TEST_ROOT}/launch-args" "${TEST_ROOT}/expected-args"
    printf '{}' > .playwright/cli.config.json
    bash "$launcher" open > "${TEST_ROOT}/launch-args"
    [[ "$(cat "${TEST_ROOT}/launch-args")" == open ]]
)
printf 'PASS: launcher default config, explicit override, project override and quoting\n'



# Any attempted installer or registry access must fail the preview test.
for command in npm npx curl uvx; do
    printf '#!/bin/bash\ntouch "%s"\nexit 99\n' "${TEST_ROOT}/network-called" > "${TEST_ROOT}/bin/${command}"
    chmod +x "${TEST_ROOT}/bin/${command}"
done
mkdir -p "${isolated_home}/.cache/opencode/packages/opencode-plugin-litellm@old"
printf sentinel > "${isolated_home}/.cache/opencode/packages/opencode-plugin-litellm@old/data"
cp "$CONFIG_FILE" "${TEST_ROOT}/before-dry-run"
main_run --dry-run --install --playwright-mcp --lsp --context7
cmp -s "$CONFIG_FILE" "${TEST_ROOT}/before-dry-run"
[[ -f "${isolated_home}/.cache/opencode/packages/opencode-plugin-litellm@old/data" ]]
[[ ! -e "${isolated_home}/.bashrc" && ! -e "${TEST_ROOT}/network-called" ]]
check_output
main_run --dry-run --uninstall
cmp -s "$CONFIG_FILE" "${TEST_ROOT}/before-dry-run"
isolated_home="${TEST_ROOT}/fresh-preview"
main_run --dry-run --all
[[ ! -e "$isolated_home" && ! -e "${TEST_ROOT}/network-called" ]]
check_output
printf 'PASS: install/uninstall previews preserve files and never call the network\n'

for feature in playwright paper-search lsp context7 pdf-mcp playwright-mcp litellm-mcp extension roundtable openagent paper-search-mcp; do
    if main_run "--$feature" "--no-$feature"; then exit 1; fi
    if main_run --all "--no-$feature"; then exit 1; fi
    if main_run "--no-$feature" --all; then exit 1; fi
done
if main_run --all --uninstall; then exit 1; fi
for flag in --key --base-url --omo-model --unknown; do
    if main_run "$flag"; then exit 1; fi
done
if main_run --install --uninstall; then exit 1; fi
if main_run --key ''; then exit 1; fi
if main_run --base-url ''; then exit 1; fi
main_run --help
for missing in key url; do
    test_key=sk-test-only
    test_url=https://example.invalid/v1
    [[ "$missing" != key ]] || test_key=''
    [[ "$missing" != url ]] || test_url=''
    if env HOME="$isolated_home" PATH="${TEST_ROOT}/bin:${PATH}" \
        LITELLM_API_KEY="$test_key" LITELLM_BASE_URL="$test_url" \
        bash "${SCRIPT_DIR}/setup-opencode.sh" --dry-run > "${TEST_ROOT}/output" 2>&1; then
        exit 1
    fi
done
[[ ! -e "$isolated_home" && ! -e "${TEST_ROOT}/network-called" ]]
printf 'PASS: main argument errors fail cleanly before changes\n'

isolated_home="${TEST_ROOT}/invalid-main"
CONFIG_FILE="${isolated_home}/.config/opencode/opencode.json"
mkdir -p "$(dirname "$CONFIG_FILE")"
for contents in 'null' '[]' '{} {}' '{"plugin":false}' '{"agent":false}' '{"agent":{"build":[]}}' '{"agent":{"plan":false}}' '{"provider":{"litellm":{"options":false}}}' '{"apiKey":"sk-test-only",'; do
    printf '%s' "$contents" > "$CONFIG_FILE"
    if main_run --install; then exit 1; fi
    [[ "$(cat "$CONFIG_FILE")" == "$contents" ]]
    check_output
done
printf '{}' > "$CONFIG_FILE"
printf '// personal config' > "${CONFIG_FILE}c"
if main_run --install; then exit 1; fi
[[ ! -e "${TEST_ROOT}/network-called" ]]
printf 'PASS: main setup rejects malformed JSON and JSONC before installation\n'

# Restore harmless command mocks for default setup and real PTY menu tests.
printf '#!/bin/bash\nexit 0\n' > "${TEST_ROOT}/bin/uvx"
install_npm_mock 0.8.0
printf '#!/bin/bash\nexit 0\n' > "${TEST_ROOT}/bin/npx"
printf '#!/bin/bash\nexit 0\n' > "${TEST_ROOT}/bin/curl"
isolated_home="${TEST_ROOT}/all-defaults"
main_run
CONFIG_FILE="${isolated_home}/.config/opencode/opencode.json"
check '.lsp.just == {command: ["just-lsp"], extensions: [".just", ".justfile"]} and ([.mcp.context7, .mcp["pdf-reader"], .mcp["litellm-tools"]] | all(.enabled == true))'
[[ -f "${isolated_home}/.config/opencode/AGENTS.md" ]]
check '(.plugin | index("opencode-roundtable@0.8.0")) != null'
check '(.mcp.playwright.enabled // false) == false and (.mcp["paper-search"].enabled // false) == false'
[[ -f "${isolated_home}/.config/opencode/skills/playwright-cli/SKILL.md" ]]
[[ -f "${isolated_home}/.config/opencode/skills/paper-search/SKILL.md" ]]
printf 'PASS: unattended setup enables CLI skills and every other add-on\n'

check '.mcp["pdf-reader"].command == ["npx", "-y", "@sylphx/pdf-reader-mcp@4.1.3"]'
jq '.mcp["pdf-reader"].command[-1] = "@sylphx/pdf-reader-mcp@latest"
    | .mcp["pdf-reader"].timeout = 45000' "$CONFIG_FILE" > "${TEST_ROOT}/pdf-legacy"
cp "${TEST_ROOT}/pdf-legacy" "$CONFIG_FILE"
main_run --pdf-mcp
check '.mcp["pdf-reader"].command == ["npx", "-y", "@sylphx/pdf-reader-mcp@4.1.3"] and .mcp["pdf-reader"].timeout == 45000'
jq '.mcp["pdf-reader"].command = ["/custom/pdf-reader"]' "$CONFIG_FILE" > "${TEST_ROOT}/pdf-custom"
cp "${TEST_ROOT}/pdf-custom" "$CONFIG_FILE"
main_run --pdf-mcp
check '.mcp["pdf-reader"].command == ["/custom/pdf-reader"]'
printf 'PASS: PDF MCP version pinned, legacy default migrated, and custom command preserved\n'

command -v script >/dev/null
printf -v menu_command '%q ' env HOME="$isolated_home" PATH="${TEST_ROOT}/bin:${PATH}" \
    LITELLM_API_KEY=sk-test-only LITELLM_BASE_URL=https://example.invalid/v1 \
    bash "${SCRIPT_DIR}/setup-opencode.sh"
# Toggle all nine entries off in a real pseudo-terminal.
{ sleep 1; printf ' \033[B \033[B \033[B \033[B \033[B \033[B \033[B \033[B \n'; } |
    script -q -e -c "$menu_command" /dev/null > "${TEST_ROOT}/output" 2>&1
check '.lsp == false and ([.mcp.context7, .mcp["pdf-reader"], .mcp["litellm-tools"]] | all(.enabled == false))'
check '(.mcp["paper-search"].enabled // false) == false'
check 'all(.plugin[]; startswith("opencode-roundtable") | not)'
[[ ! -f "${isolated_home}/.config/opencode/skills/playwright-cli/SKILL.md" ]]
[[ ! -f "${isolated_home}/.config/opencode/skills/paper-search/SKILL.md" ]]
# Accept every preselected entry: CLI skills and remaining MCPs become enabled.
{ sleep 1; printf '\n'; } |
    script -q -e -c "$menu_command" /dev/null > "${TEST_ROOT}/output" 2>&1
check '.lsp.just == {command: ["just-lsp"], extensions: [".just", ".justfile"]} and ([.mcp.context7, .mcp["pdf-reader"], .mcp["litellm-tools"]] | all(.enabled == true))'
check '(.plugin | index("opencode-roundtable@0.8.0")) != null'
check '(.mcp["paper-search"].enabled // false) == false'
check_output
[[ -f "${isolated_home}/.config/opencode/skills/playwright-cli/SKILL.md" ]]
[[ -f "${isolated_home}/.config/opencode/skills/paper-search/SKILL.md" ]]
check '(.mcp.playwright.enabled // false) == false'
printf 'PASS: real menu deselects and re-enables existing integrations\n'

# Updating pins must replace old entries, preserve unrelated plugins, and keep
# Roundtable enabled on subsequent unattended runs without an explicit flag.
main_run --roundtable
check '([.plugin[] | select(startswith("opencode-roundtable@"))] == ["opencode-roundtable@0.8.0"])'
install_npm_mock 0.9.0
main_run
check '([.plugin[] | select(startswith("opencode-roundtable@"))] == ["opencode-roundtable@0.9.0"])'
check '([.plugin[] | select(startswith("opencode-plugin-litellm@"))] == ["opencode-plugin-litellm@0.9.0"])'
main_run --no-roundtable
check 'all(.plugin[]; startswith("opencode-roundtable") | not)'
printf 'PASS: Roundtable enable, update, retention, and removal\n'

cp "$CONFIG_FILE" "${TEST_ROOT}/before-roundtable-modes"
jq '.disabled_providers = ["custom-provider"] | .plugin += [["custom-plugin@1.0.0", {setting: true}]]' \
    "$CONFIG_FILE" > "${TEST_ROOT}/mode-fixture"
cp "${TEST_ROOT}/mode-fixture" "$CONFIG_FILE"
for mode in light standard heavy free; do
    main_run --roundtable-mode "$mode"
    check "([.plugin[] | select(type == \"array\") | select(.[0] | startswith(\"opencode-roundtable@\"))] == [[\"opencode-roundtable@0.9.0\", {mode: \"$mode\"}]])"
    check '.disabled_providers == ["custom-provider", "opencode"]'
    check 'any(.plugin[]; . == ["custom-plugin@1.0.0", {setting: true}])'
done
jq '(.plugin[] | select(type == "array") | select(.[0] | startswith("opencode-roundtable@")) | .[1]).maxRounds = 9' \
    "$CONFIG_FILE" > "${TEST_ROOT}/custom-roundtable"
cp "${TEST_ROOT}/custom-roundtable" "$CONFIG_FILE"
main_run
check 'any(.plugin[]; . == ["opencode-roundtable@0.9.0", {mode: "free", maxRounds: 9}])'
main_run --roundtable-mode light
check 'any(.plugin[]; . == ["opencode-roundtable@0.9.0", {mode: "light", maxRounds: 9}])'
cp "$CONFIG_FILE" "${TEST_ROOT}/before-invalid-mode"
for args in '--roundtable-mode invalid' '--roundtable-mode' '--no-roundtable --roundtable-mode free' '--roundtable-mode free --no-roundtable' '--roundtable-mode light --roundtable-mode heavy'; do
    read -r -a invalid_flags <<< "$args"
    if main_run "${invalid_flags[@]}"; then exit 1; fi
    cmp -s "$CONFIG_FILE" "${TEST_ROOT}/before-invalid-mode"
done
main_run --dry-run --all --roundtable-mode heavy
cmp -s "$CONFIG_FILE" "${TEST_ROOT}/before-invalid-mode"
grep -q 'Roundtable mode: heavy' "${TEST_ROOT}/output"
main_run --no-roundtable
check 'all(.plugin[]; (if type == "array" then .[0] else . end) | startswith("opencode-roundtable") | not)'
cp "${TEST_ROOT}/before-roundtable-modes" "$CONFIG_FILE"
printf 'PASS: Zen disabled; Roundtable modes, tuple preservation, reruns, dry-run, and invalid flags\n'

main_run --openagent --omo-model litellm/test-model
check '([.plugin[] | select(startswith("oh-my-openagent@"))] == ["oh-my-openagent@4.19.4"])'
omo_config="${isolated_home}/.omo/omo.json"
jq -e '."[opencode]" | (.goal.enabled == false) and (.goal.auto_start == false)
    and (.team_mode.enabled == true) and .background_task.defaultConcurrency == 3
    and (.codegraph.enabled == true) and (.codegraph.auto_provision == true)
    and (.telemetry == false) and (.codegraph.telemetry == false)
    and .agents.sisyphus.model == "litellm/test-model"
    and .agents.explore.model == "litellm/test-model"
    and .categories.quick.model == "litellm/test-model"' "$omo_config" >/dev/null
jq '."[opencode]".goal.enabled = false | ."[opencode]".background_task.defaultConcurrency = 2
    | ."[opencode]".codegraph = {enabled: false, auto_provision: false, telemetry: false}
    | ."[opencode]".agents.sisyphus.model = "litellm/custom-main"
    | ."[opencode]".agents.sisyphus.temperature = 0.2
    | ."[opencode]".agents.custom = {model: "litellm/custom-role"}
    | ."[opencode]".categories.custom = {model: "litellm/custom-category"}' \
    "$omo_config" > "${TEST_ROOT}/omo-custom"
cp "${TEST_ROOT}/omo-custom" "$omo_config"
cp "$omo_config" "${TEST_ROOT}/omo-before"
main_run --openagent
cmp -s "$omo_config" "${TEST_ROOT}/omo-before"
switch_model=litellm/deepseek-ai/DeepSeek-V4-Flash-0731
main_run --dry-run --all --omo-model "$switch_model"
cmp -s "$omo_config" "${TEST_ROOT}/omo-before"
mkdir -p "${isolated_home}/.opencode/bin"
printf '#!/bin/bash\necho test\n' > "${isolated_home}/.opencode/bin/opencode"
chmod +x "${isolated_home}/.opencode/bin/opencode"
main_run --install --extension --all --omo-model "$switch_model"
jq -e --arg model "$switch_model" --slurpfile before "${TEST_ROOT}/omo-before" '
    ."[opencode]" as $config
    | ($config.agents | del(.custom) | length == 11)
    and ($config.categories | del(.custom) | length == 8)
    and ($config.agents | del(.custom) | all(.[]; .model == $model))
    and ($config.categories | del(.custom) | all(.[]; .model == $model))
    and (del(."[opencode]".agents[].model, ."[opencode]".categories[].model)
        == ($before[0] | del(."[opencode]".agents[].model, ."[opencode]".categories[].model)))
    and $config.agents.custom.model == "litellm/custom-role"
    and $config.categories.custom.model == "litellm/custom-category"
' "$omo_config" >/dev/null
cp "$omo_config" "${TEST_ROOT}/omo-before"
main_run --openagent --omo-model "$switch_model"
cmp -s "$omo_config" "${TEST_ROOT}/omo-before"
main_run --no-openagent
check 'all(.plugin[]; startswith("oh-my-openagent") | not)'
cmp -s "$omo_config" "${TEST_ROOT}/omo-before"
# An existing JSONC config is never shadowed or overwritten.
mv "$omo_config" "${omo_config}c"
if main_run --openagent; then exit 1; fi
[[ ! -e "$omo_config" ]]
cmp -s "${omo_config}c" "${TEST_ROOT}/omo-before"
mv "${omo_config}c" "$omo_config"
cp "$CONFIG_FILE" "${TEST_ROOT}/before-invalid-omo"
printf '[]' > "$omo_config"
if main_run --openagent; then exit 1; fi
cmp -s "$CONFIG_FILE" "${TEST_ROOT}/before-invalid-omo"
cp "${TEST_ROOT}/omo-before" "$omo_config"
printf 'PASS: OpenAgent configuration, repeat installation, models, disable, and JSONC preservation\n'

# An explicit telemetry opt-in must be disabled on rerun, including CodeGraph.
jq '."[opencode]".telemetry = true | ."[opencode]".codegraph.telemetry = true' \
    "$omo_config" > "${TEST_ROOT}/omo-telemetry"
cp "${TEST_ROOT}/omo-telemetry" "$omo_config"
main_run --dry-run --openagent
cmp -s "$omo_config" "${TEST_ROOT}/omo-telemetry"
main_run --openagent
jq -e --arg model "$switch_model" '."[opencode]" | .telemetry == false and .codegraph.telemetry == false
    and .codegraph.enabled == false and .agents.sisyphus.model == $model' \
    "$omo_config" >/dev/null
cp "$omo_config" "${TEST_ROOT}/omo-telemetry-disabled"
main_run --openagent
cmp -s "$omo_config" "${TEST_ROOT}/omo-telemetry-disabled"
printf 'PASS: telemetry opt-ins disabled, preview unchanged, and rerun idempotent\n'

# Migrate previously enabled goal configurations while keeping explicit models.
jq '."[opencode]".goal.enabled = true' "$omo_config" > "${TEST_ROOT}/omo-old-goal"
cp "${TEST_ROOT}/omo-old-goal" "$omo_config"
main_run --openagent
jq -e --arg model "$switch_model" '."[opencode]".goal.enabled == false and ."[opencode]".agents.sisyphus.model == $model' "$omo_config" >/dev/null
[[ -n "$(find "${isolated_home}/.omo" -name 'omo.json.backup.*' -print -quit)" ]]
# A fresh generic setup must not create model assignments without explicit input.
env HOME="${TEST_ROOT}/generic-omo" OMO_MODEL='' bash "${SCRIPT_DIR}/setup-openagent.sh" > "${TEST_ROOT}/output" 2>&1
jq -e '."[opencode]" | (has("agents") | not) and (has("categories") | not) and (.goal.enabled == false)' \
    "${TEST_ROOT}/generic-omo/.omo/omo.json" >/dev/null
printf 'PASS: old goal default disabled and generic setup has no model assignments\n'

# Existing installations gain CodeGraph defaults without losing custom options.
jq '."[opencode]".codegraph = {daemon: false}' "$omo_config" > "${TEST_ROOT}/omo-codegraph"
cp "${TEST_ROOT}/omo-codegraph" "$omo_config"
main_run --openagent
jq -e '."[opencode]".codegraph | .enabled == true and .auto_provision == true and .daemon == false' "$omo_config" >/dev/null
printf 'PASS: CodeGraph defaults added to existing configurations and explicit opt-outs preserved\n'

# Failed authentication must leave the existing config untouched and must never
# invoke an installer, npm, or npx.
cp "$CONFIG_FILE" "${TEST_ROOT}/before-auth-failure"
cat > "${TEST_ROOT}/bin/curl" <<'EOF'
#!/bin/bash
[[ "$*" != *opencode.ai/install* ]] || touch "$HOME/unexpected-install"
exit 22
EOF
if main_run --install --roundtable; then exit 1; fi
cmp -s "$CONFIG_FILE" "${TEST_ROOT}/before-auth-failure"
[[ ! -e "${isolated_home}/unexpected-install" ]]
check_output
printf 'PASS: proxy rejection aborts before configuration or installation\n'

# A signal during the proxy check must remove the credential header file.
cat > "${TEST_ROOT}/bin/curl" <<'EOF'
#!/bin/bash
for argument in "$@"; do
    if [[ "$argument" == @* ]]; then
        printf '%s' "${argument#@}" > "$HOME/auth-file-path"
    fi
done
kill -TERM "$PPID"
exit 0
EOF
if main_run; then exit 1; else [[ $? -eq 143 ]]; fi
[[ ! -e "$(cat "${isolated_home}/auth-file-path")" ]]
printf '#!/bin/bash\nexit 0\n' > "${TEST_ROOT}/bin/curl"
printf 'PASS: interrupted proxy check removes credential file\n'

# Save the terminal state around an interrupted menu in the same PTY.
# shellcheck disable=SC2016
printf -v interrupt_command 'trap : INT; before=$(stty -g); %s; result=$?; after=$(stty -g); test "$result" = 130 && test "$before" = "$after"' "$menu_command"
{ sleep 1; printf '\003'; } |
    script -q -e -c "$interrupt_command" /dev/null > "${TEST_ROOT}/output" 2>&1
printf 'PASS: interrupted menu restores terminal settings\n'

isolated_home="${TEST_ROOT}/shell-config"
mkdir -p "${isolated_home}/.opencode/bin"
printf '#!/bin/bash\necho test\n' > "${isolated_home}/.opencode/bin/opencode"
chmod +x "${isolated_home}/.opencode/bin/opencode"
cat > "${isolated_home}/.zshrc" <<'EOF'
# personal settings
export PATH="$HOME/.opencode/bin:$HOME/custom/bin:$PATH"
alias oc="$HOME/.opencode/bin/opencode"
EOF
cp "${isolated_home}/.zshrc" "${TEST_ROOT}/personal-zshrc"
# Return a fake installer that replaces an existing executable. All writes stay
# inside the isolated HOME; no real installer or network access is used.
cat > "${TEST_ROOT}/bin/curl" <<'EOF'
#!/bin/bash
if [[ "$*" == *opencode.ai/install* ]]; then
    cat <<'INSTALLER'
mkdir -p "$HOME/.opencode/bin"
printf '#!/bin/bash\necho updated\n' > "$HOME/.opencode/bin/opencode"
chmod +x "$HOME/.opencode/bin/opencode"
echo called >> "$HOME/installer-calls"
INSTALLER
fi
EOF
main_run --install --roundtable
main_run --install
[[ "$(wc -l < "${isolated_home}/installer-calls")" -eq 2 ]]
[[ "$("${isolated_home}/.opencode/bin/opencode" --version)" == updated ]]
CONFIG_FILE="${isolated_home}/.config/opencode/opencode.json"
check '([.plugin[] | select(startswith("opencode-roundtable@"))] | length) == 1'
printf 'PASS: repeated installation updates the binary without uninstalling\n'
# A real terminal with no input must not open the menu under --all.
printf -v all_command '%q ' env HOME="$isolated_home" PATH="${TEST_ROOT}/bin:${PATH}" \
    LITELLM_API_KEY=sk-test-only LITELLM_BASE_URL=https://example.invalid/v1 \
    bash "${SCRIPT_DIR}/setup-opencode.sh" --all
timeout 20s script -q -e -c "$all_command" /dev/null </dev/null > "${TEST_ROOT}/output" 2>&1
if grep -q 'Optional Add-ons' "${TEST_ROOT}/output"; then exit 1; fi
[[ "$(wc -l < "${isolated_home}/installer-calls")" -eq 3 ]]
check '.lsp.just.command == ["just-lsp"] and ([.mcp.context7, .mcp["pdf-reader"], .mcp["litellm-tools"]] | all(.enabled == true))'
check '(.plugin | index("opencode-roundtable@0.9.0")) != null'
[[ -f "${isolated_home}/.config/opencode/AGENTS.md" ]]
printf 'PASS: --all installs and enables every add-on without a terminal prompt\n'
grep -q '^# BEGIN devcontainer opencode$' "${isolated_home}/.zshrc"
main_run --uninstall
cmp -s <(sed '/^$/d' "${isolated_home}/.zshrc") "${TEST_ROOT}/personal-zshrc"
printf 'PASS: uninstall preserves custom PATH entries and aliases\n'

# Mock shell lookup and account changes; this test only verifies configuration sync.
mkdir -p "${isolated_home}/.oh-my-zsh/custom/plugins/"{zsh-autosuggestions,zsh-syntax-highlighting}
printf '#!/bin/sh\nexit 0\n' > "${TEST_ROOT}/bin/zsh"
printf '#!/bin/sh\nexit 0\n' > "${TEST_ROOT}/bin/usermod"
# Evaluate the shell path when the mock runs in the isolated environment.
# shellcheck disable=SC2016
printf '#!/bin/sh\nprintf "test:x:1:1::/tmp:%%s\\n" "$(command -v zsh)"\n' > "${TEST_ROOT}/bin/getent"
chmod +x "${TEST_ROOT}/bin/"*
for _ in 1 2; do
    env HOME="$isolated_home" PATH="${TEST_ROOT}/bin:${PATH}" ZSH_CUSTOM="${isolated_home}/.oh-my-zsh/custom" \
        ZSHRC_SOURCE="${SCRIPT_DIR}/.zshrc" sh "${SCRIPT_DIR}/setup-zsh.sh" > "${TEST_ROOT}/output" 2>&1
done
backups=("${isolated_home}"/.zshrc.backup.*)
[[ ${#backups[@]} -eq 1 ]]
cmp -s <(sed '/^$/d' "${backups[0]}") "${TEST_ROOT}/personal-zshrc"
[[ "$(stat -c %a "${backups[0]}")" == 600 ]]
printf 'PASS: Zsh replacement keeps a private backup without duplicates\n'
