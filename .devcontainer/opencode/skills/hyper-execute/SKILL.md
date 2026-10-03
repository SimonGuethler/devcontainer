---
name: hyper-execute
description: Drive one goal to evidence-verified completion through a frozen mission contract, OpenAgent planning/execution, and independent blind verification rounds. Start or resume ONLY through /hyper-execute; never auto-activate on ordinary implementation requests or saved-mission references.
---

# Hyper-execute

Drive a **goal** — not a plan — to verified completion. Freeze what "done"
means before any work starts, plan and execute through the existing ulw-*
machinery, then run independent verification rounds that never see the
implementers' claims. Four outcomes exist:

- **Exit verified**: a clean round satisfies the Phase 3 completion rules
  (two consecutive clean rounds on the same candidate when high_stakes).
- **Exit user**: the user says stop — any phrasing, any time. Record state,
  present the partial evidence table, stop. Never negotiate.
- **Exit blocked**: a required capability, evidence source, permission, or
  consequential user decision is unavailable and no authorized path remains.
- **Exit budget-exhausted**: an explicit user limit or the verification-round
  budget is reached without meeting the completion rules. Report incomplete work.

Continue authorized work until one of these outcomes applies. Respect user
time/cost limits and platform limits; stopping does not establish completion.

## When not to use

Routine small edits: just do them. Analysis questions: `/hyper-analyze`.
Plan-only requests: `/ulw-plan`. Idea generation: `/brainstorm`. This
workflow is for goals whose completion the user wants proven by independent
verification — it is deliberately the most expensive command in the toolkit.

## Authorization and rulings

Follow applicable instructions and existing user authorization. Obtain missing
authorization before destructive operations, credential changes, or external
mutations such as merge, push, and publish; do not request it again for an action
already authorized. Ask for a consequential decision when evidence cannot
resolve it. Continue independent authorized work while waiting.

Resolve routine choices with `Ruling: <what> — <why> — <cost if wrong>` in
the ledger. Rulings may reject findings with contrary evidence, but cannot waive
an approved AC or accept an unresolved Critical/Important defect as verified.

## Capability preflight

Before creating the contract, check actual tool schemas, installed skills, agent
permissions, configured categories/models, concurrency, and worktree support.
Resolve `ulw-plan`, `ulw-execute`, `workspace-review`, `hyper-review`, and
`workspace-verification`, plus `playwright-cli` for browser ACs. The security
verifier uses template B directly; it does not require the team-only
`security-research` skill. Require `roundtable` only for an enabled stress test.
Record effective role/category models and provider availability, including built-in
defaults. OpenAgent 5.1.8 has `deep-low` and `deep-high`; older installations may
need an equivalent mapping. Do not infer strength from category names alone.

Read `references/opencode-runtime.md` before planning or execution. It defines
the OpenCode adaptation of the ulw workflows, continuation lifecycle, and source
snapshot procedure. Use actual schemas rather than copied Codex-only examples.

An equivalent permitted specialist may replace a named agent. Reduced concurrency
may serialize work, but cannot remove required checks or fresh-context isolation.
Do not install dependencies, enable worktrees, or change configuration merely to
satisfy the skill. If no equivalent capability preserves the workflow, exit
blocked with the missing capability and smallest remedy; do not claim independence
or silently replace the ulw workflows with an improvised process.
If preflight blocks before a mission exists, record the invocation, missing
capability, and absence of dispatches in the final response; no ledger is needed
until Phase 0. For an existing mission, record the blocker in its ledger.

## Phase 0 — Freeze the mission

1. Resolve the input: a goal statement, or a path to an existing mission
   (`.omo/missions/<slug>/mission.md`) or plan (`.omo/plans/*.md`). A goal
   statement starts this phase. An existing mission goes through Recovery before
   resuming. A bare plan gets a mission created around it and goes through Phase 1
   validation after contract approval; a path alone proves no review history.
