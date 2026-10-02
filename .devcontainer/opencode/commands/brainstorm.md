---
description: Generate specific, diverse ideas with useful picks and unconventional alternatives; light, medium (default), or heavy
---

Run a divergent ideation pass for this request:

$ARGUMENTS

Parse the first word as the level when it is `light`, `medium`, or `heavy`
(case-insensitive) and use the remaining text as the topic. Otherwise use
`medium` and keep the entire argument text as the topic. If no topic is supplied,
use the conversation's established subject; if none is clear, ask what to
brainstorm. Vague topics are fine — breadth is the goal.

## Shared rules

- Carry the user's goal, relevant conversation context, explicit constraints,
  and no-write boundary into every tool query and delegated task. State only
  material assumptions; do not turn a vague seed into an interview.
- Keep explicit requirements binding for useful ideas. Framing-breaking ideas
  may challenge assumptions; ideas requiring a user constraint to change belong
  in the crazy list, labeled **outside current constraints** with that change
  named. Never silently relax requirements.
- Explore different mechanisms, users, contexts, and cross-domain analogies.
  Include at least three ideas that break or invert the framing. Prefer specific
  actions or concepts over slogans; skip generic caching, docs, or tests unless
  they address the actual topic. Apply these rules at every level.
- Generate broadly before selecting. Deduplicate by underlying mechanism across
  both lists; variations of the same feature are one idea. Rank useful ideas by
  relevance and plausible value under the stated constraints, preserving distinct
  approaches. Selection and effort labels are provisional, not validation.
- This is ideation: never implement, write files, or run critics, roundtables,
  or stress tests. Recommend `/hyper-analyze` for decision analysis or a planning
  workflow for a chosen idea (`/ulw-plan` when available); do not invoke them.

## Output

Return one concise response with these two lists:

- **Most useful ideas** — aim for 7–10 ranked ideas, one line each: a specific
  idea, its value, and an effort tag (`now`, `needs development`, or `moonshot`).
  If feasibility depends on missing facts, say so rather than guessing.
- **Crazy ideas** — aim for 3–5 unconventional ideas, one line each: a specific
  idea and its key enabling condition, including any required constraint change.

Do not pad either list to meet a count; briefly explain a material shortfall.
End with at most three questions about user decisions that would most change
the direction; omit them when none are useful. Heavy also adds a short evidence
map before the questions. Mention reduced coverage when a stage was unavailable
or failed; never claim tool or survey work that did not complete.

## Level: light — fastest, no tools

Ideate and select directly, without tool calls. Apply all shared rules.

## Level: medium (default) — one chorus pass

If available and permitted, call `chorus` with `query` containing the topic,
context, constraints, and a request for specific, diverse, framing-breaking
ideas; use `maxRounds: 3`. Consider the full harvest before selecting, including
less prominent themes. If unavailable or failed, retain any usable output and
finish through direct ideation. Do not retry failed orchestration.

## Level: heavy — grounded and double-passed

Run in this order, keeping at most one delegated background task running.
Round counts are upper bounds; accept early completion. Heavy explores more
deeply, not through longer final lists.

1. If available and permitted, dispatch one background `librarian` task to
   survey existing and adjacent-domain approaches, including documented failed
   attempts. Bound the survey to 3–5 relevant sources actually read, preferring
   primary sources; request concise findings, source links, and gaps. Require
   no file writes. If delegation is unavailable or fails, survey directly with
   available research tools under the same scope. If research is unavailable,
   proceed with ideation and explicitly mark the grounding gap.
2. While a delegated survey runs (or after a direct survey), call `chorus` when
   available and permitted, with the medium query guidance and `maxRounds: 5`.
   Otherwise generate a broad first harvest directly.
3. After collecting the survey's findings or failure status, use one second
   `chorus` pass with `maxRounds: 3` if available, permitted, and the first call
   succeeded; otherwise use a direct second pass. Seed it with the usable survey
   findings and first harvest; request missing mechanisms,
   cross-domain analogies, and framing-breaking ideas under the shared constraint
   rules. If either chorus call fails, keep usable output and finish directly;
   do not retry failed orchestration or add more passes.
4. Merge and select under the shared rules. Add a compact evidence map linking
   the relevant ideas to sources actually read. Distinguish documented precedent,
   contrary evidence, and unverified extrapolation; an analogy is not proof of
   feasibility. Leave unsupported ideas explicitly unverified.

State which stage is running during substantial work. Do not claim a grounded
heavy result when the survey did not complete.
