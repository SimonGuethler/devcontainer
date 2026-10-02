---
name: hyper-research
description: Comprehensive, hallucination-resistant research on a topic or idea — gathers, verifies, and cross-checks relevant information and delivers a claim-evidence-backed synthesis. Use for hyper-research or when asked to thoroughly research a topic, idea, technology, question, or state of the art; use hyper-analyze to decide between options and hyper-review to assess a concrete artifact.
---

# Hyper-research

Start with the topic or idea and why the user needs it. Build a verified
knowledge base: comprehensive coverage of what is actually known, not a
decision, an assessment, or a long report. Depth comes from tracing claims to
evidence and resolving contradictions, not from search volume or report length.

Hyper-research complements `hyper-review` (assesses a concrete artifact) and
`hyper-analyze` (supports a decision or comparison). When the request turns
into choosing between options, recommend hyper-analyze; when it turns into
evaluating something that exists, recommend hyper-review. Do not silently
switch workflows.

## Establish the research scope

- Identify the topic, purpose, audience, and constraints (time, cost, breadth
  vs depth). State material assumptions; ask only for missing information that
  changes the research. Continue independent work meanwhile.
- Decompose the topic into sub-questions and the claims that would change the
  user's conclusions. Prioritize by impact and uncertainty; research the
  highest-impact unknowns first.
- Record scope and coverage compactly: sub-questions, searches run, sources
  read (with access date where relevant), open questions, and exclusions, so a
  long investigation does not silently lose scope.
- Stop the research when every sub-question has a supported answer or the
  remaining uncertainty needs unavailable evidence or a user decision; do not
  repeat searches without a concrete new lead.
- Research does not authorize repository edits. Save deliverables only where
  the user requested them; honor the active agent's write boundaries.

## Gather sources

- Use the available search, fetch, scholarly, documentation, and code tools as
  appropriate. Combine discovery (search engines, paper search, code search)
  with actual reading of the best sources. When delegation is available and
  permitted, use a librarian or explore specialist for external documentation
  or codebase context; keep write boundaries intact.
- Prefer primary sources: official documentation matching the relevant
  version, papers, specifications, standards, source code, official
  announcements, and raw data. Judge provenance rather than format: a
  firsthand technical report may be primary evidence. Use credible secondary
  sources when primary material is unavailable or they add useful synthesis;
  label that reliance and its limits. Treat aggregators and AI-generated pages
  as discovery leads until their claims are checked against original sources.
- Search for what would disprove the emerging answer while gathering, not
  only sources that support it; selection bias forms early.
- Chase citations in both directions for pivotal sources: what they build on
  and who cites them, including critiques. Treat links as perishable — for
  decisive but dead or moved pages, consult a web-archive snapshot and label
  it as such.
- Read sources after discovery. Search snippets, abstracts, and titles do not
  support claims about full content. Keep private material and secrets out of
  queries and URLs.

## Verify and resist hallucination

This is the core contract. Every factual claim in the deliverable must trace
to material actually accessed in this session.

- Cite only sources actually read this session — fetched pages, read files,
  PDFs, or API results. Never reconstruct a citation, quote, number, author,
  date, URL, or DOI from memory; verify identifiers against the source before
  using them. If verification fails or is impossible, say so rather than
  guessing.
- Distinguish established findings, attributed source claims, and your own
  inferences. Separately note source status (e.g., peer-reviewed, preprint, or
  vendor marketing) where it affects confidence; publication status alone does
  not establish a claim. Mark verbatim quotations as such; paraphrases must
  preserve meaning.
- Corroborate decisive claims with independent sources. Repetition of one
  origin (same press release, same dataset, cross-posted content) is not
  corroboration. Duplicates, translations, and mirror pages do not count as
  independent evidence. If independent corroboration is unavailable, identify
  the single-source basis and limit the claim accordingly; do not invent
  agreement or keep searching without a concrete lead.
- Reconcile contradictions explicitly: check dates, versions, methods, and
  context. Report unresolved conflicts with both sides instead of silently
  picking one. Check publication status; label preprints, retractions, and
  superseded versions.
- Match claims to the accessed material: an abstract does not establish
  full-text findings; a homepage does not establish API behavior; a changelog
  does not establish current behavior. State when the full text or source was
  unavailable.
