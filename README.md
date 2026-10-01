# GPU Devcontainer

A reusable GPU development container for Python, JavaScript/TypeScript, Rust, and CUDA, with Zsh, VS Code tooling, and optional OpenCode setup for an existing LiteLLM proxy.

## Requirements

- Docker with Docker Compose support.
- An x86-64 host with an NVIDIA GPU configured for Docker.
- For OpenCode: a LiteLLM proxy URL reachable from the container and an API key. This repository does not deploy LiteLLM.

Without a GPU, remove `deploy.resources.reservations.devices` and the NVIDIA environment variables from `.devcontainer/compose.yml` before starting.

## Quick start

Run steps **1–2 on the host**, from this repository's root directory. Run steps **3–5 inside the container**. OpenCode is optional; skip steps 3–5 if you only need the development tools.

### 1. Build and start

```sh
docker compose -f .devcontainer/compose.yml up --build -d
```

### 2. Enter the container

```sh
docker compose -f .devcontainer/compose.yml exec dev zsh
```

### 3. Install and configure OpenCode

Replace the API key and URL with your own values. Use the API base URL, typically ending in `/v1`, without a trailing slash.

```sh
bash /workspace/.devcontainer/setup-opencode.sh --install --extension \
  --key 'your-api-key' --base-url 'https://your-proxy.example/v1'
```

- Use **↑/↓** to navigate, **Space** to toggle add-ons, and **Enter** to confirm.
- All add-ons, including Roundtable, start selected. Unattended runs use the same defaults.
- Deselect **LiteLLM MCP gateway** if your proxy does not provide it, or add `--no-litellm-mcp` to the command.
- Playwright downloads Chromium and its system dependencies.

### 4. Refresh the shell

```sh
source ~/.zshrc
```

### 5. Start OpenCode

```sh
opencode
```

For project work, change to your project's directory before starting OpenCode.

## Workspace and daily use

| Task | Direction |
|------|-----------|
| Add a project | Clone it into this repository's root on the host, or into `/workspace` inside the container |
| Work on a project | Run `cd /workspace/your-project`, then your tools or `opencode` |
| Re-enter the container | Repeat step 2; installation is not needed again in the same container |
| Rebuild after Dockerfile changes | Repeat step 1 with `--build`, then repeat OpenCode setup if the container was recreated |
| Use VS Code | Install the Dev Containers extension, open this repository, and run **Dev Containers: Reopen in Container** |
| Rebuild through VS Code | Run **Dev Containers: Rebuild Container** |

- The repository root is mounted at `/workspace`; files there persist on the host.
- The root `.gitignore` allows only devcontainer files and documentation. Nested projects keep their own Git repositories.
- Home-directory settings, OpenCode credentials, and manually installed packages are not persisted separately; recreating the container discards them.

Stop and remove the container from the repository root **on the host**:

```sh
docker compose -f .devcontainer/compose.yml down
```

## OpenCode options

| Add-on | Purpose | Disable flag |
|--------|---------|--------------|
| LSP diagnostics | Language diagnostics; requires appropriate language servers and project dependencies | `--no-lsp` |
| Context7 | Documentation queries sent to an external service | `--no-context7` |
| LiteLLM MCP gateway | Tools exposed by your proxy at `/mcp`; requires gateway support and access | `--no-litellm-mcp` |
| PDF reader | PDF/document reading through MCP | `--no-pdf-mcp` |
| Paper Search | CLI + on-demand skill for academic search, PDF downloads and text; pinned to `paper-search-mcp==0.1.4` with `mcp<2`; basic use needs no API key | `--no-paper-search` |
| Playwright | CLI + on-demand skill for headless Chromium browser automation | `--no-playwright` |
| Coding guidelines | Installs the included `AGENTS.md` | `--no-extension` |
| Roundtable | Multi-agent debates across several rounds; increases token usage | `--no-roundtable` |
| Oh My OpenAgent | Orchestration and specialized background agents; selected by default | `--no-openagent` |

| Setting | Usage |
|---------|-------|
| API key | `LITELLM_API_KEY` or `--key`; a nonempty value is required |
| Proxy URL | `LITELLM_BASE_URL` or `--base-url`; no default proxy |
| Preview | Add `--dry-run`; no installation, network calls, configuration writes, or credential output |
| All flags | Run `bash /workspace/.devcontainer/setup-opencode.sh --help` |

