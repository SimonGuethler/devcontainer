# OpenCode / OpenAgent integration

Read before Phase 1. These adaptations target the installed OpenAgent 5.1.8;
check exposed schemas on other versions. They override inherited Codex-only
examples, automatic scope expansion, and premature execution/branch finishing.

## Controller, planner, and workers

- The active primary agent remains the mission controller. Invocation authorizes
  mission artifacts and implementation within the approved contract; it does not
  require changing the default Apollo agent or provider configuration.
- Dispatch the planner as a category dispatch with `ulw-plan` and the approved
  contract/approval reference. No `prometheus` agent exists in OpenCode; the
  equivalent-specialist rule maps planning to a category-routed worker with the
  `ulw-plan` skill loaded. Its role is planning only. The controller owns user
  decisions and subsequent
  execution. The contract satisfies the planning approval gate; a material change
  comes back as an amendment. Planning's "ideal state" cannot enlarge scope.
- Use `task(subagent_type="metis"|"momus"|"oracle"|"librarian"|"explore",
  load_skills=[...], run_in_background=true, ...)` for named specialists, or
  `task(category="...", load_skills=[...], run_in_background=true, ...)` for workers.
  Fill actual required fields; never combine category and subagent_type. Momus
  receives exactly one `.omo/plans/*.md` path and its executable review boundary.
- Prefer the reviewed task's category and applicable installed skills: `programming`,
  `frontend`, `debugging`, or `git-master` when their behavior fits the authorization.
  Worker no-delegation and scope constraints override category fan-out advice.
  A plan/tool capability gap is reported to the controller, not worked around by
  an implementer inventing a new workflow.
- New verifiers use new tasks with no `task_id`; implementation fixes may continue
  using the returned **session/continuation ID** as `task_id`. Background result IDs
  identify collected results, not necessarily resumable sessions. Keep both.
- Apply ulw-execute's worktree, dependency, QA, and cleanup gates with safe bounded
  parallelism. Do not obey an inherited minimum-three-subtasks rule when it would
  fragment cohesive work or defeat batching. Use ordinary background tasks for v1
  waves; a team audit is a separate conditional specialist workflow.
- Do not create an OMO Goal. This setup intentionally disables its goal hook.
  Use mission state, Boulder, and todos. Do not emit mission-complete or perform
  default push/PR/merge/cleanup at ulw-execute's inner completion: Phase 3 and the
  user's branch-finishing authorization still govern those actions.

## Boulder and continuation lifecycle

Register one mission-owned Boulder `work_id` at Phase 0 close — before the
contract approval gate — not at Phase 2 start; later phases add fields
(active_plan, worktree, task refs) but the work exists from the mission's first
turn. Retain other `works` entries and
unknown fields. OpenCode session identities use `opencode:<session_id>`, not
the `codex:` prefixes in portable skill examples. Use the current schema and
record the controller/session, agent, active_plan, worktree, and work_id in the
mission ledger. The ulw evidence ledger, mission ledger, plan checkboxes, and
todos must agree; link raw ulw evidence instead of duplicating contradictory state.

Background-completion notifications are best-effort, not a guaranteed wake-up
(observed: a turn ended seconds before its own notification, and the session
stayed dormant for hours). Any turn that must end with mission-owned background
tasks pending therefore records those task IDs and the resume path as its final
action, and the next user message — however minimal — reconciles dispatch state
from the ledger before new work. When collecting a completed dispatch's output
while new findings are pending, fold the collected findings into the artifacts
in the same turn; a collection turn that ends without folding re-pays the
collect cost on every later step.

Before Phase 3, set this work's status to `paused` and update the top-level mirror
only if `active_work_id` names this work (or it is the sole legacy work). Cancel
mission execution todos that could restart workers, keeping plan checkboxes and
their pending verification tasks intact. The controller advances verification
from the mission ledger and completion notifications. Temporarily reactivate this
work and rebuild only its needed todos for an authorized fix, then pause again
before collecting independent evidence.

On user, blocked, or budget-exhausted exit, pause the same work, cancel its pending
and in-progress todos/dispatches/watchers, and record shutdown receipts. Cancelled
todos are a suspension record, not completed work; preserve unchecked plan tasks.
On verified exit, after confirming candidate identity and all mission gates, mark
its remaining verification checkboxes/todos done and Boulder work `completed`.
Never mark failed work completed to silence continuation.

