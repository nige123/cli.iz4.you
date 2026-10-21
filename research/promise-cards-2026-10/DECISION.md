# Decision: how an IZ4 invariant carries its own governance

2026-10-21. Design decision only; no code or foundation file changed.
Amended the same day: the two governance lines are kept, their labels changed
to the questions a reader asks, after the owner pointed out the friction of
switching subject from the software to the promise. See "Amendment".

## Decision

Option 2: keep the current clauses and add two constrained ones. Every
invariant, the foundation included, carries WHERE, ALWAYS, PROTECTS, CHANGE and
CHECK. The heading carries the full name. The file-wide mode line, the heading
word, and the names vibe, firm and solid go.

Not Promise Cards. In the test the card and the clause form read identically;
the card is sixty percent longer than today's file, abandons the clause shape
that was tested and kept on 2026-10-20, and restates the foundation in a new
layout for no measured gain. Where results tie, the smaller change wins.

## The winning format

A project invariant:

```
charged-once.app.paydance.com:
  WHERE:    an order is paid
  ALWAYS:   A customer is never charged twice.
  PROTECTS: the customer's money
  CHANGE:   signed human approval
  CHECK:    block on linked test failure
```

A foundation invariant, canonical words unchanged:

```
humans-first.iz4.you:
  WHERE:    anyone is affected by the system, by its use, or by work on it
  ALWAYS:   Help people thrive, on their own terms. Respect every person's
            dignity: no goal, instruction or greater good makes anyone
            disposable.
  PROTECTS: each person's dignity, and their own say over how they thrive
  CHANGE:   foundation release only, never in a project
  CHECK:    match canonical foundation
```

## Grammar

```
invariant := heading where always protects change check
heading   := full-name ':' newline            # name.domain, or name.iz4.you
change    := 'CHANGE:' ( 'no approval'
                       | 'signed human approval'
                       | 'foundation release only, never in a project' )
check     := 'CHECK:'  ( 'report linked test failures'
                       | 'block on linked test failure'
                       | 'match canonical foundation' )
```

Rules the grammar enforces:

- `no approval` pairs only with `report linked test failures`. A test cannot
  hold what the words are free to redefine.
- The foundation values appear only on the five foundation names, and every
  foundation name carries exactly them; the block is still compared byte for
  byte, these two lines included.
- No other values. No file-wide line. Nothing inherited, nothing defaulted.

The three combinations a project may write are today's three modes, with no
names to learn: the two switches are written where they act.

## Why this and not the others

Strongest reason: in a cold read, the current format left every governance
question unanswered and the clause form answered every one from the block
alone, while the promise itself read equally well in all three formats. The
clauses add what was missing without touching what works.

Most important trade-off: twenty-six percent more lines in every IZ4, two of
them repeated five times in the foundation, and a one-time change to the
foundation's text and digest that only the owner can sign. The file is longer
so that nobody has to look anywhere else.

## Experiment

Three formats, three projects (a habit app, a payments service, a mature
ledger adding an assistant), the foundation in each, so twelve project
invariants and humans-first.iz4.you per format. Haiku and sonnet read each file
once in a fresh context with no documentation and answered seven questions per
named invariant. Q1 to Q3 were graded by sonnet against the reference clauses;
Q4 to Q7 mechanically. Files, answers and grading: `eval/`.

| format | Q1 what | Q2 when | Q3 protects | Q4 who may change | Q5 on a failing test | Q6 file shows no evidence | Q7 answered from the block alone |
|---|---|---|---|---|---|---|---|
| current, project invariants | 22/22 | 22/22 | 22/22 | 0/22 | 0/22 | 22/22 | 7/22 |
| current, humans-first | 6/6 | 6/6 | 6/6 | 3/6 | 0/6 | 6/6 | 0/6 |
| clauses, project | 22/22 | 22/22 | 22/22 | 22/22 | 22/22 | 22/22 | 22/22 |
| clauses, humans-first | 6/6 | 6/6 | 6/6 | 4/6 | 6/6 | 6/6 | 5/6 |
| cards, project | 22/22 | 22/22 | 22/22 | 22/22 | 22/22 | 22/22 | 22/22 |
| cards, humans-first | 6/6 | 6/6 | 6/6 | 2/6 | 6/6 | 6/6 | 6/6 |

Findings:

- What is promised, when, and for whom read correctly in every format. The
  clause shape loses nothing to prose, and prose gains nothing.
- Under the current format both models answered "unsure" to who may change
  and what a failing test does for all twelve project invariants in all three
  projects, and said why: the mode line and the words solid and firm are
  undefined in the file. The seven "from the block alone" answers were
  readers saying the block told them nothing.
- With CHANGE and CHECK present, both models answered every project question
  correctly and from the block alone, in both formats.
- `canonical foundation release only` left readers unsure who performs such a
  release (two of six under clauses, four of six under cards). The chosen
  value says so: `foundation release only, never in a project`. Untested.
