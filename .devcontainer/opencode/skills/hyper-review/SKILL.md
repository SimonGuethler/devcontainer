---
name: hyper-review
description: Evidence-based assessment of a concrete artifact or bounded topic for correctness, completeness, plan alignment, and worthwhile improvements. Use for hyper-review or an in-depth review of code, a system, or a plan; use hyper-analyze to investigate the underlying problem, assumptions, and alternatives through multiple critic rounds.
---

# Hyper-review

Start with the concrete artifact or bounded topic and its intended outcome.
Assess whether it is sound, complete, and worth improving. Investigate deeply
enough to uncover material gaps and recommend practical improvements.
Depth comes from tracing evidence, testing
assumptions, and resolving contradictions, not from report length or finding quotas.

## Establish the review boundary

- Identify the question, target, constraints, and expected outcome from the
  request and available context. State material assumptions; ask only for missing
  information that changes the investigation. Continue independent work meanwhile.
- Evaluate the target against its goals, contracts, and accepted decisions.
  Challenge its premise when evidence warrants it, but do not automatically reopen
  settled choices. If a consequential unresolved question merits hyper-analyze,
  explain why and recommend that next step; do not silently launch its multi-round
  workflow without a request for that deeper analysis.
- Establish the inspected state: repository/revision and working-tree scope,
  plan version, or research date and relevant product versions. Read applicable
  instructions and representative patterns before assessing alternatives.
- For broad requests, map the important areas and prioritize by impact and
  uncertainty. Keep a compact coverage record of inspected areas, open questions,
  and exclusions so a long investigation does not silently lose scope.
- For follow-up reviews, establish what changed since the previous assessment.
  Recheck affected areas and earlier findings, marking each as resolved, still
  present, or unverifiable with current evidence. Reuse unaffected evidence only
  while its assumptions remain valid; expand coverage when changes affect other
  contracts or conclusions. If the previous state is unavailable, disclose that
  limitation rather than claiming an incremental review.
- Review and research do not authorize implementation. Recommend changes unless
  the user also requests fixes; save or revise documents only when requested.
  Honor the active agent's tool and write boundaries. In particular, a skill does
  not enable repository tests or implementation when the agent forbids them.

## Build and challenge the evidence

Choose and combine the following lenses according to the task. Do not force a
code checklist onto nontechnical research or research unrelated to the decision.

### Topic research and alternatives

- Decompose the question into claims that could change the conclusion. Research
  the highest-impact unknowns and plausible competing explanations first.
- Use available search, document, scholarly, or source tools as appropriate.
  Read sources after discovery; prefer primary evidence and documentation matching
  the relevant version. Verify current or uncertain external claims rather than
  treating remembered facts as established evidence.
- Compare credible alternatives against the user's constraints, including the
  current approach when viable. Explain trade-offs, applicability, costs, and
  what evidence would change the recommendation.
- Seek contrary evidence. Reconcile disagreements using methods, dates, versions,
  and context; repeated claims derived from one source are not corroboration.
  Distinguish established findings, source claims, and your own inferences.
- Cite only material actually accessed. Link decisive claims to supporting
  sources and disclose partial access or missing evidence. Do not infer full-text
  results from abstracts or search snippets. Keep private material out of queries.

### Code and system review

- Map relevant entry points, component boundaries, data flow, configuration,
  dependencies, and tests. Trace important paths through callers and downstream
  consumers; a suspicious line alone is not a confirmed defect.
- Trace representative scenarios end to end across component boundaries: a normal
  case, an important boundary case, and a failure/recovery case where relevant.
  Follow inputs, state transitions, side effects, and observable outcomes to find
  integration gaps. Distinguish static traces from scenarios actually executed.
- For a change review, establish the requested diff/base and inspect surrounding
  contracts. For uncommitted work, include staged, unstaged, and relevant untracked
  files. Separate introduced regressions from pre-existing issues.
- Examine correctness and failure recovery, security and trust boundaries,
  compatibility, performance at realistic scale, and maintainability where
  relevant. Consider concurrency, retries, partial failures, lifecycle cleanup,
  and operational visibility when the system's behavior depends on them.
