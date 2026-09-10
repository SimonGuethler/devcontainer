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
| Playwright | Headless Chromium browser automation | `--no-playwright-mcp` |
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
- Use `--all` to install/update OpenCode and enable every add-on without prompts. It cannot be combined with `--no-*` or `--uninstall`; credentials are still required. For example, with `LITELLM_API_KEY` and `LITELLM_BASE_URL` set:

  ```sh
  bash /workspace/.devcontainer/setup-opencode.sh --all
  ```

- Repeat the installation command with `--install` to update OpenCode and refresh plugin pins without uninstalling. The official installer skips the binary download if the current release is already installed. Restart OpenCode afterward.
- Setup checks the proxy connection and API key before installation or configuration changes; a failed check aborts setup.
- Setup uses `opencode-plugin-litellm` for model discovery and metadata from `/v1/models` and `/v1/model/info`.
- Standard API-key proxies are the intended setup. Custom authentication, certificates, or gateway routes may need manual configuration.
- `localhost` refers to the container; use an address reachable from inside it.

## Advanced configuration

### Oh My OpenAgent

Setup registers a pinned `oh-my-openagent` plugin (minimum 4.19.4). OpenCode downloads it on startup; no separate provider login or upstream interactive installer is run.

CodeGraph defaults to enabled with automatic provisioning (`[opencode].codegraph.enabled` and `auto_provision` are `true`). OpenAgent downloads its managed CodeGraph binary and initializes the project index at session start; the Dockerfile already provides Node.js 24. The initial download requires network access. If the MCP still shows disabled after provisioning, restart OpenCode so it can detect the binary. Unsupported runtimes, excluded project paths, or failed downloads can leave CodeGraph unavailable without blocking the other agents. Existing explicit CodeGraph settings and disable lists are preserved; set `codegraph.enabled` to `false` to opt out. For manually managed `omo.jsonc`, add these settings inside `[opencode]` yourself.

Restart OpenCode, select Sisyphus, and describe your objective and acceptance criteria in normal chat. Setup disables the faulty Goal hook: OpenAgent 4.19.4 can interpret ordinary messages or expanded commands as objectives and reject them above 2000 characters. Reruns also change an existing `[opencode].goal.enabled` to `false`, backing up the previous JSON configuration. This is a compatibility workaround, not an upstream code fix; dedicated `/goal` continuation is unavailable until a corrected release is verified. Agent orchestration remains available. New configurations default to at most three background tasks. Team Mode/worktrees remain off. Build and Plan remain available.

The workspace does not impose any model. Optional `--omo-model litellm/<model-id>` (or `OMO_MODEL`) fills missing agent/category model settings only when explicitly supplied. Existing individual assignments remain intact, including assignments from earlier setup runs. Without it, OpenAgent model selection uses upstream defaults and may require providers you have not configured; selecting a model in the UI does not necessarily configure every subagent. Edit individual assignments in `~/.omo/omo.json` under `[opencode].agents` and `[opencode].categories`.

The helper backs up changed `~/.omo/omo.json` files and preserves custom settings except for the Goal compatibility override. If `~/.omo/omo.jsonc` already exists, setup stops before installation/configuration changes: set `goal.enabled` to `false` manually inside its `[opencode]` object and manage that JSONC configuration manually. The duplicate built-in Context7 MCP is disabled in generated JSON; our existing Context7 option continues to control it. Local workspace-memory remains available.

`--no-openagent` removes the plugin registration, including the old `oh-my-opencode` package alias, while retaining its settings for reinstallation. The existing OpenCode uninstall also leaves `~/.omo` intact. Home-directory OpenAgent state is not persisted across container recreation; keep durable project notes in the mounted workspace.

Plugin loading and model execution with OpenCode 1.18.30 require a live smoke test; the setup regression suite uses simulated registry and installation commands.

### Other settings

| Detail | Behavior |
|--------|----------|
| OpenCode config | Written to `~/.config/opencode/opencode.json`; changed files are backed up |
| Existing settings | Models, other providers, and unrelated settings are preserved; selected add-ons can re-enable existing integrations |
| Agent colors | Setup supplies blue for Build and orange for Plan when no explicit color exists; custom colors are preserved. Rerun setup and restart OpenCode to apply. |
| Disable an integration | Use its `--no-*` flag or deselect it in the menu |
| JSONC config | Existing `opencode.jsonc` files must be edited manually |
| Local agent and skills | Includes a review agent plus verification, browser-check, and project-memory skills |
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