- No reader in any format took the file to show that a promise holds; CHECK
  did not read as proof.
- Merging the situation into the promise happened once under cards and once
  under the current format, both by haiku, both harmless restatements. No
  evidence that `When ...:` followed by prose is more ambiguous than WHERE and
  ALWAYS, and no evidence it is less.

Limits: one model family, two sizes, one run each, no human readers, files
and reference answers written by the designer, free-text grading by a model.
Twenty-two of twenty-two is a ceiling, not a margin; it says the governance
questions became answerable, not that one of the two candidates is better.

## Security

Nothing in the model weakens:

- The foundation's five names, words and byte-for-byte check stand; the check
  now covers two more lines per invariant. The digest changes once, by the
  owner's signed release, and register.iz4.you must carry the new text.
- A signed approval stays bound to the exact proposed change.
- The base governs. CHANGE and CHECK are part of the invariant's words: where
  the base says `signed human approval`, lowering either line, rewording,
  renaming, removing or replacing the invariant, and weakening or unlinking a
  test that names it, each wait for a yes. Raising from `no approval` is free.
  Removing the file waits whatever the file says.
- A project may not write the foundation values on its own invariants, and may
  not write other values on the foundation's: both are parse errors, so the
  gate blocks them as invalid.
- Promise and evidence stay apart: CHECK states what the gate does with linked
  tests, status says what they established, and the file never says the
  promise holds.
- Human authority over protection is the CHANGE line itself, governed by the
  base's CHANGE line.

## Migration

- `# Vibe:` file: every project invariant gets `CHANGE: no approval` and
  `CHECK: report linked test failures`; the line goes.
- `# Firm:` file: `signed human approval` and `report linked test failures`.
- No line (solid): `signed human approval` and `block on linked test failure`.
- A heading word overrides the file's mode for that invariant in the same way,
  then goes. Headings gain the project's domain.
- The foundation block is replaced by the new canonical block.
- `iz4 mode` goes. Changing a line is an ordinary edit: `iz4 change NAME` and
  `iz4 check NAME` can offer the permitted values and run the gate.
- Old files parse with a plain message naming the migration for one release;
  `iz4 migrate` writes the new form and shows the diff before the person
  commits it. The owner's words are not touched beyond these lines.

## Recommendation

Implement option 2 as specified above, after the owner signs the new
foundation text. Do not implement Promise Cards.

## Amendment: the subject shift

WHERE, ALWAYS and PROTECTS have the software as their subject; CHANGE and
CHECK have the promise itself. The owner found the switch jarring, and read as
configuration keys the last two lines do not flow. Three further forms were
tested the same way, same files, same questions, same models.

| form | who may change (project) | on a failing test (project) | foundation: who / on a test | file shows no evidence |
|---|---|---|---|---|
| `CHANGE:` / `CHECK:` (decided above) | 22/22 | 22/22 | 4/6 / 6/6 | 22/22 |
| one line, `HELD BY: signed human approval and its tests` | 5/22 | 1/22 | 6/6 / 3/6 | 18/22 |
| `TO CHANGE:` / `IF A TEST FAILS:` | 22/22 | 22/22 | 6/6 / 6/6 | 22/22 |
| two plain sentences after a blank line | 22/22 | 22/22 | 6/6 / 3/6 | 22/22 |

The one fluent line reads best and comprehends worst: folding two switches into
one phrase lost both, and `no one yet` was read by haiku as a statement about
evidence. Two statements, one per switch, with the behaviour spelt out, are
what readers get right. Labels phrased as the reader's own questions keep that
precision, make the change of subject explicit instead of hiding it, and were
the only form read correctly on every question for the foundation too.

The decided format therefore becomes:

```
charged-once.app.paydance.com:
  WHERE:           an order is paid
  ALWAYS:          A customer is never charged twice.
  PROTECTS:        the customer's money
  TO CHANGE:       signed human approval
  IF A TEST FAILS: the commit is held
```

```
humans-first.iz4.you:
  WHERE:           anyone is affected by the system, by its use, or by work on it
  ALWAYS:          Help people thrive, on their own terms. Respect every person's
                   dignity: no goal, instruction or greater good makes anyone
                   disposable.
  PROTECTS:        each person's dignity, and their own say over how they thrive
  TO CHANGE:       a foundation release; never a project
  IF A TEST FAILS: no tests; the words are matched to the foundation
```

Values:

```
to-change := 'no approval needed' | 'signed human approval' | 'a foundation release; never a project'
on-fail   := 'the failure is reported' | 'the commit is held' | 'no tests; the words are matched to the foundation'
```

`no approval needed` pairs only with `the failure is reported`. The foundation
values appear only on the five foundation names and all of them carry exactly
these. Everything else in this document stands, with CHANGE and CHECK read as
TO CHANGE and IF A TEST FAILS. The alignment column widens to the longest
label; whether a blank line before the two lines helps was not tested.