- Check whether tests assert the required behavior, including meaningful failure
  cases, rather than merely mirroring the implementation. Inspect checks before
  running them; use permitted, isolated validation without changing external state.
  If execution is unavailable or forbidden, use static tracing and state the limit.
- For each suspected defect, identify a concrete trigger and impact, then inspect
  guards, callers, and tests that might disprove it. Label unresolved concerns as
  hypotheses with a specific verification step, not confirmed findings.

### Plan quality and implementation alignment

- Read the actual plan and accepted amendments. Identify requirements, acceptance
  criteria, dependencies, sequencing, and verification expectations. Distinguish
  binding requirements from examples, tentative suggestions, and open decisions.
- Check whether the plan achieves the stated goal and handles material risks,
  rollout/recovery needs, and prerequisites. Flag contradictions or stale
  assumptions; mechanical compliance with a flawed plan is not success.
- Map each material requirement in a compact table with separate columns for
  requirement, implementation status/evidence, verification status/evidence, and
  gap/next check. Implementation may be implemented, partial, missing, deviated,
  or unverifiable; verification should identify static inspection, passing or
  failing checks, or checks not run/blocked, with their scope. Code presence or
  unrelated passing tests do not establish acceptance: implemented but untested
  is not fully verified, and a requirement is satisfied only when its acceptance
  criteria are supported by appropriate evidence.
- Explain deviations and their impact. Recognize accepted or justified changes;
  do not silently redefine requirements or demand obsolete plan details. Surface
  decisions needing the user's judgment separately from implementation defects.

## Synthesize improvements

- Look explicitly for useful improvements beyond defects: unnecessary complexity,
  duplicated responsibilities, missing observability, and opportunities to simplify
  the relevant design or workflow. Tie each recommendation to observed evidence
  and a concrete benefit for the user's goal; omit speculative cleanup.
- Prioritize supported issues by concrete impact and likelihood. For each material
  finding provide location/source, trigger or evidence, consequence, and the
  smallest useful correction or next step. Note confidence where uncertainty
  changes the decision; do not manufacture numeric precision.
- Separate defects and unmet requirements from optional improvements. For
  improvements, explain the expected benefit, effort/dependencies, and trade-off.
  Prefer changes compatible with existing architecture and conventions; recommend
  a larger redesign only when evidence justifies its migration cost.
- Assess proposed corrections as well as the original problem. Check for
  compatibility risks, migration work, operational burden, and new failure modes.
  Explain material costs and why the expected benefit justifies them; a confirmed
  defect does not establish that the first proposed fix is appropriate.
- For each material unresolved question, identify the smallest useful experiment,
  measurement, or missing fact that would resolve it and whether it blocks the
  recommendation. Perform permitted checks when practical; otherwise state the
  next check and how its possible outcomes would affect the conclusion.
- Before concluding, challenge the strongest findings against contrary evidence,
  deduplicate root causes, and check that recommendations address the actual goal.
  Refresh affected evidence if the reviewed state changes.
- For broad or consequential reviews, consider a bounded independent assessment
  by an available specialist when delegation is permitted and adds useful coverage.
  Supply the question, raw evidence, constraints, and permitted scope without
  leading the specialist toward a preferred verdict. Keep implementation and write
  boundaries intact. Verify decisive references and reconcile disagreements;
  specialist agreement alone is not proof. Complete the review directly when
  delegation is unavailable or adds little value; do not require a fixed agent count.
- Stop when the material questions have supported answers and relevant coverage
  is complete, or when remaining uncertainty requires unavailable evidence or a
  user decision. Do not repeat searches or review rounds without a concrete lead.

## Deliver the assessment

Lead with the assessment of the target and its most consequential findings.
Emphasize prioritized defects, worthwhile improvements, and verification gaps.
Include the relevant
scope, prioritized findings, plan coverage or alternatives when applicable, and
recommended next actions. Make evidence easy to follow with exact file/symbol/line
references or source links. Report checks actually run and their outcomes separately
from suggested checks, plus material exclusions and unresolved questions.

If no actionable defects are found, say so without claiming proof of correctness.
Be thorough in the investigation and concise in the report; do not pad it with
cosmetic preferences, speculative rewrites, or an exhaustive tool transcript.