- Never fill gaps with plausible-sounding content. If evidence is missing,
  write "unknown/unverified" and name the smallest check that would resolve
  it. Track confidence per claim (high/medium/low) where it affects use.
- Recompute derived numbers where practical: percentages, growth rates, and
  comparisons should be recalculated from the underlying figures rather than
  only quoted; report a mismatch instead of adopting either silently.

## Verification panel

Trigger the adversarial claim-verification panel when a wrong claim would be
costly: load-bearing numbers, health, safety, security, legal, or financial
claims, claims feeding a decision, or an explicit request for high rigor.
For other requests, a direct verification pass over decisive claims is usually
enough. Respect explicit time and cost limits, and confirm delegation is
available and permitted before planning a panel.

Independent verification tasks challenge the draft claims and their evidence.
Keep the panel bounded to claims; use hyper-analyze for decisions.

- Use at least two independent verification tasks with distinct lenses:
  source-forensics (does the source support the claim, and is it credible and
  current?) and contrary-evidence (what evidence contradicts or limits it?).
  Every decisive claim must receive both checks; partition less consequential
  claims to control cost. Include coverage gaps in the assignments.
  Map tasks to actual available, permitted agents; separate tasks may use the
  same agent type. Use fresh contexts without earlier verifier verdicts, and
  do not present a continuation or self-critique as independent verification.
- Give each agent its assigned claims, citations, scope, and tool/write
  boundaries, without the coordinator's preferred verdict. Ask for verdicts
  (supported / overstated / contradicted / unverifiable) with evidence, not
  opinions; include the contrary evidence, not only what fits. Request
  counterexamples and overlooked failure paths without demanding a defect.
- Classify and resolve verdicts: supported claims keep their citations;
  overstated claims get narrowed wording; contradicted claims are corrected
  with the better source or dropped; unverifiable claims are moved to the
  open-questions section with the smallest next check. Reconcile conflicting
  verdicts by re-reading the decisive sources yourself.
- Collect results before claiming completion. If a task fails, retry only
  with a changed approach or use a permitted substitute. If delegation is
  unavailable, forbidden, or yields fewer than two independent results,
  complete the missing checks directly and report the reduced coverage and
  reason. Disclose unavailable checks; do not claim a completed panel.
- Preserve panel provenance in the deliverable: tasks actually completed,
  claims and lenses covered, verification limits, and remaining disagreements.
- Stop when every surviving decisive claim has received both checks and
  material disputes are resolved or require unavailable evidence. Recheck
  materially revised claims; do not repeat rounds without a concrete lead.

## Synthesize

- Organize by sub-question or theme, not by source or tool transcript. Lead
  the reader from the question to the answer, not through the search history.
- Map material claims to evidence: claim, source(s) with location (URL, page,
  section, commit), and confidence. A compact table works well for many small
  claims; inline references for a few decisive ones.
- Cover what is solidly established, competing views and why they disagree,
  notable gaps and open research questions, and practical implications for the
  user's stated purpose. Include relevant versions and dates so findings age
  visibly.
- Separate observed evidence from interpretation. A narrative that fits the
  data is not a demonstrated mechanism; when sources support competing
  explanations, present them as competing rather than choosing silently.
- For follow-up research, establish what changed since the previous pass:
  recheck affected sources, mark prior findings as confirmed, outdated, or
  unverifiable, and reuse unaffected evidence already accessed in this session
  only while its assumptions hold. In a new session, reopen supporting sources
  before relying on prior findings; earlier reports are leads, not substitutes
  for source access. Disclose sources that cannot be reopened.

## Deliver the research

Lead with the key findings and the direct answer to the question, then the
structured detail. Make every decisive claim easy to check with exact
references. Stamp the research with its date ("as of ...") so readers can
judge how current it is. Report separately: searches and checks actually run,
sources that could not be accessed, material exclusions, and ranked open
questions with the smallest next check for each. If coverage is thin or
sources conflict materially, describe the uncertainty and its effect on the
answer. Quantify it only when supported by data or a documented method.

Be thorough in the investigation and concise in the report. No padding, no
speculative filler, no exhaustive tool transcript.
