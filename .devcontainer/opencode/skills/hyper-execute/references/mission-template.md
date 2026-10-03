# Mission file template

Create at `.omo/missions/<slug>/mission.md` in Phase 0. Every acceptance
criterion must carry an evidence type plus a runnable command or a concrete
observation procedure — an AC without one is not accepted into the mission.

```markdown
# Mission: <one-sentence goal>

## Acceptance criteria

- AC1: <criterion> — evidence: command `exact command` → <expected observable outcome>
- AC2: <criterion> — evidence: browser flow <route, actions, observation procedure>
  via playwright-cli → <expected behavior>
- AC3: <criterion> — evidence: command `exact command` → <expected observable outcome>

## Verification environment and authorization

- Repository: <target repository and applicable instructions>
- Environment: <working directory, setup, isolated test data/resources>
- Authorized actions: <existing user authorization, including branch finishing>

## Verification policy (approved contract)

- high_stakes: false
- Required verifiers: correctness, QA, <security when applicable>
- Security applicability: <required/skipped; changed behavior, exposure, auth,
  privileges, secrets, dependencies, infrastructure/configuration; reason>
- stress_test: false

## Scope out

- <explicit non-goal>
- <explicit non-goal>

## Stop conditions

- Exit verified: every AC is VERIFIED with fresh evidence, all required verifiers
  completed and QA checks passed, and no confirmed Critical/Important findings
  remain open. Require one clean round, or two consecutive clean rounds on the
  same candidate when high_stakes. Missing/unverifiable evidence cannot pass.
- Exit user: the user says stop — any phrasing, any time.
- Exit blocked: no authorized path can obtain required capabilities, evidence,
  permission, or a consequential user decision.
- Exit budget-exhausted: a user limit or round budget is reached before completion,
  or remaining rounds cannot meet the clean-round requirement after a failure.
- All exits: cancel mission-owned workers/watchers/verifiers and queued dispatches,
  suspend mission-owned continuation per the runtime reference, preserve work,
  record state, and report evidence with its completion status.

## Budget

- verification_rounds: 3
- user_limits: <explicit time/cost limits, or none specified>

## Artifacts

- Plan: <filled in Phase 1 — path to .omo/plans/…>
- Ledger: .omo/missions/<slug>/ledger.md
- Worktree: <filled in Phase 2>
- mission_base: <immutable initial implementation commit>
- baseline_source_tree: <source tree SHA including pre-existing user work>
- verification_head: <pinned integrated candidate commit; updated after fixes>
- candidate_id: <source tree SHA from the runtime reference's snapshot procedure>
```

Notes:

- `high_stakes: true` requires two consecutive clean verification rounds
  on the same candidate before exit-verified and a round budget of at least two.
- Each started round counts, including incomplete/retried rounds. A fix requires
  sufficient remaining budget for the required clean rounds. No implicit extensions.
- `stress_test: true` adds one roundtable on the completed plan in Phase 1.
- The user may edit `verification_rounds` in the file directly; the running
  orchestrator re-reads the file at each round boundary.
- Skip security only when the approved policy records it as inapplicable. Pure
  prose/cosmetic changes may qualify; infrastructure/auth/configuration changes
  can require it without any application-code change.
- Approved goal, ACs, expected evidence outcomes, scope, authorization/environment,
  stop conditions, and the full verification policy may change only through an
  explicit user-approved amendment. Hash those contract fields; exclude only artifact paths,
  verification_rounds, and user_limits. Record approval in the ledger below.

## Compact ledger format

Create `<mission-dir>/ledger.md`; fill fields as the corresponding phase runs.
Use artifact links for lengthy outputs. Keep current state plus an append-only
transition history; do not overwrite the evidence for an earlier decision.

```markdown
.omo/missions/<slug>/mission.md

- State: <phase, active/verified/user/blocked/budget-exhausted, next action>
- Contract: <version/hash, approval reference, amendment references>
- Plan: <path, version/hash, review references>
- Capabilities: <tool/agent/category mappings, isolation, concurrency, skips/blockers>
- Repository: <branch, worktree, wave/lane refs, mission Boulder work_id>
- Continuation: <Boulder status/mirror, mission todo states, shutdown receipts>
- Baseline: <mission_base, baseline_source_tree, initial status/inventory path>
- Candidate: <verification_head, candidate_id, source snapshot/manifest path>
- Budget: <rounds started/limit, clean streak and its candidate_id, user limits>

| Task | Lane/worktree | State | task_base/task_head; source manifest | Review/report |
|---|---|---|---|---|
| <N> | <ownership> | <pending/running/incomplete/complete> | <refs/paths> | <refs/paths> |

| Dispatch | Task/role | Result ID | Continuation ID | Watcher ID | State/cancellation |
|---|---|---|---|---|---|
| <ID> | <owner> | <ID> | <ID or none> | <ID or none> | <running/completed/cancelled/unknown> |

| Round | candidate_id | Verifier | AC/check | Verdict; command/procedure; observed result |
|---|---|---|---|---|
| <R> | <hash> | <role/result ID> | <AC/check> | <verdict and artifact link> |

| Finding | Severity/failed AC | Evidence | State | Owner/resolution |
|---|---|---|---|---|
| <ID> | <severity/AC> | <trigger/result> | <open/resolved/rejected/deferred minor> | <task or contrary evidence> |

## Transitions and rulings

- <time>: <phase/task/round transition, counters, refs, next action>
- Ruling: <what> — <evidence/why> — <cost if wrong>
```

On resume, reconcile ledger refs, approvals, active dispatches, and source manifests
with actual state before accepting completion or dispatching replacements.
