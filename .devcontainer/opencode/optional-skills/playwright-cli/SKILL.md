---
name: playwright-cli
description: Automate browser interactions and inspect web pages through the devcontainer's Playwright CLI, including local frontend verification.
---

# Playwright CLI

Use the installed launcher through the shell (adjust the config root only if
OpenCode was installed elsewhere):

```bash
PW="$HOME/.config/opencode/skills/playwright-cli/scripts/run.sh"
bash "$PW" --help
bash "$PW" -s=task-name open http://localhost:3000
bash "$PW" -s=task-name snapshot
bash "$PW" -s=task-name click e3
bash "$PW" -s=task-name fill e5 "example"
bash "$PW" -s=task-name console error
bash "$PW" -s=task-name screenshot
bash "$PW" -s=task-name close
```

The launcher defaults to bundled Chromium, headless, with sandbox disabled for
the root devcontainer. A project's `.playwright/cli.config.json` or an explicit
`--config` overrides these defaults. Run from the project directory so snapshots
and screenshots remain associated with that project. Localhost is the container.

Use a unique named session per task and reuse it for all related commands. Read
the snapshot file only as needed; refs such as `e3` must come from the current
page snapshot. Use `--help` for additional commands and `run-code` when a sequence
needs Playwright APIs. Inspect the resulting state and console/network errors;
a screenshot alone does not verify an interaction. Close only your own session.

If the launcher is missing, report the missing integration. Do not run the setup
installer as an automatic verification step. MCP is an explicit alternative
(`--playwright-mcp`), not a second browser interface to use alongside the CLI.