- Explicit enable/disable flags skip the corresponding menu entries.
- Playwright and Paper Search default to CLI + skills, including under `--all`.
  Use `--playwright` / `--paper-search` to select them explicitly. Setup disables
  their old MCP entries while preserving commands and settings for later reuse.
  The skills appear in a new OpenCode session; no individual browser or paper
  MCP tool schemas are loaded in CLI mode.
- `--playwright-mcp` / `--paper-search-mcp` explicitly select the alternative MCP
  interface and disable the corresponding CLI skill. Do not combine these with
  `--all` or the corresponding CLI enable flag. The legacy `--no-*-mcp` flags
  remain aliases for disabling the whole integration. Installed CLI packages
  and customized launch configuration remain available for later re-enabling.
- Playwright installs privately under `~/.config/opencode/tools/playwright`.
  The CLI version is resolved on each setup run, and Chromium is installed using
  its matching Playwright dependency. The launcher defaults to Chromium,
  headless, with sandbox disabled for the root container. Project
  `.playwright/cli.config.json` and explicit `--config` take precedence; setup
  preserves edits to the private default configuration on reruns.
- Paper Search uses the cached `uvx --with 'mcp<2' --from paper-search-mcp==0.1.4
  paper-search` command. Optional credentials belong in shell environment
  variables or `~/.config/paper-search-mcp/.env`; credentials stored only in an
  OpenCode MCP `environment` entry must be configured there separately for CLI
  use. The CLI supports search, download, read and source listing, but version
  0.1.4 does not expose the MCP-only `download_with_fallback` operation. Select
  MCP explicitly when that operation is required.
- Use `--all` to install/update OpenCode and enable every add-on without prompts. It cannot be combined with `--no-*` or `--uninstall`; credentials are still required. For example, with `LITELLM_API_KEY` and `LITELLM_BASE_URL` set:

  ```sh
  bash /workspace/.devcontainer/setup-opencode.sh --all
  ```

- Repeat the installation command with `--install` to update OpenCode and refresh plugin pins without uninstalling. The official installer skips the binary download if the current release is already installed. Restart OpenCode afterward.
- Setup checks the proxy connection and API key before installation or configuration changes; a failed check aborts setup.
- Setup uses `opencode-plugin-litellm` for model discovery and metadata from `/v1/models` and `/v1/model/info`.
- Setup disables OpenCode Zen (`disabled_providers: ["opencode"]`), removing its
  models from the picker after restarting OpenCode. Existing disabled providers
  are retained; other providers are not disabled.
- Standard API-key proxies are the intended setup. Custom authentication, certificates, or gateway routes may need manual configuration.
- `localhost` refers to the container; use an address reachable from inside it.

## Advanced configuration

### Roundtable modes

All add-ons remain selected by default. Roundtable uses `standard` on first
setup; choose a different preset by adding `--roundtable-mode light`,
`--roundtable-mode standard`, `--roundtable-mode heavy`, or
`--roundtable-mode free` to your usual setup command. This flag enables Roundtable
and also works with `--all`, without adding another interactive prompt.

The presets allow up to 3, 5, or 7 rounds respectively. `free` hides the round
limit from participants and uses the plugin's internal safety cap (currently
12 rounds); it does not mean free API usage. Presets also tune thresholds,
timeouts, and retries. Debates can finish earlier.

An explicitly selected mode is stored as plugin options in the container's
`~/.config/opencode/opencode.json`. Reruns preserve these options unless another
mode is specified; `--no-roundtable` removes the registration and its options.
Plugin options require an OpenCode version supporting plugin tuples (use the
current version installed by `--install`). Restart OpenCode after setup.

### Oh My OpenAgent

Setup registers a pinned `oh-my-openagent` plugin (minimum 4.19.4). OpenCode downloads it on startup; no separate provider login or upstream interactive installer is run.

