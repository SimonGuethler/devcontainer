---
description: Drive one goal to evidence-verified completion — frozen mission contract, ulw-plan/ulw-execute execution, independent blind verification rounds. The most expensive workflow; use only on explicit request
---

Load the `hyper-execute` skill and run its full workflow for this goal:

$ARGUMENTS

The argument is a goal statement, a mission path (`.omo/missions/<slug>/mission.md`),
or a plan path (`.omo/plans/*.md`). Resolve it per the skill's Phase 0.

Check required capabilities first. Plan and execute through the ulw-* machinery,
then verify a pinned candidate through fresh independent contexts. Validate supplied
plans and review provenance before execution. Present the mission contract for
explicit approval before implementation, unless that exact contract is already
approved; this replaces a duplicate plan approval gate. Approved scope/AC changes
need an amendment; routine choices use recorded rulings. Honor existing authorization.

Report one outcome: verified, user-stopped, blocked, or budget-exhausted. Verified
requires all ACs verified, required verifier coverage complete, QA passing, and no
open confirmed Critical/Important findings on the same candidate. Respect explicit
limits and the round budget; missing or repeated failing evidence cannot pass.
On any exit, cancel mission-owned active/queued work, preserve changes, and record
recovery state. Non-verified exits report partial evidence and the next required step.

Starting or resuming requires `/hyper-execute`, including for saved missions.
Ordinary messages may steer or stop an active invocation, but do not start one.
If the request is analysis, planning, or
idea generation instead, recommend `/hyper-analyze`, `/ulw-plan`, or
`/brainstorm`.
