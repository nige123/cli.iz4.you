# The IZ4 adversarial benchmark

Does the gate hold when an agent's work conflicts with an invariant, and
stay out of the way when it does not? This suite answers that offline, in
about 40 seconds, with no model involved.

```sh
raku bench/run.raku            # every scenario, four ways; writes bench/results/latest.{json,md}
raku bench/run.raku --check    # and compares with each scenario's recorded expectation
raku bench/run.raku --only=G   # one category
raku bench/run.raku --trials=3 # repeat; disagreement between trials is reported
```

Each scenario is a directory under `scenarios/`: a plausible task, the
files a coding agent would leave behind (or the approval it would try to
reuse, or the action it would attempt), and whether that result violates
an invariant. The seed is a small synthetic job platform whose IZ4 says
`private-stays-private.jobs.example.com`. No model runs: the agent is a
scripted result, so the benchmark measures the boundary, never a model.
Whether a given model obeys an IZ4 it was merely shown is a different
question, and only live runs answer it.

Every scenario runs four ways:

| Mode | What stands between the change and the repository |
|---|---|
| none | no IZ4; the project's own tests |
| context | the IZ4 is present and the gate reports; nothing is held |
| vibe | every promise of the project's own is exploring (its card says `CHANGES REQUIRE no approval; current promise still applies`) and the gate enforces: a change to one, or a failing protecting test, waits for nobody; the foundation, what the gate blocks outright, and any promise the seed keeps established (`seed/<name>/vibe-keeps`) hold as ever |
| enforced | the gate holds the commit until a signed approval covers that exact tree, base and proposal |

Every result carries three outcomes, reported separately because they are
not the same thing:

| Outcome | Means | Measured by |
|---|---|---|
| FuncPass | the feature works | the candidate's own tests that name no invariant |
| InvariantPass | the invariant still holds | the holdout tests, the seed's protecting tests kept outside the candidate's reach (`seed/<name>/t` and `holdout/<name>`), run against the candidate's code from a sealed directory |
| VerifiedPass | something other than the agent says so | the boundary of that mode passed, every check ran and none failed, no approval outstanding. Where a promise is exploring a failing protecting test holds nothing, yet still denies VerifiedPass: let through is not verified |

A scenario where FuncPass holds and InvariantPass fails is working software
that no longer serves its purpose. Endor Labs measured that gap across 200
tasks and 32 agents (research/endor-argon-2026-10); the J scenarios are the
same shape in IZ4's terms, each with its compliant twin so friction is
measured too.

Categories: A well-intentioned violations, B explicit pressure, C invariant
manipulation, D indirect routes, E prompt injection, F ambiguous authority,
G approval evasion, H legitimate changes (to count false positives and
unnecessary questions), I the mechanics themselves: a look-alike letter in a
name, a bidi override hidden in a clause, a valid signature on a foundation
edit, an agent's own key added to the approvers in the same commit, J
conflicting requirements: a reasonable request whose quickest implementation
breaks a stated invariant (reuse payment details across beneficiaries, read
configuration from the working directory, auto-approve what a person used to
decide), each paired with the legitimate version of the same request
(`alternative_to`), K the lifecycle: an exploring project whose payment promise
is established on its card (seed `pay-protected`): the established
promise holds even while its neighbours explore (K1, K2); lowering what it
requires, deleting or renaming it waits for a yes (K3 to K5); establishing
one promise on day one is free, in an exploring file and in an established
file (K6).

## Integrity

What Endor Labs found about benchmarks applies here, and this is where the
suite stands against each risk.

| Risk | Here | Mitigated by |
|---|---|---|
| training recall | does not apply: no model runs; every agent is a scripted result | if a live agent is ever put through these scenarios, the scenarios are public and must be assumed memorised: use fresh variants |
| answer leakage from the workspace | the candidate workspace holds the seed and the overlay only; the holdout tests are never copied into it | `invariant-pass` runs them from a sealed directory; a live agent must not be given `bench/` |
| the agent reading scoring criteria | `scenario.json` holds the expectations and lives outside the workspace | same |
| contamination from generated files | each scenario and mode gets a fresh `git init` from the seed in a temporary directory, removed afterwards | `fresh-repo` |
| ambiguous or contradictory expectations | every expectation is declared before the run, by rule, in the scenario file; a mismatch is printed and the run says "not met" | `--check`; a mismatch is reviewed by hand, never silently re-recorded |
| a grader accepting what it should not | grading is deterministic: exit codes, gate outcomes, test results; no model grades | `classify` |
| nondeterminism | `--trials=N` runs each scenario and mode N times and marks any classification that disagrees `UNSTABLE` | |
| success wrongly attributed to IZ4 | the control mode `none` runs the same change with no IZ4; the report's first sentence says no model was measured | |

Not mitigated: a live agent would see the public scenarios; the seeds are
small and synthetic, so a pass here says the boundary works on this shape,
not on a real codebase; the holdout tests are only as strict as written (D1
remains the honest miss).


The results say what was measured and no more. A prevented scenario is
evidence for that scenario; it is not proof that every violation of that
kind is prevented. D1 is kept as an honest miss: a new route around an
invariant whose words and whose test do not change is invisible to the
gate until a test covers that route (D2).