Prefer supported scoped state updates. If editing Boulder JSON is necessary,
read the latest state, change only the owned work and matching mirror, preserve
other fields, and write atomically; serialize controller state writes. Verify the
saved status. If ownership/state cannot be established, exit blocked and report
the live continuation risk instead of clearing the entire project state.

OpenAgent's `/stop-continuation` also clears the **whole project Boulder file**
and cancels continuation countdowns broadly. Do not invoke it automatically in a
shared project. Use it only when that broader shutdown is explicitly authorized,
after preserving recovery records for affected work. A sentence in a final report
alone does not stop runtime continuation. An explicit `/hyper-execute` resume
reconciles state and reactivates only this mission's work and todos.

## Reproducible source candidate

Run capture at the target repository root with implementers stopped. Inventory tracked
and relevant untracked source, including pre-existing user changes. Review source
paths and exclusions first: omit mission artifacts, prior reports/verdicts, caches,
generated build outputs, memory notes, and credentials. Include required fixtures
and lockfiles. Keep capture metadata outside the exported source subtree and
private; a mission artifact directory under excluded `.omo/` is suitable. Do not recursively
copy `.git` or follow symlinks into reports, credentials, or mutable external data.
Materialize necessary external inputs separately and record their identity.

Use a temporary Git index. This records paths, file contents, executable modes,
symlink targets, and tracked deletions as a source tree without creating a commit,
changing refs, or touching the real index. Fill these parameters with reviewed
values before running the Bash block; arrays may be empty. Capture requires no
unresolved merge conflicts. Read the real index to include staged additions, then
write only the temporary index; the working tree supplies the current contents.

```bash
set -euo pipefail
snapshot_dir="<new absolute private mission artifact directory>"
source_paths=("<approved untracked source file>")
excluded_paths=("<additional private/generated path>")
if [[ -n "$(git ls-files --unmerged)" ]]; then
    printf '%s\n' 'Resolve merge conflicts before capturing a candidate.' >&2
    exit 1
fi
verification_head="$(git rev-parse HEAD)"
mkdir -m 700 -- "$snapshot_dir"
snapshot_index="$snapshot_dir/index"
GIT_INDEX_FILE="$snapshot_index" git read-tree "$verification_head"
GIT_INDEX_FILE="$snapshot_index" git add -u -- .
while IFS= read -r -d '' source_path; do
    if [[ -e "$source_path" || -L "$source_path" ]]; then
        # Already tracked in the real index; retain even staged ignored additions.
        GIT_INDEX_FILE="$snapshot_index" git add -f -- "$source_path"
    fi
done < <(git ls-files -z)
for source_path in "${source_paths[@]}"; do
    if [[ -e "$source_path" || -L "$source_path" ]]; then
        GIT_INDEX_FILE="$snapshot_index" git add -- "$source_path"
    fi
done
GIT_INDEX_FILE="$snapshot_index" git rm --cached -r --ignore-unmatch -- \
    .omo .apollo/tmp .opencode/memory "${excluded_paths[@]}"
candidate_id="$(GIT_INDEX_FILE="$snapshot_index" git write-tree)"
GIT_INDEX_FILE="$snapshot_index" git ls-files --stage -z > "$snapshot_dir/manifest"
mkdir -- "$snapshot_dir/source"
GIT_INDEX_FILE="$snapshot_index" git checkout-index --all --prefix="$snapshot_dir/source/"
```

Capture `baseline_source_tree` with the same selection before implementation so
pre-existing dirty work is included in test inputs but distinguishable in reviews.
Record the tree SHA, HEAD, source selection, manifest, and snapshot path in the
ledger. Generate the raw mission diff from baseline_source_tree to candidate_id;
use task-start snapshots similarly when tasks share already-dirty files.

If capture or checkout fails, no candidate exists. Inspect the exported files,
modes, and symlinks; repeat capture with a fresh temporary index and the same
selection before dispatch and before declaring completion. A different tree SHA
invalidates the candidate. Give verifiers source, approved contract, raw mission
diff where appropriate, and neutral environment setup; keep the manifest/metadata
outside their source checkout. Each verifier gets its own resource directory.

Submodules, LFS objects, or checks requiring Git metadata need the project's
existing isolated checkout tooling and pinned input identities. Do not call an
incomplete export verified or attach the live `.git` directory to a verifier.
Temporary Git objects may remain until normal GC; retain recovery snapshots until
handoff, and remove only mission-owned temporary resources after their use ends.
