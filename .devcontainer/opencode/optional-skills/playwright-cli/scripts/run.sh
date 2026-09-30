#!/bin/bash
set -euo pipefail
CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CLI="${CONFIG_DIR}/tools/playwright/node_modules/.bin/playwright-cli"
[[ -x "$CLI" ]] || { echo 'Playwright CLI is not installed; run setup-opencode.sh --playwright.' >&2; exit 1; }
# A project config or explicit --config takes precedence over container defaults.
if [[ -f .playwright/cli.config.json ]]; then
    exec "$CLI" "$@"
fi
for argument in "$@"; do
    if [[ "$argument" == --config || "$argument" == --config=* ]]; then
        exec "$CLI" "$@"
    fi
done
# Configuration is an open option, not a global option for commands such as
# run-code, snapshot or close. Sessions retain their launch configuration.
for argument in "$@"; do
    case "$argument" in
        -*) continue ;;
        open) exec "$CLI" --config "${CONFIG_DIR}/tools/playwright/cli.config.json" "$@" ;;
        *) break ;;
    esac
done
exec "$CLI" "$@"