CodeGraph defaults to enabled with automatic provisioning (`[opencode].codegraph.enabled` and `auto_provision` are `true`). OpenAgent downloads its managed CodeGraph binary and initializes the project index at session start; the Dockerfile already provides Node.js 24. The initial download requires network access. If the MCP still shows disabled after provisioning, restart OpenCode so it can detect the binary. Unsupported runtimes, excluded project paths, or failed downloads can leave CodeGraph unavailable without blocking the other agents. Existing explicit CodeGraph settings and disable lists are preserved; set `codegraph.enabled` to `false` to opt out. For manually managed `omo.jsonc`, add these settings inside `[opencode]` yourself.

After running `setup-opencode.sh --openagent`, restart OpenCode and start a new session on Apollo. The primary-agent cycle is **Apollo → Sisyphus → Prometheus → Atlas → OpenCode-Builder → Apollo**. Setup sets `default_agent` to `apollo`, configures OMO's core order, and keeps Hephaestus and native Plan as subagents rather than cycle entries. OpenCode's native builder remains available as OpenCode-Builder. Rerunning setup reapplies this cycle; additional user-defined primary agents can still appear. Existing sessions or an explicit `--agent` selection can retain a different active agent.

Apollo's source is `.devcontainer/opencode/agents/apollo.md`. The image build and post-create harness install it into `~/.config/opencode/agents/apollo.md`, backing up a differing installed copy. Apollo provides analysis and review without implementation, writes Markdown plans or analysis documents at the requested or established project destination only when asked, and keeps temporary research artifacts under `<project-root>/.apollo/tmp/` (repository clones in `repos/`, downloads in `downloads/`, extracted text in `extracted/`, and working notes in `notes/`). After editing its source, rerun `bash /workspace/.devcontainer/setup-opencode-harness.sh` and restart OpenCode. The local harness installs the agent without changing provider settings; the main setup with `--openagent` configures startup and cycling.

Setup disables the faulty Goal hook: OpenAgent 4.19.4 can interpret ordinary messages or expanded commands as objectives and reject them above 2000 characters. Reruns also change an existing `[opencode].goal.enabled` to `false`, backing up the previous JSON configuration. This is a compatibility workaround, not an upstream code fix; dedicated `/goal` continuation is unavailable until a corrected release is verified. Agent orchestration remains available. New configurations default to at most three background tasks. Team Mode defaults to enabled; existing explicit settings are preserved. Worktrees and tmux visualization are optional and are not enabled by this setup.

The workspace does not impose any model. Optional `--omo-model litellm/<model-id>` (or `OMO_MODEL`) sets all built-in agent/category model assignments, replacing earlier assignments so rerunning setup can switch models. Other role settings and custom roles remain intact. Omit both the flag and environment variable to preserve existing model assignments. Without configured assignments, OpenAgent model selection uses upstream defaults and may require providers you have not configured; selecting a model in the UI does not necessarily configure every subagent. Restart OpenCode after switching models. Edit individual assignments in `~/.omo/omo.json` under `[opencode].agents` and `[opencode].categories`.

The helper backs up changed `~/.omo/omo.json` files and preserves custom settings except for the Goal compatibility override and enforced telemetry opt-out. If `~/.omo/omo.jsonc` already exists, setup stops before installation/configuration changes: set `goal.enabled` to `false` manually inside its `[opencode]` object and manage that JSONC configuration manually. The duplicate built-in Context7 MCP is disabled in generated JSON; our existing Context7 option continues to control it. Local workspace-memory remains available.

`--no-openagent` removes the plugin registration, including the old `oh-my-opencode` package alias, while retaining its settings for reinstallation. The existing OpenCode uninstall also leaves `~/.omo` intact. Home-directory OpenAgent state is not persisted across container recreation; keep durable project notes in the mounted workspace.

Plugin loading and model execution with OpenCode 1.18.30 require a live smoke test; the setup regression suite uses simulated registry and installation commands.

### Other settings

