# Configuration and maintenance reference

[Back to the README](../README.md)

Detailed settings and maintenance notes for the GPU devcontainer:

- [OpenCode options](#opencode-options)
- [Advanced configuration](#advanced-configuration): Roundtable, OpenAgent, telemetry, and local commands
- [Tool versions](#tool-versions)
- [Repository files](#repository-files)
- [Validation](#validation)

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

Apollo keeps the configuration ID `apollo-analyzer`. Setup writes `agents["apollo-analyzer"].displayName = "Apollo - Analyzer"` inside `[opencode]` in `~/.omo/omo.json`; OpenAgent maps both the agent registration and `default_agent` to that display name at runtime. Model settings remain under `agent["apollo-analyzer"]` in OpenCode's configuration. Without OpenAgent, the Markdown agent uses its filename-derived name, `apollo-analyzer`. For an existing installation, run `bash /workspace/.devcontainer/setup-openagent.sh` and restart OpenCode to apply the display name. If you manage `omo.jsonc` manually, add the same `displayName` setting there.

Setup registers a pinned `oh-my-openagent` plugin (minimum 4.19.4). OpenCode downloads it on startup; no separate provider login or upstream interactive installer is run.

CodeGraph defaults to enabled with automatic provisioning (`[opencode].codegraph.enabled` and `auto_provision` are `true`). OpenAgent downloads its managed CodeGraph binary and initializes the project index at session start; the Dockerfile already provides Node.js 24. The initial download requires network access. If the MCP still shows disabled after provisioning, restart OpenCode so it can detect the binary. Unsupported runtimes, excluded project paths, or failed downloads can leave CodeGraph unavailable without blocking the other agents. Existing explicit CodeGraph settings and disable lists are preserved; set `codegraph.enabled` to `false` to opt out. For manually managed `omo.jsonc`, add these settings inside `[opencode]` yourself.

After running `setup-opencode.sh --openagent`, restart OpenCode and start a new session on Apollo - Analyzer. The primary-agent cycle is **Apollo - Analyzer → Sisyphus → Prometheus → Atlas → OpenCode-Builder → Apollo - Analyzer**. Setup sets `default_agent` to `apollo-analyzer`, configures OMO's core order, and keeps Hephaestus and native Plan as subagents rather than cycle entries. OpenCode's native builder remains available as OpenCode-Builder. Rerunning setup reapplies this cycle; additional user-defined primary agents can still appear. Existing sessions or an explicit `--agent` selection can retain a different active agent.

Apollo - Analyzer's source is `.devcontainer/opencode/agents/apollo-analyzer.md`. The image build and post-create harness install it into `~/.config/opencode/agents/apollo-analyzer.md`, backing up a differing installed copy. Apollo - Analyzer analyzes without edits by default, makes edits or implements changes only when explicitly requested, then returns to analysis. Tool permissions are unrestricted to avoid routine approval prompts. When authorized, it keeps temporary research artifacts under `<project-root>/.apollo/tmp/` (repository clones in `repos/`, downloads in `downloads/`, extracted text in `extracted/`, and working notes in `notes/`). After editing its source, rerun `bash /workspace/.devcontainer/setup-opencode-harness.sh` and restart OpenCode. The local harness installs the agent without changing provider settings; the main setup with `--openagent` configures startup and cycling.

Setup disables the faulty Goal hook: OpenAgent 4.19.4 can interpret ordinary messages or expanded commands as objectives and reject them above 2000 characters. Reruns also change an existing `[opencode].goal.enabled` to `false`, backing up the previous JSON configuration. This is a compatibility workaround, not an upstream code fix; dedicated `/goal` continuation is unavailable until a corrected release is verified. Agent orchestration remains available. New configurations default to at most three background tasks. Team Mode defaults to enabled; existing explicit settings are preserved. Worktrees and tmux visualization are optional and are not enabled by this setup.

The workspace does not impose any model. Optional `--omo-model litellm/<model-id>` (or `OMO_MODEL`) sets all built-in agent/category model assignments, replacing earlier assignments so rerunning setup can switch models. This includes OpenAgent 5.1.x's `deep-low` and `deep-high` lanes; legacy `deep` is retained for older supported releases. These model assignments also apply to Apollo - Analyzer, workspace-review, and native Build/Plan. Setup leaves existing variant and reasoning settings unchanged. Other role settings and custom roles remain intact. Omit a flag and its environment variable to preserve its existing assignments. Without configured assignments, OpenAgent model selection uses upstream defaults and may require providers you have not configured; selecting a model in the UI does not necessarily configure every subagent. Restart OpenCode after switching models. Edit individual assignments in `~/.omo/omo.json` under `[opencode].agents` and `[opencode].categories`.

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
| Local agents and skills | Includes Apollo - Analyzer and workspace-review plus verification, browser-check, project-memory, hyper-review, hyper-analyze, and hyper-research skills, and the `/brainstorm` command |
| Zsh setup | Backs up a differing `.zshrc` before replacement; manages OpenCode PATH entries in marked blocks |

Use `/hyper-review <target or review request>` to assess a concrete artifact or
bounded topic against its intended outcome: correctness, completeness, plan
alignment, and worthwhile improvements. Its report emphasizes prioritized findings
and verification gaps; specialist delegation is optional. The command loads the
`hyper-review` skill using the current agent. For example:
`/hyper-review Check this implementation against _project_plans/example.md and prioritize gaps and improvements`.
Without arguments, it uses the established conversation scope or asks for a target.
The workflow reports evidence, trade-offs, and verification limits; a review alone
does not request fixes. Rerun the harness installer and restart OpenCode after
changing the command file.

Use `/hyper-analyze <problem or decision>` to investigate the underlying problem,
assumptions, competing explanations, and viable alternatives, including retaining
the current approach when applicable. Its report emphasizes a reasoned recommendation,
trade-offs, critic findings, and what would change the conclusion. For example:
`/hyper-analyze Is the Kubernetes migration strategy appropriate for our constraints, and which alternatives or failure modes have we overlooked?`

The analysis uses at least
two independent critics across three required rounds: independent discovery,
cross-critique and deeper investigation, and a synthesis stress test. Targeted
rounds continue while material leads or investigable coverage gaps remain, with
explicit stopping criteria and reporting of incomplete rounds. It extends
`hyper-review`, uses the current agent, and selects
relevant perspectives such as architecture, implementation, requirements, or
research quality. Unlike `/hyper-review`, delegation is required when available
and permitted. If the active agent cannot delegate, it reports reduced coverage
and continues useful direct analysis without claiming a completed critic panel.
Both workflows recommend improvements without automatically implementing them.
Both respect explicit constraints and accepted decisions, revisiting them when
new evidence warrants it. Review may recommend analysis for a consequential open
question, but does not automatically escalate into the multi-round workflow.

Use `/hyper-research <topic or idea>` to gather comprehensive, verified
information on a topic and deliver a claim-evidence-backed synthesis. It
prioritizes sub-questions by impact and uncertainty, reads primary sources
matching the relevant versions after discovery, and cross-checks decisive
claims against independent sources. Only material accessed in the session is
cited; search snippets and abstracts never stand in for full content. Claims
are labeled as established findings, source claims, or inferences, and
unresolved conflicts are reported from both sides instead of being silently
resolved. For example:
`/hyper-research What is the current state of WebGPU adoption in game engines, and where do sources disagree?`

For consequential claims or an explicit request for high rigor, it uses an
independent verification panel when delegation is available and permitted.
Every decisive claim receives source-support and contrary-evidence checks;
failed or unavailable panel work is disclosed and checked directly where
possible. Follow-ups in a new session reopen supporting sources before reuse.
Credible secondary evidence is allowed with stated limits, and uncertainty is
quantified only when supported by data or a documented method.

The report leads with key findings, maps claims to sources with confidence,
and ranks open questions with the smallest next check for each. Unverified
gaps are named as such rather than filled. Research does not decide between
options or review artifacts; when the request turns into that, the workflow
recommends `/hyper-analyze` or `/hyper-review` instead. Rerun the harness
installer and restart OpenCode after changing the command or skill file.

Use `/brainstorm [light|medium|heavy] <topic>` to generate many diverse ideas
for a topic. Every level targets 7–10 useful ideas and 3–5 unconventional ideas,
deduplicated across both lists, without padding. Explicit constraints remain
binding; hypothetical ideas requiring a change are labeled outside current
constraints. The level is `medium` when omitted. `light` uses no tools; `medium`
uses one `chorus` pass capped at three rounds; `heavy` combines a survey of 3–5
sources with two passes capped at five and three rounds. Passes can finish early.
Unavailable or failed ideation tools fall back to direct ideation; heavy surveys
directly when delegation is unavailable or fails, and discloses missing grounding
when research cannot be completed. Heavy maps ideas to accessed sources and
distinguishes precedent from unverified extrapolation. Every level ends with
at most three useful decision questions. The command never implements, writes
files, or stress-tests ideas. Use `/hyper-analyze` for decision analysis and a
planning workflow (`/ulw-plan` when available) for a chosen idea. Rerun the harness
installer and restart OpenCode after changing the command file.

Use `/hyper-execute <goal | mission-path | plan-path>` to drive one goal to
evidence-verified completion. It first freezes a mission contract — acceptance
criteria, each with an evidence command or observation procedure, scope-out,
stop conditions, and a verification-round budget (3 by default) — in
`.omo/missions/<slug>/mission.md` and presents it for approval. After that
single gate (replacing duplicate plan approval) the run is continuous within its
limits: it plans through the ulw-plan workflow, validates supplied plans and review
provenance, executes through ulw-execute's worker waves with per-task reviews and capped
fix loops, then runs independent verification rounds on fresh subagents that
never see implementer reports (correctness, security for relevant behavior or
infrastructure/configuration changes, and QA) against a pinned candidate. A clean
round requires every criterion verified,
all required verifier coverage complete, passing QA, and no open confirmed serious
findings; high-stakes missions require two consecutive clean rounds on the same
candidate. Required capabilities are checked before starting. Outcomes are verified,
user-stopped, blocked, or budget-exhausted; every exit cancels mission-owned active
and queued work and records recovery state. It reports the evidence table,
deferred minors, and every ruling it made. Contract changes need explicit approval;
existing authorization is respected. This is deliberately the most expensive
command; starting or resuming requires the slash command. Ordinary messages may
steer or stop an active run. Security rounds use a standalone verifier rather
than loading the main-session-only `security-research` team skill; a full team audit
is conditional additional coverage. High-stakes mode and required coverage are
part of the approved contract, separate from mutable round/time/cost limits.
Exit handling pauses mission-owned Boulder work and cancels its continuation todos,
while retaining recovery state; successful verification marks that work completed.
The runtime reference documents OpenCode session IDs and source snapshots that
preserve contents, executable modes, symlinks, and pre-existing work without commits.
For plan-only requests use `/ulw-plan`; for analysis use `/hyper-analyze`.
Rerun the harness installer and restart OpenCode after changing the command
or skill files.

Use `/image-gen model=<image-model-id> <prompt>` to generate one image, or request
an edit with a local reference PNG and optional mask. This is a command only;
there is no keyword-triggered image skill. The command delegates to an installed
script, reads `provider.litellm.options.apiKey` and `baseURL` from the setup JSON,
and supplies no provider URL or default model. Edit capability must be verified
for the selected backend. The API paths are `/images/generations` and
`/images/edits`; edits use a file upload. An optional size is sent only when
requested; otherwise the backend chooses it. Output goes to a descriptive path
in the current project unless another destination is requested. Existing files
are never replaced. Only one base64 PNG is supported; its header and requested
dimensions are checked, without full image decoding. URL-only
responses, other formats, multiple outputs, JSONC, and provider-specific extras
are unsupported. Failed requests are not retried automatically.

Use `/video-analysis <url|@file.txt> [--out DIR] [--asr local|proxy] [--no-video]
[--keep-audio] [--frames N] [--lang auto] [--lang-report Deutsch] [--diarize]
[--whisper-model large-v2]` to analyze one or more YouTube videos: the command
downloads each video (≤720p mp4), transcribes locally with WhisperX (Silero VAD,
float16, word-level alignment; `--asr proxy` uses the proxy whisper endpoint as
fallback), extracts capped 1 fps frames, describes them with the multimodal chat
model, and writes a German markdown report plus `_index.md` per batch into
`video-analysis/` in the current project. Re-runs skip completed steps. The
first run after a container rebuild needs `video-analysis-setup.sh` (also run
automatically by the command) and downloads ffmpeg, a Python 3.12 venv with
yt-dlp and WhisperX 3.8.6, and ~3 GB of Whisper model weights; diarization
requires an HF token for gated models and is off by default.

Rerun `bash /workspace/.devcontainer/setup-opencode-harness.sh` and start a new
OpenCode session after changing the command or script. To check an existing
installation without changing it, compare the command and Bash script with their
counterparts under `~/.config/opencode/` using `cmp`; this is separate from the
isolated tests. The script requires Bash, jq, curl, and GNU coreutils.

Change only LSP and Context7 settings without changing provider credentials:

```sh
bash /workspace/.devcontainer/setup-opencode-harness.sh --lsp --context7
```

For `just` diagnostics:

- `--lsp` registers `just-lsp` for `.just` and `.justfile`, preserving an existing `lsp.just` override.
- For an extensionless `justfile` or `Justfile`, add its absolute container path to `lsp.just.extensions` in `~/.config/opencode/opencode.json`, then restart OpenCode.

## Tool versions

The `just`, `just-lsp`, and croc release archives are version-pinned and checked
against SHA-256 digests before extraction. Update each Dockerfile version and its
digest together. Node intentionally tracks the v24 release line, and Rust tracks
stable; fresh builds pick up toolchain fixes when those layers are rebuilt.
Projects can select a specific Rust toolchain with `rust-toolchain.toml`.
The image has two build targets that use the same shared tooling instructions:
`heavy` uses the CUDA development base image and adds Rust, while `light` uses
plain `ubuntu:26.04` and skips Rust. `compose.yml` builds `heavy`,
`compose.light.yml` builds `light` on hosts without an NVIDIA GPU.
PDF MCP is pinned to `@sylphx/pdf-reader-mcp@4.1.3` so restarting it cannot silently
select a newer release. Rerunning setup with PDF enabled migrates the old workspace
`@latest` command while preserving custom commands.

## Repository files

| File | Purpose |
|------|---------|
| `.devcontainer/Dockerfile` | Base image, tool versions, and packages |
| `.devcontainer/compose.yml` | Full variant: container service, workspace mount, GPU access, and shared memory |
| `.devcontainer/compose.light.yml` | Light variant: same service without GPU access or the Rust toolchain |
| `.devcontainer/devcontainer.json` | VS Code extensions, settings, and creation hooks (full variant) |
| `.devcontainer/light/devcontainer.json` | VS Code entry for the light variant |
| `.devcontainer/.zshrc` | Shell theme and plugins |
| `.devcontainer/setup-zsh.sh` | Shell setup and configuration sync |
| `.devcontainer/setup-opencode.sh` | OpenCode installation and LiteLLM configuration |
| `.devcontainer/setup-opencode-harness.sh` | Local agent, skills, and LSP/Context7 configuration |
| `.devcontainer/AGENTS.md` | Coding guidelines for optional OpenCode setup |

## Validation

After changing the Dockerfile or Compose files, run from the repository root on
the host:

```sh
docker compose -f .devcontainer/compose.yml config --quiet
docker compose -f .devcontainer/compose.light.yml config --quiet
docker compose -f .devcontainer/compose.light.yml build dev
docker run --rm --network none gpu-workspace:light sh -ec '
  for tool in node npm uv pyright clang cmake make gcc just just-lsp croc xz zstd; do
    command -v "$tool"
  done
  node --version
  uv --version
  test -z "$(command -v cargo)"
  test ! -d /usr/local/cuda
  test "$LANG" = C.UTF-8
'
```

For full-image changes, also build it and check Rust:

```sh
docker compose -f .devcontainer/compose.yml build dev
docker run --rm --network none gpu-workspace:dev cargo --version
```

Run inside the container, from `/workspace`, after changing setup scripts:

```sh
bash .devcontainer/test-opencode-harness.sh
bash -n .devcontainer/setup-opencode.sh
sh -n .devcontainer/setup-zsh.sh
git diff --check
```

To check Apollo's runtime registration with an installed OpenCode and OpenAgent, run `bash .devcontainer/test-opencode-agent-display.sh /path/to/opencode /path/to/oh-my-openagent/dist/index.js`. This uses a temporary home and configuration, verifies the display name, default agent, model/variant preservation, and agent-list entry, and sends no model prompts.
