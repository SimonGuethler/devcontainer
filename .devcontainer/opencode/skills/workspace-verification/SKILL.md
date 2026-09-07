---
name: workspace-verification
description: Discover and run a project's verification commands inside the GPU devcontainer when validating changes or diagnosing environment-related check failures.
---

# Verification in this container

The mounted `/workspace` contains separate repositories. Run checks from the
target repository, not the workspace root. Read its instructions and manifests
before choosing commands. Record the exact commands and exit codes.

- Python: `uv` is installed, but Python is project-managed. Follow `.python-version`,
  `pyproject.toml`, and lockfiles. Use the existing environment or documented
  `uv run` workflow. Do not install packages into system Python. Distinguish a
  missing interpreter/dependency from a failing test; do not rewrite the lockfile
  merely to run a check.
- JS/TS/Vue: Node and npm are available. Use the package manager selected by the
  project and scripts in `package.json`; never assume npm is the project's choice.
  VS Code extensions do not provide CLI typecheckers to OpenCode.
- Rust: rustc, cargo, clippy, rustfmt, and rust-analyzer are installed. Respect
  repository toolchain files and existing cargo aliases/check commands.
- Bash: `bash -n` checks parsing; `shellcheck` checks common shell mistakes.
  Neither validates runtime behavior. Exercise modified installers with dummy
  credentials and an isolated HOME, mocking network calls when appropriate.
- `just --list` can reveal existing recipes. Inspect a recipe before running it;
  a command called `check` is not a guarantee of harmless behavior.

Start with checks covering the change. Expand when failures or affected interfaces
justify it. For LSP problems, verify project root, interpreter, and installed
dependencies; use the project's CLI checks if diagnostics are stale.
