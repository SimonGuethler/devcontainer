---
name: workspace-browser-check
description: Verify a changed local frontend flow using the devcontainer's optional Playwright MCP, including browser-visible errors and interaction checks.
---

# Local browser verification

Read the target project's start command and prerequisites. Use its documented
local services and test data. The browser runs inside the container: localhost
refers to the container, not the host computer.

Check whether Playwright MCP tools are available before relying on them. If
missing, report the limitation; setup supports `--playwright-mcp`, but rerunning
the proxy installer rewrites its config and must not be an automatic test step.

Start only needed services; record their process/session identifiers. Wait for
readiness using a bounded check. Use accessibility snapshots and stable role/name
locators to navigate. Exercise the changed flow, inspect console/network failures,
and capture screenshots when layout matters. A screenshot alone does not prove
that submitting a form or saving a change works.

Use local fixtures and avoid real accounts or external submissions unless the
task authorizes them. Do not bypass authentication or expose secrets in artifacts.
Stop only processes you started. Report tested URL, actions, observed result,
and remaining coverage gaps; retain the project's automated tests as applicable.
