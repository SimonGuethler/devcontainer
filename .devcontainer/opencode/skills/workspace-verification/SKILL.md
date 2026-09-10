---
name: workspace-verification
description: Select and run relevant project checks in the devcontainer, identify regression coverage, and distinguish code failures from environment problems.
---

# Verification in this container

The mounted `/workspace` contains separate repositories. Run checks from the
target repository, not the workspace root. Read its instructions and manifests
before choosing commands. Record the exact commands and exit codes.

## Choose coverage

- Derive checks from the changed behavior and affected interfaces. Cover the
  expected result and relevant boundary or failure cases, not an exhaustive
  checklist unrelated to the change.
- For a bug fix, add a focused regression test when practical. Confirm it fails
  for the original defect and passes with the fix; disclose when the original
  failure could not be reproduced.
- Assert observable behavior and contracts rather than private implementation
  details. Reuse existing fixtures and test conventions; isolate external effects
  without mocking away the behavior being verified.
- Use the lowest-cost test level that exercises the risk. Add integration or
  end-to-end coverage when the failure depends on component interaction. Do not
  introduce a new test framework solely for a small change.

## Use the project environment

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
justify it; after relevant checks pass, repeat only for new changes or unresolved
concerns. Report coverage gaps and environment blockers separately from observed
failures. For LSP problems, verify project root, interpreter, and installed
dependencies; use the project's CLI checks if diagnostics are stale.