2. Create `.omo/missions/<slug>/mission.md` from
   `references/mission-template.md`: one-sentence goal; acceptance criteria
   where **every AC carries an evidence type plus a runnable command or a
   concrete observation procedure** — an AC without one is not accepted into
   the mission; an explicit scope-out list; stop conditions; budget
   (verification rounds: 3 default, user-adjustable in the file); artifact
   paths. Include user time/cost limits and the verification policy: high_stakes,
   required verifier coverage, and security applicability with its reason. Require
   security verification for changes to executable behavior, exposed services,
   authentication, privileges, secrets, dependencies, or infrastructure configuration;
   pure prose/cosmetic changes may skip it. Preserve existing
   missions; use an unused slug for a new mission. Initialize its ledger before
   the contract audit using the format in `references/mission-template.md`.
3. Dispatch one `metis` subagent to audit the draft contract: is each AC
   verifiable, complete, and unambiguous; which hidden requirement or
   acceptance gap is missing; which AC is really two ACs. Fold the fixes in.
4. Present the mission contract and **wait for explicit approval**, unless that
   exact contract is already approved in the session. Record the approved contract
   version/hash and approval reference. Hash the goal, ACs/evidence outcomes, scope,
   authorization/environment, stop conditions, and verification policy, including
   high_stakes. Only artifact paths, verification_rounds, and user_limits may change
   without a contract amendment.
   This is the single upfront gate;
   Phase 1 still plans and reviews, but does not ask for duplicate approval.
5. Changes to any approved contract field require an explicit amendment and user
   approval. Record it and invalidate affected evidence. Record operational path
   and budget updates separately; they do not approve weaker verification.

## Phase 1 — Plan

- **Plan path given** (or a resumed mission with a plan): validate against the
  installed ulw-plan format, map every approved AC to tasks, and check dependencies,
  commands, interfaces, and applicability to the current code. Inspect review
  records tied to the plan version; if missing or stale, run the missing Metis
  audit and dual Momus+Oracle reviews required by ulw-plan.
  Repair only affected sections and re-review them. Do not remove an AC through a
  scope ruling or accept structure as proof of review.
- **Goal statement**: dispatch a `prometheus` planner with `ulw-plan`, the approved
  contract and approval reference, and a plan-artifact-only boundary. Follow
  classification, interview or announced defaults, scaffold, mandatory
  Metis, dual Momus+Oracle review. Hyper-execute's approved contract replaces its
  separate plan approval gate; ask only for a material contract amendment or
  missing authorization. Never write your own plan format. Record the plan path,
  version, and review references in the ledger and mission file.
- **Opt-in stress test**: when the mission file says `stress_test: true`,
  run one `roundtable` on the completed plan in addition to the dual review,
  and fold accepted findings into the plan before Phase 2. Off by default.

## Phase 2 — Execute

Load the `ulw-execute` skill and follow its machinery — Boulder state, todos
mirroring plan checkboxes, dependency-ordered waves, task-owned worktrees,
per-lane completion-condition watchers, category-routed workers, and
"inconclusive is never a pass". Hyper-execute adds the layers below. When
this skill and ulw-execute conflict, this skill wins on authorization, stopping,
review, fix loops, evidence, and lifecycle; ulw-execute supplies wave and worktree
mechanics within the mission's scope, authorization, and concurrency limit.

Record immutable `mission_base` before any implementation, plus the initial Git
status and an inventory of pre-existing staged, unstaged, and relevant untracked
work. Preserve that work and distinguish it from mission changes. Record branch,
worktree, and wave/lane refs, and capture baseline_source_tree using the runtime
reference before dispatch; never overwrite mission_base for a later task.

### Pre-flight scan (before the first dispatch)

Write one table to the ledger: for every pair of tasks sharing a file or an
interface, what one produces against what the other consumes and what you
found; one row per task for internal consistency (its tests against its own
code). Resolve every surfaced conflict before work starts against the approved
mission and reviewed plan. A plan cannot override the contract. A clean scan
still shows its rows.

### Worker dispatch hygiene

