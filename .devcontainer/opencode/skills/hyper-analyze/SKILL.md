---
name: hyper-analyze
description: Investigate a difficult decision, broad problem, or uncertain assumptions by comparing explanations and alternatives through multiple critic rounds. Use for hyper-analyze or an explicitly requested multi-critic deep dive; use hyper-review to assess a concrete target against its intended outcome.
---

# Hyper-analyze

Start with the underlying problem and the decision to support. Investigate whether
the proposed approach addresses the right question and which viable alternative
best fits the user's constraints, rather than only assessing a supplied solution.

Load the installed `hyper-review` skill first. Its evidence standards, review
lenses, verification rules, follow-up handling, and write boundaries apply here.
This skill extends that foundation with required independent critic work when
delegation is available and permitted; it replaces hyper-review's optional
delegation guidance for this invocation. The problem framing, deliverable, round,
and stopping rules below replace the foundation's artifact-first framing,
assessment format, and earlier stopping point. Do not silently downgrade to
hyper-review or stop after the first useful assessment.

## Frame and investigate

- Establish the target, inspected state, decision to support, constraints, and
  material questions. Respect explicit time, cost, and scope limits; depth does
  not imply unlimited research or permission to implement changes.
- Define the underlying problem, desired outcomes, and decision criteria before
  judging a preferred solution. Separate explicit user constraints and accepted
  decisions from tentative assumptions. Preserve settled choices unless new
  evidence justifies revisiting them; explain that evidence without silently
  replacing the user's decision.
- Investigate plausible competing explanations and viable alternatives, including
  keeping the current approach when applicable. Compare them against the same
  criteria, costs, and risks. Do not invent weak alternatives to favor a preferred
  answer or force an architecture choice onto a question needing an explanation.
- Treat material findings as both significant defects and worthwhile improvements,
  including simplifications or better alternatives with concrete benefits for the
  user's goal. Apply this meaning when assigning critics and deciding whether
  further rounds are useful; do not restrict the investigation to bug hunting.
- Map the evidence and highest-risk unknowns before assigning critics. Read
  representative source material yourself and identify useful independent lines
  of investigation. Maintain a compact coverage record throughout the analysis.
- Explain the planned critic perspectives briefly. Use at least two independent
  critic tasks with distinct perspectives, normally two or three; add more only
  for a concrete coverage gap. This is part of the requested workflow, not a
  decision left to whether the coordinating agent feels scrutiny is worthwhile.

## Assign independent critics

Select perspectives that fit the question, rather than forcing every topic through
all of these examples:

| Perspective | Question to investigate |
| --- | --- |
| Requirements and assumptions | Are we solving the right problem, and which constraints or acceptance criteria are missing or unjustified? |
| Architecture and alternatives | Does the approach fit the constraints, and would a simpler alternative offer a better trade-off? |
| Correctness and implementation | Do contracts, end-to-end behavior, and plan requirements hold under realistic boundary and failure cases? |
| Security and operations | Where can trust boundaries, rollout, recovery, scaling, or observability fail? |
| Research and evidence | Do sources support the claims, and what contrary evidence or methodological limitations change the conclusion? |

- Map perspectives to actual available, permitted agents. Perspective names are
  assignments, not invented tool or agent identifiers. Separate tasks may use the
  same agent type with independent initial context; distinct models are not required.
  Respect specialist prerequisites, including any restrictions on plan locations.
  Confirm delegation is actually available and permitted before assigning
  critics, so a capability gap changes the plan at the start instead of being
  discovered mid-flight; if unavailable, fall back to direct analysis early and
  report the reduced coverage.
- Give each critic the goal, bounded question, relevant raw artifacts or source
  locations, inspected revision, constraints, and tool/write boundaries. Include
  the applicable skill guidance through supported context mechanisms. Do not give
  critics the coordinator's preferred verdict or one another's findings during
  the initial independent round. Share findings deliberately in later rounds.
- Ask for supported findings, counterexamples, useful improvements, uncertainty,
  inspected coverage, and exact evidence references. A critic may find no issues;
  do not demand disagreement or a minimum number of defects.
- Run independent tasks concurrently when supported, within available limits.
  Continue your own complementary investigation. Sequential independent tasks are
  valid when concurrency is limited. Avoid recursive critic panels and overlapping
  edits; critics investigate and report, not implement or write final documents.
- Collect results before claiming the panel completed. If a critic fails, retry
  only when a changed approach can help or use a permitted substitute. If fewer
  than two independent results are possible, complete useful direct analysis and
  explicitly report reduced coverage and why. Self-critique is not an independent
  critic and must not be presented as one.

## Run several rounds

