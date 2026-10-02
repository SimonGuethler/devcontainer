# GPU Devcontainer

A reusable GPU development container for Python, JavaScript/TypeScript, Rust, and CUDA, with Zsh, VS Code tooling, and optional OpenCode setup for an existing LiteLLM proxy.

## Requirements

- Docker with Docker Compose support.
- An x86-64 host with an NVIDIA GPU configured for Docker.
- For OpenCode: a LiteLLM proxy URL reachable from the container and an API key. This repository does not deploy LiteLLM.

Without a GPU, remove `deploy.resources.reservations.devices` and the NVIDIA environment variables from [compose.yml](.devcontainer/compose.yml) before starting.

## Quick start

From this repository's root **on the host**, build and enter the container:

```sh
docker compose -f .devcontainer/compose.yml up --build -d
docker compose -f .devcontainer/compose.yml exec dev zsh
```

For VS Code, install the Dev Containers extension, open this repository, and run **Dev Containers: Reopen in Container**.

### Optional: OpenCode

Run **inside the container**, replacing the key and URL with your own values. Use the API base URL, typically ending in `/v1`, without a trailing slash. `localhost` refers to the container.

```sh
bash /workspace/.devcontainer/setup-opencode.sh --install --extension \
  --key 'your-api-key' --base-url 'https://your-proxy.example/v1'
source ~/.zshrc
```

Use **↑/↓** to navigate the add-on menu, **Space** to toggle, and **Enter** to confirm. All add-ons start selected, including Roundtable and Oh My OpenAgent. Deselect **LiteLLM MCP gateway** if your proxy does not provide it, or add `--no-litellm-mcp` to the command. Playwright downloads Chromium and its system dependencies.

Change to your project's directory, then run `opencode`. See the [configuration reference](docs/configuration.md#opencode-options) for add-ons, model assignments, unattended setup, and updates. For all flags:

```sh
bash /workspace/.devcontainer/setup-opencode.sh --help
```

## Daily use

The repository root is mounted at `/workspace`. Clone projects here on the host or inside the container, then work in `/workspace/your-project`. Nested projects keep their own Git repositories; the root `.gitignore` allows only devcontainer files and documentation.

Files in `/workspace` persist on the host. Home-directory settings, OpenCode credentials, and manually installed packages are lost when the container is recreated; rerun OpenCode setup afterward.

| Task | Command or action |
|------|-------------------|
| Re-enter the container | `docker compose -f .devcontainer/compose.yml exec dev zsh` |
| Rebuild after Dockerfile changes | `docker compose -f .devcontainer/compose.yml up --build -d` |
| Rebuild through VS Code | **Dev Containers: Rebuild Container** |
| Stop without removing | `docker compose -f .devcontainer/compose.yml stop dev` |
| Resume | `docker compose -f .devcontainer/compose.yml start dev` |
| Stop and remove | `docker compose -f .devcontainer/compose.yml down` |

Run Docker Compose commands from this repository's root **on the host**. The container stays running when VS Code closes and starts automatically when Docker starts, unless explicitly stopped. `start dev` resumes it and restores automatic startup. Enable Docker Desktop startup at sign-in if you want this after reboot.

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

## Reference

- [OpenCode add-ons and setup options](docs/configuration.md#opencode-options)
- [Roundtable modes](docs/configuration.md#roundtable-modes) and [Oh My OpenAgent](docs/configuration.md#oh-my-openagent)
- [Telemetry, local commands, and other settings](docs/configuration.md#other-settings)
- [Tool versions](docs/configuration.md#tool-versions), [repository files](docs/configuration.md#repository-files), and [validation commands](docs/configuration.md#validation)