- **Briefs are files, never prompts.** Write the task's exact values
  (numbers, signatures, paths, test cases verbatim) to
  `<mission-dir>/briefs/task-N-brief.md`. The dispatch prompt carries: one
  line of project context, the brief path ("your requirements — use its
  values verbatim"), interfaces from earlier tasks that the brief cannot
  know, the report path (`task-N-report.md`), and the no-subagents rule.
  Never paste session history into a dispatch.
- **Workers never dispatch subagents and never spawn reviewers.** Review
  comes from the orchestrator. A worker-spawned reviewer is a defect to
  flag, not extra rigor.
- **Record `task_base` and initial task status before each implementation/fix
  dispatch.** Capture its task-start source tree when uncommitted work is present;
  pin `task_head` on completion. Store dispatch/result and continuation
  IDs separately, task ownership, lane, report path, and review status in the ledger.
- **Batch small same-shape tasks**: N repeated mechanical edits across
  files = one brief, one worker, one review of the combined diff.
- **Serial within a lane; parallel across independent lanes** per
  ulw-execute's wave rules. While waiting on children, do local work
  (ledger updates, next brief, review packaging); rely on background
  completion notifications; never poll with short timeouts and never sit in
  an open-ended silent wait.
- **Category routing** — specify a supported category from the preflight mapping
  on category-routed dispatches. Prefer `quick` for mechanical changes, `writing`
  for prose, `visual-engineering` for UI, `deep-low` for integration/debugging,
  `deep-high` for consequential decisions, and `ultrabrain` for hard reasoning.
  Honor reviewed plan annotations or record why a mapping changes. Use named
  specialists through `subagent_type`, with no simultaneous category parameter.
  Every worker/verifier brief prohibits delegation, overriding category fan-out
  advice. Collect `ESCALATE` as a routing result, never as DONE.

### Per-task review and the fix loop

- On a worker's DONE: write the review package — `git log --oneline`,
  `git diff --stat`, and `git diff -U10` over `task_base..task_head` — into one file
  under `<mission-dir>/packages/`; dispatch the `workspace-review` agent in
  the background with the package, brief, and report paths. Every review
  requires two verdicts: spec compliance AND quality.
  Include staged/unstaged diffs and relevant untracked file contents, comparing
  with the task's initial inventory to identify mission-owned changes. For dirty
  work, use task-start and completion source trees for the authoritative raw diff;
  commit history is supplemental. An empty
  commit range is not proof of an empty change. Supply the complete package to
  the read-only reviewer; do not require shell access from workspace-review.
- Fix loop, cap 5 rounds per task: rounds 1–3 resume the same worker via its
  continuation id with the findings verbatim (its context is intact);
  rounds 4–5 dispatch a fresh worker with stronger configured reasoning when
  available, with the brief, report, and findings ("a prior implementer attempted
  this N times; read the report"). Every round ends with a **scoped re-review** of the fix
  range only; the re-reviewer verdicts each finding ADDRESSED /
  NOT ADDRESSED and flags new breakage in the fix diff only.
- Minor findings never enter the loop: ledger
  `Task <N>: minor (deferred): <one-liner>`; the final review triages them.
- At the cap: reject false positives with evidence or explicitly carry unresolved
  findings into an owning follow-up task, keeping affected tasks incomplete.
  Do not advance dependent work past a blocking defect. If no authorized path
  remains, exit blocked. Do not create a new task solely to restart the capped fix
  loop for the same defect. Never fix findings in your own session.
- Ledger after every round:
  `Task <N>: fix round <R>/5 (<X> addressed, <Y> open — <one-liners>; commits <a>..<b>)`.

### Final whole-branch review

After implementation tasks: suspend mission-owned automatic execution continuation
per `references/opencode-runtime.md`; final mission-verification tasks remain
incomplete until Phase 3 passes. Pin the integrated candidate's `verification_head`
and capture its source tree using the runtime reference. Create one review package
with the raw `baseline_source_tree..candidate_id` diff and supplemental history over
`mission_base..verification_head`, covering mission-owned uncommitted/untracked
changes. Dispatch to the strongest category with `load_skills: ["hyper-review"]`, pointed at the
deferred-minors and `Ruling:` lines. Critical/Important findings → ONE fix
dispatch carrying all of them (never one fixer per finding), then one scoped
re-review, then adjudicate residuals. There is no second fix wave here; carry
confirmed residuals into Phase 3's finding register, never mark them resolved
merely because this review's fix allowance ended.

Capture the immutable source candidate using the runtime reference's temporary-index
procedure, without creating commits or changing the user's index/refs. Record
candidate_id alongside verification_head; exclude coordination artifacts and secrets
from verifier inputs. Every source change after capture requires a new candidate_id
and invalidates affected reviews and all clean-round counts.

## Phase 3 — Independent verification rounds

The final review checked the diff. This phase checks the **mission**, with
fresh contexts that never saw any implementer claim. Use the templates in
`references/verifier-prompts.md`. Each round dispatches up to three verifiers
within the actual concurrency limit, with candidate_id and verification_head.
Use separate checkouts/copies of the same pinned candidate and isolated build,
database, port, and browser resources where needed. Serialize conflicting checks
when isolation is unavailable; no implementer may change the candidate during
verification. Temporary test artifacts are allowed; source edits are not.

1. **Correctness verifier** — mapped reasoning category, using
   `references/verifier-prompts.md` template A: receives the mission file's
   approved contract plus the shared neutral environment brief — **never the plan,
   never any worker report, never a prior round's verdicts**. It runs each AC's
   evidence command itself and returns per-AC `VERIFIED (command → observed output)` /
   `FAILED (concrete trigger)` / `UNVERIFIABLE (reason + the smallest check
   that would resolve it)`.
2. **Security verifier** — template B, with no team-audit skill loaded. Trace trust
   boundaries and demonstrate realistic attack paths on the changed surfaces,
   including infrastructure/configuration. Skip only when the approved verification
   policy marks security inapplicable; record the reason in the ledger.
3. **QA verifier** — template C (`load_skills: ["workspace-verification"]`):
   the project's own check suite plus, for UI acceptance criteria, a driven
   browser flow via the playwright-cli skill. Verifiers run commands; they
   never edit source — findings only. Record environment blockers separately.

Start each verifier as a new context without inherited conversation, rather
than resuming a reviewer/worker. Supply only the approved contract, pinned source,
appropriate raw diff, and neutral environment instructions. Prohibit reading
plans, implementer reports, ledger rulings, and prior verdicts. Do not load skills
that require these inputs or permit recursive delegation. If the tool cannot
provide independent contexts, exit blocked rather than claiming blindness.

Round rules:

- **Clean round**: every approved AC is VERIFIED with fresh observed evidence;
  every required verifier completed its assigned coverage on the same candidate;
  QA checks pass; and no confirmed Critical/Important findings remain open,
  including findings from earlier phases. FAILED, UNVERIFIABLE, missing results,
  and repeated unresolved findings cannot pass. Require one clean round, or two
  consecutive clean rounds on the same candidate when `high_stakes: true`.
- **Critical/Important findings** → ONE fix dispatch carrying all of them, a
  scoped re-review, then the next round on a newly pinned candidate. Dispatch fixes
  only when the remaining budget allows the required clean rounds afterward.
- **Minor findings** → deferred-minors ledger; never extends the loop.
  A failed AC is blocking regardless of an assigned severity.
- **Same finding two rounds running** → adjudicate once with a ruling;
  reject only with contrary evidence. A confirmed recurring defect stays open
  and blocks success; repetition alone does not establish verifier noise.
- **Structural finding** (the approach itself is wrong) → before ruling on
  the fix, invoke the specialist workflow that fits (routing table below)
  and fold its evidence into the ruling.
- **Cross-round thrashing** (the same failure category in two rounds) → bounded
  specialist diagnosis before another fix, within existing limits. Use
  `/hyper-analyze` only when its additional rounds fit the user's budget.
- **UNVERIFIABLE or failed verifier** → attempt a bounded recovery supported by
  evidence; retry as a fresh context within the round budget. If no authorized
  path can obtain required evidence, exit blocked. Missing evidence is not a pass.
- **Budget accounting**: re-read limits and check the approved contract hash/amendments
  at each round boundary before consuming edited fields. Every started
  round counts, including incomplete/retried rounds; diagnostics do not reset the
  counter. Require a positive integer budget, at least two for high_stakes.
  If the clean-round requirement is not met at the limit, or remaining rounds
  cannot meet it after a failure, exit budget-exhausted even with no new findings.
  No extra fix or verification wave follows without an
  explicit user budget extension. Record user edits to limits separately from
  contract amendments; do not treat a budget edit as approval to change ACs.

### Specialist routing

| Situation | Dispatch |
|---|---|
| External practice, versions, or benchmarks needed | `librarian` |
| Hard architecture or protocol reasoning | `oracle` |
| Hidden requirements, ambiguity, acceptance gaps | `metis` |
| Plan or executability defect mid-flight | `momus` on the plan section |
| Codebase discovery needed for a ruling | `explore` |
| Stuck fix needing deep diagnosis | `oracle`, using the `debugging` skill's methodology when useful |
| Broader research needed | `librarian` with `ulw-research` or `hyper-research` when their workflow fits |
| Deeper security investigation needed | Controller-owned `security-research` audit in a primary session with permitted team tools and budget; otherwise bounded `oracle` diagnosis |
| Heavy research or implementation work itself | reasoning category from the preflight mapping |

The hyper-* skills are lenses for these dispatches (`load_skills`), not a
fixed menu: pick the specialist and skill that fit the finding, and record
in the ledger which you chose and why.
Ordinary waves and verifier rounds use background tasks rather than teams. A
conditional team audit is additional coverage, not a replacement for the blind
security verifier, and cannot consume its independent context or omit required
checks. Chorus belongs to `/brainstorm`; do not add divergent rounds here.

### Anti-theater rule

Every round runs fresh commands in that round. A "verified" from a previous
round is not evidence; "should pass" is not evidence; reading a passing
claim is not evidence. Never claim a check ran that did not.

## Phase 4 — Exit

**Exit verified** requires, in the final message:

1. Evidence table: AC → command/procedure → observed output → round → candidate_id.
2. Deferred minors list (exhaustive).
3. **"Rulings I made"**: every ledger `Ruling:` line, in order, each with
   its cost if wrong. A ruling that dies with the workspace was a decision
   made in secret.

Before declaring verified, confirm the delivered source still matches candidate_id;
re-verify if it changed. Handle branch finishing per existing user authorization
(merge / PR / keep). If finishing needs missing authorization, report the verified
candidate and pending action without performing it.

**All exits**: cancel mission-owned active workers, watchers, verifiers, and queued
dispatches and suspend mission-owned continuation as the runtime reference specifies;
confirm cancellation/state or report what could not be stopped. Preserve
their work and user processes. Record the outcome and recovery state. For user,
blocked, or budget-exhausted exits, mark evidence partial and include the blocker
or limit and smallest next step. If the user requests an immediate stop, cancel
first and keep the state update/report brief.

## Recovery and compaction

Re-read the mission, ledger, Git status/log, worktree list, and available dispatch
status before new work. Compare contract hash/approval, plan version/reviews,
branch/worktree identity, task commit refs and source manifests, active dispatch
IDs, and evidence candidate_id with current state. A complete ledger line alone
does not prove a task still exists or its evidence is current.

Adopt or cancel surviving mission-owned workers/watchers before dispatching
replacements. If a surviving process might still mutate source and its status or
cancellation cannot be confirmed, exit blocked and report its ID and uncertainty;
do not dispatch competing work. Reuse a completed task only when its implementation
and review remain applicable; reset affected tasks/evidence after missing commits or source
changes, preserving unrelated work. Stop blocked if approval or ownership cannot
be established. Resume the reconciled phase and existing counters; compaction
does not replenish budgets. Reactivate only the reconciled mission work on an
explicit `/hyper-execute` resume. Update the ledger after each state transition.
