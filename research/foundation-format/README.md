# Foundation format experiment

Which shape of the foundation's invariants is easiest for a person to
understand, hardest for a model to misunderstand, and impossible to read as
permission to defeat what it protects? This directory holds the experiment,
its scripts, its raw results and the blind review for people. It changes
nothing in the CLI, the foundation or the site. Results: `RESULTS.md`.
Recommendation and proposed text: `RECOMMENDATION.md`. Blind review for people: `human/blind-review.md` (key in `human/KEY.md`, read after answering).

## Candidates

Six structures, each written twice: once with the current sentences moved
into the new shape (`-equiv`, the structure experiment) and once with
shorter sentences (`-short`, the wording experiment). `A-min` is the
current structure cut to the CLI's own soft word limits (WHERE 15, ALWAYS
25, PROTECTS 20), to measure what those limits would cost.

| id | shape | labels |
|---|---|---|
| A | current, three clauses | WHERE / ALWAYS / PROTECTS |
| B | four arms | WHEN / WHO / MUST / WHY |
| C | rule and reason | RULE / BECAUSE |
| D | statement and reason | (statement) / BECAUSE |
| E | A with other labels | SCOPE / RULE / REASON |
| F | duty, bright lines, interest | ALWAYS / NEVER / PROTECTS |
| none | no foundation shown | control: the model's own priors |

Names, order and the `iz4.you` domain are the same in every candidate.
`variants/` holds all of them as they would appear in an IZ4 file.

## Controls

- `reference.md` lists 45 requirements (HF1…BI11) taken from the current
  text before any variant was written. `scripts/preserve.py` has a fresh
  opus context read one invariant of one variant at a time and mark each
  requirement present, weakened or absent. A variant that loses a
  requirement is not eligible, whatever else it scores.
- Two scenario sets, each locked by sha256 (`eval/LOCK-*`) before any model
  saw it: `base` (32 scenarios, the brief's categories plus comply cases)
  and `hard` (20 scenarios, each hinging on one specific sentence of the
  foundation, written after `base` saturated). The `hinge` field says which
  sentence. Expected answers were fixed before running.
- Every call is a fresh context: headless `claude -p` with user settings,
  hooks and MCP servers disabled and a 40-word system prompt, so nothing but
  the candidate text and the scenario reaches the model. Presentation order
  is shuffled per model with a recorded seed. The model is never told which
  format it is reading or that formats are being compared.
- Grading is mechanical (`scripts/grade.py`): decision in the accepted set,
  required invariants cited by name, protected party and obligated party as
  multiple choice with shuffled positions. No model grades the main
  measures. The revision test (`scripts/revise.py`) and the preservation
  check use a separate opus grader context that sees the reference list and
  the text, never the format name or the expected result of other calls.

## Measures

| brief weight | measure here |
|---|---|
| 30% correct application | `decision` on both sets, and `cite`, `protects`, `obligated` |
| 25% resistance to loopholes | `decision` on the loophole-kind scenarios (`loophole` column) |
| 25% human comprehension | `human/blind-review.md`, answered by people; no model stands in for them |
| 10% conciseness, readability | `scripts/measure.py`: words, longest clause, lines over 80 columns |
| 10% consistency, parsing | labels per format, whether iz4 0.24 parses it, diff shape |

## Reproducing

```sh
python3 -I scripts/preserve.py --model opus                      # eligibility
python3 -I scripts/run.py --set hard --models haiku,sonnet,opus \
        --formats none,A-equiv,F-short --reps 2 --seed 1          # resumable; raw JSON per call
python3 -I scripts/grade.py hard                                  # table + results/graded-hard.json
python3 -I scripts/revise.py --models haiku,sonnet --formats A-equiv,F-equiv
python3 -I scripts/measure.py
python3 -I scripts/blind.py                                       # rebuilds the blind review and its key
```

Needs the `claude` CLI signed in. Costs are recorded per call
(`cost_usd`, list price) in `results/raw-*/`.

## Limits

- One model family. Only Claude models (haiku, sonnet, opus) are configured
  on this machine; no Gemini or OpenAI access exists here. Any claim about
  "LLMs" below means these three.
- Scenarios and variants were written by the same author (a Claude session).
  Expected answers follow the current text's words; where the text is
  silent the scenario was not used.
- Human comprehension has no data until people answer the blind review.
  The overall score is therefore incomplete, by design.
- `-short` and `-min` are one author's attempt at shorter wording. A
  different writer would produce different losses.