Complete at least three substantive rounds unless explicit user limits or
unavailable capabilities prevent it. A round must examine evidence or challenge
reasoning; relabeling or summarizing earlier output does not count.

1. **Independent discovery:** The coordinator and at least two critics investigate
   distinct perspectives independently. Map important paths, assumptions, evidence
   gaps, alternatives, and candidate findings before sharing conclusions.
2. **Cross-critique and deeper investigation:** Give each critic relevant findings
   from another perspective plus the coverage gaps. Ask them to disprove claims,
   trace interactions between areas, and investigate missed scenarios or sources.
   The coordinator verifies disputed claims and pursues remaining gaps. Reuse
   existing critics where useful; this round need not spawn a new panel.
3. **Synthesis stress test:** Build a provisional assessment for at least two
   critics with complementary questions. At least one must first assess the
   original evidence without seeing earlier verdicts or the synthesis. Use a fresh
   context containing the task, constraints, and source material, without inherited
   discussion of findings; telling an already-exposed critic to ignore them does
   not restore independence. Spawn that fresh critic as a new independent task,
   not a continuation of an earlier critic's session, because a continued session
   carries its prior context. Collect that fresh assessment before revealing the
   synthesis for comparison and challenge, and resume earlier critics only for
   that later stage. If context isolation is unavailable, disclose the
   limitation and continue with the strongest available scrutiny.
   Challenge both conclusions and
   proposed corrections: hidden assumptions, counterexamples, simpler alternatives,
   migration costs, second-order effects, and evidence that would reverse the
   recommendation. Reconcile their responses before delivering the assessment.
   Evaluate recommendations together as well as individually: conflicting changes,
   shared assumptions, dependencies, implementation order, and combined migration
   or operational risks. State any sequencing constraints or mutually exclusive
   options in the final recommendation.

Between rounds, maintain a compact finding register with stable IDs, type (defect,
improvement, or open question), status (candidate, confirmed, rejected, or unresolved),
supporting and contrary evidence, and reasons for status changes. Confirmed means
the claim is supported, not that its proposed change has been implemented. Merge
duplicates under a canonical ID while preserving their references; reopen rejected
claims only when new evidence warrants it. Keep this working record in context or
an already permitted research area; it does not authorize new document writes.
Track new evidence and remaining coverage alongside it. Assign each follow-up
a concrete question and expected evidence rather than asking critics to "look
harder." Give brief progress updates on what changed and what the next round tests.

## Reconcile and continue until diminishing returns

- Verify decisive source references and traces yourself. Merge duplicate root
  causes and distinguish confirmed defects, optional improvements, and hypotheses.
  Critic votes or repeated citations to one source do not establish truth.
- Investigate disagreements using the smallest discriminating check or missing
  fact. Preserve material unresolved disagreement and its decision impact rather
  than forcing consensus. Refresh conclusions if the target changes during review.
- Continue targeted rounds beyond the initial three while material new findings
  open further questions, consequential contradictions remain investigable, or
  important coverage gaps can be closed. Re-challenge materially revised
  recommendations; do not treat the third round as an automatic finish line.
- Stop after the required rounds when the latest challenge yields no material
  new findings or changes to the recommendation, important coverage is complete,
  and remaining uncertainty is either nonblocking or requires unavailable evidence
  or a user decision. Agreement alone is not a stopping condition. Respect explicit
  user limits and report incomplete rounds when blocked or budget-constrained.
- Do not invent defects to sustain the process, repeat exhausted searches, or
  require unanimity. Thorough investigation cannot prove that every possible issue
  has been found; state residual uncertainty and the reason for stopping.

## Deliver the synthesis

Lead with a reasoned recommendation or best-supported explanation, tied to the
problem and decision criteria. Compare viable alternatives and trade-offs, explain
the decisive evidence and uncertainty, and state what would change the conclusion.
Include prioritized critic findings and verification gaps using hyper-review's
evidence standards. If evidence cannot distinguish the alternatives, say so and
identify the smallest useful next investigation instead of forcing a winner.

Add a concise account of
the rounds and critic perspectives actually completed, what later rounds changed,
their coverage, and any unavailable or failed work. Explain material disagreements
and how they were resolved or what would resolve them. Retain finding IDs for
traceability without dumping the entire working register. Prioritize recommendations
by impact, confidence, and cost,
and distinguish implementation status from verification status where applicable.

Deliver one coherent assessment, not concatenated critic reports. Be explicit
about whether all three rounds and any needed follow-ups completed; never claim
full multi-critic coverage when only a fallback analysis was possible. When
material candidate findings or alternatives were investigated and rejected,
include a short rejected-candidates summary with the candidate and the disqualifying
evidence, so the funnel from suspicion to conclusion is visible without
reconstructing the working register.
