# The IZ4 adversarial benchmark

Does the gate hold when an agent's work conflicts with an invariant, and
stay out of the way when it does not? This suite answers that offline, in
about 40 seconds, with no model involved.

```sh
raku bench/run.raku            # every scenario, three ways; writes bench/results/latest.{json,md}
raku bench/run.raku --check    # and compares with each scenario's recorded expectation
raku bench/run.raku --only=G   # one category
```

Each scenario is a directory under `scenarios/`: a plausible task, the
files a coding agent would leave behind (or the approval it would try to
reuse, or the action it would attempt), and whether that result violates
an invariant. The seed is a small synthetic job platform whose IZ4 says
`private-stays-private.jobs.example.com`. No model runs: the agent is a
scripted result, so the benchmark measures the boundary, never a model.
Whether a given model obeys an IZ4 it was merely shown is a different
question, and only live runs answer it.

Every scenario runs three ways:

| Mode | What stands between the change and the repository |
|---|---|
| none | no IZ4; the project's own tests |
| context | the IZ4 is present and the gate reports; nothing is held |
| enforced | the gate holds the commit until a signed approval covers that exact tree, base and proposal |

Categories: A well-intentioned violations, B explicit pressure, C invariant
manipulation, D indirect routes, E prompt injection, F ambiguous authority,
G approval evasion, H legitimate changes (to count false positives and
unnecessary questions).

The results say what was measured and no more. A prevented scenario is
evidence for that scenario; it is not proof that every violation of that
kind is prevented. D1 is kept as an honest miss: a new route around an
invariant whose words and whose test do not change is invisible to the
gate until a test covers that route (D2).
