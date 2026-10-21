# Working software is not necessarily software that still serves its purpose

Research note, 2026-10-21. What Endor Labs found when it ran Gemini 4 Argon
through its coding-agent security benchmark, verified against the sources,
and what that does and does not say about IZ4.

Endor Labs evaluated coding agents. It did not evaluate IZ4, and nothing
below should be read as a result about IZ4.

## Sources

- Endor Labs, "Gemini 4 Argon on Cursor: solid security score, two unique
  solves, but slower and more expensive", 2026-10-20.
  https://www.endorlabs.com/learn/gemini-4-argon-on-cursor-solid-security-score-two-unique-solves-but-slower-and-more-expensive
- Endor Labs, Agent Security League (the benchmark; extends SusVibes from
  Carnegie Mellon). https://www.endorlabs.com/research/ai-code-security-benchmark
- Hacker News, "Gemini 4 Argon" thread. https://news.ycombinator.com/item?id=50073879
  Read in full. It discusses the model's launch and general coding quality;
  it does not discuss the Endor benchmark, its contamination findings or
  its grading. It is listed here because the brief named it, not as
  evidence for anything below.

## What was found

| figure | value | basis |
|---|---|---|
| functional pass (FuncPass) | 78.8% | memorised solutions removed |
| security pass (SecPass) | 29.0% | memorised solutions removed; tied top on Cursor |
| the same two with memorisation kept | 93.3% / 41.9% | |
| cost, time | $765, 14.0 min median per task | Opus 5.5: $116, 2.2 min |
| contamination cases | 29 | 27 training recall, 2 workspace leakage |
| benchmark | 200 tasks, 108 Python projects, 77 CWE classes | |

**Functional is not secure.** FuncPass means the task's functional tests
pass. SecPass means the code also passes the security tests written for the
historically vulnerable spot the task touched. Across 32 agent and model
combinations the gap is 40 to 60 points: Cursor with GPT-5.5 is 84.9%
functional and 24.0% secure. Agents are asked only to follow security best
practice in general; nothing in the task names the specific property.

**Contamination.** 27 of 29 cases were training recall: the model wrote the
historical fix it had seen. Two were workspace leakage: the model found the
answer in the workspace. Scores are reported with these removed, which is
why the two columns above differ.

**A contradictory task.** The Jupyter Core task's own problem statement
told agents to include the current working directory in the configuration
search path, labelled "highest priority". The security test rejects exactly
that line. Most combinations did as instructed and failed SecPass; Argon
and one other omitted the line, which the reviewers attributed to recalled
fixed code, rejected as a unique solve, and logged as a dataset curation
issue. A grader can be wrong about the task as well as about the answer.

**Automation missed a leak; a person caught it.** The automated
anti-cheating pipeline cleared Argon's Django Registration fix. Manual
review of the trajectory found the agent had grepped a file inside the
pre-built `.tox` test environment, a workspace artefact, and the verdict
was overturned to workspace leakage. Two of Argon's four apparent unique
solves survived manual review.

## What this does and does not establish about IZ4

It establishes nothing about IZ4; no IZ4 was present. It does bear on
three things IZ4 claims to be for.

- **Passing tests is not keeping intent.** The benchmark measures, at
  scale, the gap IZ4's own benchmark was built around: the quickest
  implementation that satisfies the request can defeat a property nobody
  mentioned. Endor's property is "secure"; IZ4's is "whatever this project's
  owner said must remain true", which includes security where the owner
  said so. The gap is the same shape.
- **A general instruction does not carry.** "Follow security best practice"
  produced 29%. IZ4's bet is that a named, testable invariant beside the
  code, checked by something other than the agent, does better than a
  general instruction. The foundation-format experiment in this directory's
  neighbour found that showing models the foundation moved loophole
  resistance from 72% to 95% and the naming of the relevant invariant from
  25% to 78% (research/foundation-format/RESULTS.md); that is evidence about
  Claude models reading iz4.you's foundation, not about Endor's tasks.
- **Graders and benchmarks fail in known ways**: recall, leakage,
  contradictory expectations, an automated check that clears what a reader
  would not. IZ4's benchmark is offline and scripted, so training recall
  does not apply to it as it stands; the rest does, and the review in
  bench/README.md under "Integrity" lists what is mitigated and what is not.

## Implications

- **iz4**: the benchmark now reports three outcomes separately, FuncPass,
  InvariantPass and VerifiedPass, so that "the feature works" is never read
  as "the invariant held" or "the boundary verified it". Vibe mode is a
  fourth mode in the table, tested separately from protected development.
  Conflicting-requirement scenarios (category J) are the Endor shape in
  IZ4's terms: a reasonable request whose quickest implementation breaks a
  stated invariant, paired with the legitimate version of the same request
  so friction is measured too.
- **321**: a receipt says what ran and what changed; it should carry, when
  the gate ran, which of the three outcomes it established. That is a
  schema addition for the 321 owner to decide, not made here.
- **123.do**: a run's "done" that rests on functional tests alone is the
  Endor gap in a work harness. The result approval should be able to show
  the invariant and verified outcomes beside the functional one. Noted for
  the api.123.do owner; nothing changed here.

## Limits of this note

Figures are as published on 2026-10-20; the whitepaper was not read. The
HN thread adds nothing on methodology. Everything measured in this
repository is measured against scripted agent results, never a live model,
and the README of the benchmark says so on every report.