Telemetry is disabled through the image environment (`DO_NOT_TRACK=1`,
`OMO_DISABLE_POSTHOG=1`, `OMO_SEND_ANONYMOUS_TELEMETRY=0`,
`CODEGRAPH_TELEMETRY=0`, `OTEL_SDK_DISABLED=true`). OpenAgent setup also forces
`[opencode].telemetry` and `[opencode].codegraph.telemetry` to `false`, including
existing opt-ins. For manually managed JSONC, set these values yourself.
The VS Code devcontainer settings disable Microsoft and Red Hat telemetry;
keep `telemetry.telemetryLevel: "off"` in local VS Code user settings as well.
Rebuild the container to apply the image environment to all processes, and restart
OpenCode after changing its configuration. These opt-outs apply to tools that
honor them; they do not block model requests, MCP queries, or package downloads.

| Detail | Behavior |
|--------|----------|
| OpenCode config | Written to `~/.config/opencode/opencode.json`; changed files are backed up |
| Existing settings | Models, other providers, and unrelated settings are preserved; selected add-ons can re-enable existing integrations |
| Agent colors | Setup supplies blue for Build and orange for Plan when no explicit color exists; custom colors are preserved. Rerun setup and restart OpenCode to apply. |
| Disable an integration | Use its `--no-*` flag or deselect it in the menu |
| JSONC config | Existing `opencode.jsonc` files must be edited manually |
| Local agents and skills | Includes Apollo and workspace-review plus verification, browser-check, and project-memory skills |
| Zsh setup | Backs up a differing `.zshrc` before replacement; manages OpenCode PATH entries in marked blocks |

Change only LSP and Context7 settings without changing provider credentials:

```sh
bash /workspace/.devcontainer/setup-opencode-harness.sh --lsp --context7
```

For `just` diagnostics:

- `--lsp` registers `just-lsp` for `.just` and `.justfile`, preserving an existing `lsp.just` override.
- For an extensionless `justfile` or `Justfile`, add its absolute container path to `lsp.just.extensions` in `~/.config/opencode/opencode.json`, then restart OpenCode.

## Included tools

| Area | Tools |
|------|-------|
| GPU | Ubuntu-based NVIDIA CUDA development image with cuDNN |
| Python | `uv`, `uvx`, Pyright and its language server; Python environments are managed per project |
| JavaScript / TypeScript | Node.js 24 and npm |
| Rust | `rustc`, Cargo, Clippy, rustfmt, rust-analyzer |
| Build | C/C++ toolchain, Clang, CMake, `just`, `just-lsp` |
| Shell | Zsh, Oh My Zsh, autosuggestions, syntax highlighting, history search, fzf |
| Utilities | Git, Git LFS, ripgrep, fd, jq, SQLite CLI, ShellCheck, tmux, croc |
| VS Code | Python, notebooks, Vue, Rust, and configuration-file extensions; formatting defaults for Python, JavaScript, TypeScript, and Vue |

The `just`, `just-lsp`, and croc release archives are version-pinned and checked
against SHA-256 digests before extraction. Update each Dockerfile version and its
digest together. Node intentionally tracks the v24 release line, and Rust tracks
stable; fresh builds pick up toolchain fixes when those layers are rebuilt.
Projects can select a specific Rust toolchain with `rust-toolchain.toml`.
PDF MCP is pinned to `@sylphx/pdf-reader-mcp@4.1.3` so restarting it cannot silently
select a newer release. Rerunning setup with PDF enabled migrates the old workspace
`@latest` command while preserving custom commands.

## Repository files

| File | Purpose |
|------|---------|
| `.devcontainer/Dockerfile` | Base image, tool versions, and packages |
| `.devcontainer/compose.yml` | Container service, workspace mount, GPU access, and shared memory |
| `.devcontainer/devcontainer.json` | VS Code extensions, settings, and creation hooks |
| `.devcontainer/.zshrc` | Shell theme and plugins |
| `.devcontainer/setup-zsh.sh` | Shell setup and configuration sync |
| `.devcontainer/setup-opencode.sh` | OpenCode installation and LiteLLM configuration |
| `.devcontainer/setup-opencode-harness.sh` | Local agent, skills, and LSP/Context7 configuration |
| `.devcontainer/AGENTS.md` | Coding guidelines for optional OpenCode setup |

## Validation

Run inside the container, from `/workspace`, after changing setup scripts:

```sh
bash .devcontainer/test-opencode-harness.sh
bash -n .devcontainer/setup-opencode.sh
sh -n .devcontainer/setup-zsh.sh
git diff --check
```
