# How an invariant says how it is protected

Design exploration, 2026-10-21. Nothing here is implemented. The brief asked for
a design that lets a reader see, from one invariant alone and with the fewest
words, both what must remain true and how that promise is protected.

## The two switches behind the three levels

Everything the gate does with a project invariant comes down to two switches:

| switch | on | off |
|---|---|---|
| words | a change to the heading or clauses waits for a signed yes | a change waits for nobody |
| tests | a failing linked test holds the commit | a failing linked test is reported |

The three current levels are three of the four combinations. Vibe is both off,
firm is words on and tests off, solid is both on. The fourth (words off, tests
on) is pointless: a test cannot hold what the words are free to redefine.

So the real question is not "which three names" but "do we need the middle
combination, and where does the reader see the switches".

## What the cold read showed

Twenty files were written: four realistic projects (a habit app, a payments
service, a mature ledger adding an assistant, an infusion pump) in each of five
syntaxes. Two models (haiku, sonnet) read each file with no documentation and
said, for every project invariant, whether an agent may change its words
without a signed yes and whether a failing linked test holds the commit. A
second round gave each syntax its own one-paragraph legend. Scripts, files,
answers and grading are in `eval/`.

| syntax | marker | cold: right / wrong / unsure of 56 | with legend | legend words | places to look | lines added over the four files |
|---|---|---|---|---|---|---|
| S1 current | `# Vibe:` line, word on the heading raises one | 10 / 1 / 45 | 56 / 0 / 0 | 87 | 2 | 6 |
| S2 clause | `HOLD: vibe` / `firm` / `solid` | 6 / 1 / 49 | 56 / 0 / 0 | 55 | 1 | 14 |
| S3 word, two states | `name: draft`, bare is held | 6 / 0 / 50 | 56 / 0 / 0 | 48 | 1 | 0 |
| S4 clause that describes | `HOLD: the words and the tests` / `the words` / `nothing yet` | 28 / 0 / 28 | 54 / 0 / 2 | 30 | 1 | 14 |
| S5 word, three states | `name: draft` / `agreed`, bare is held | 10 / 0 / 46 | 56 / 0 / 0 | 56 | 1 | 0 |

Actual results:

- Cold, no marker word explains the gate. The models answered "unsure" and said
  why: the file states the promise, not who may edit it or what a failing test
  does. That is the honest reading. Only the clause whose values describe what
  is held (S4) reached half right.
- Both confident wrong answers came from `firm`: haiku read it as "settled" and
  concluded a failing test holds the commit. `vibe` was read as "weak or
  informal protection". `draft` was read as "a status distinct from the
  unmarked ones, but I cannot tell whether looser or stricter". `solid` was
  read as the strongest level by sonnet and as undefined by haiku.
- Without a marker (the pump file in S1 and S3) haiku twice inferred "held"
  from binding.iz4.you and human-agency.iz4.you; sonnet stayed unsure.
- With a legend every syntax is read correctly by both models. The two
  remaining unsure answers were sonnet wondering whether the foundation still
  requires approval for a `HOLD: nothing yet` invariant, a fair question.

Limits: one model family, two sizes, one run each, synthetic files written by
the same hand that designed the syntaxes, and the grader is the designer. The
cold round separates the syntaxes; the legend round does not, because a model
applies any stated rule. The legend round does measure how long each rule has
to be, and how many places a reader must look.

My judgement from this: the words on the marker will never carry the gate's
behaviour on their own. What a syntax can do is keep the rule short, keep it
in one place, and make the dangerous direction visible in a diff.

## The three strongest alternatives

### A. A fourth clause on every project invariant

```
charged-once:
  WHERE:    an order is paid
  ALWAYS:   A customer is never charged twice.
  PROTECTS: the customer's money
  HOLD:     the words and the tests
```

Values that describe the switches (`the words and the tests`, `the words`,
`nothing yet`) rather than name a level. This was the only syntax a cold
reader got half right, and its legend is the shortest.

Costs. One line on every project invariant: the four example files grow by
fourteen lines, about a quarter. And the clause is of a different kind from
its neighbours: WHERE, ALWAYS and PROTECTS would be true in any tool; HOLD is
only meaningful to iz4's gate. The brief's worry that this mixes human intent
with enforcement configuration is right, unless the clause is read as the
owner's own statement of how firmly they hold the promise.

The owner has said the foundation may carry the clause too (2026-10-21). That
removes the objection that the file would hold two shapes of invariant. It
means five more lines in every IZ4 and a one-time change to the foundation's
words and digest, signed by the owner. The foundation's value would have to
name a fourth state, since no yes can change it: something like
`HOLD: the words, in every IZ4` or `HOLD: always, unchangeable`.

### B. One word on the heading, two states

```
charged-once:
  WHERE:    an order is paid
  ALWAYS:   A customer is never charged twice.
  PROTECTS: the customer's money

receipts-are-kept: draft
  WHERE:    a payment completes
  ALWAYS:   A receipt is kept for every payment made.
  PROTECTS: a business's record of what it paid
```

A bare heading is held: its words wait for a signed yes and a failing linked
test holds the commit. The word `draft` marks the one state that differs:
its words may change without approval and a failing linked test is reported.
No file-wide mode. Nothing is inherited. The rule is one sentence.

The middle state goes. What it expressed (the words are agreed, the evidence
is not yet trusted) moves to where the evidence lives: a test counts only when
it names the invariant. A test the team does not yet trust does not name it,
and status shows the invariant as promised, not yet shown. Removing an
invariant's name from a protecting test already waits for a yes
(`protection-unlinked`), so the downgrade path is covered.

### C. One word on the heading, three states

As B, with `agreed` for the middle: words wait for a yes, tests are reported.
Keeps every behaviour of today's firm, drops the comment line and the
inheritance. `agreed` names what is agreed (the words) rather than how it
feels; cold, `firm` was the only marker that produced confident wrong
answers.

## Comparison

| | A clause | B word, two | C word, three |
|---|---|---|---|
| read from the invariant alone | yes | yes, with one constant rule for bare | yes, with one constant rule for bare |
| legend | 30 words | 48 words | 56 words |
| lines added per project invariant | 1 | 0 | 0 |
| states to learn | 3 | 2 | 3 |
| the dangerous direction in a diff | a changed value | a word appears | a word appears or changes |
| foundation and project invariants look alike | yes, if the foundation carries the clause | yes | yes |
| enforcement in the promise's clauses | yes | no | no |
| promise and evidence kept apart | partly: `the words` carries evidence trust | yes | partly |

## Is the middle state needed

Reasons to drop it:

- It puts a property of the evidence (not trusted yet) on the promise. The
  brief asks for a clear distinction between a promise and evidence that it
  holds; the link between a test and an invariant is already that line.
- It was the hardest state to name (eight candidates rejected) and the only one
  misread with confidence in the cold round. A state that resists naming and
  invites misreading is a candidate for removal.
- The two-state form has the shortest heading-word legend and the fewest
  things to hold in mind: held or draft.

What it costs: a linked test that is red but does not block. Under two states
a team with a failing protecting test on a held invariant must fix the test,
fix the software, or get a yes to unlink it. A new test that names a held
invariant and fails cannot be committed red. For invariant tests that is
arguably right (they pin what already holds), but it is a real change of
habit.

## Names

Clause name, if a clause is used: HOLD. PROTECTION and GUARD sit next to
PROTECTS and share its stem while meaning something else. GATE and LEVEL make
the file about the tool. STRENGTH suggests the quality of the promise. HOLD
pairs with the tool's own language (held, holds the commit, the marks' legend)
and takes self-describing values. `HOLD: vibe` does not make sense: HOLD asks
how firmly or by what, and vibe answers what mood.

Values. The held state needs no word in B and C. For the open state:

| word | for | against |
|---|---|---|
| draft | ordinary English for "not final, may change"; fine for non-native readers and auditors | cold, read as "different" rather than "looser"; an agent might read it as "not binding yet" |
| vibe | the existing word; cold, read as "weak or informal" | slang; jars in a payments or safety file read by an auditor |
| settling | the word the tool already uses in prose | odd as a tag on a heading |
| provisional, tentative | precise | long |

`draft`, with one sentence in the format doc: a draft invariant still binds
the agent; what differs is that its words may change without a signed yes and
its tests do not yet hold the commit.

## Recommendation

B. One word on the heading, two states, bare is held.

With the foundation allowed to carry a clause, A is a real alternative and the
choice is narrower than the brief's premise made it: A has no implicit default
and read best cold; B has the fewest words, adds no line to any invariant or to
the foundation, and keeps enforcement off the promise's clauses. I still prefer
B, because the central question asked for the fewest words and because a rule
of one sentence is cheaper than a line read before every change in every
file. If A is chosen, use the describing values, not level names, and give the
foundation its own fixed value.

Exact syntax, as a grammar rule and as prose:

```
heading  := name ':' [ ' ' 'draft' ]? newline
```

- `name:` is held. A change to its heading or clauses, its removal or
  replacement, a word appearing after its heading, and the weakening or
  unlinking of a test that names it, each wait for a signed yes bound to the
  change. A failing test that names it holds the commit.
- `name: draft` may change without approval; the gate prints one line saying
  what changed. A failing test that names it is reported. Removing the word is
  free.
- What governs a change is the base, never the candidate.
- The foundation carries no word and admits none.
- The `# Vibe:` and `# Firm:` lines, `iz4 mode`, and the words `firm` and
  `solid` go. `iz4 draft NAME` adds the word (waits for a yes), `iz4 hold NAME`
  removes it. `iz4 add` writes `draft`, since a first wording is a draft;
  status names the drafts and shows `iz4 hold NAME` as the next command.

Migration: a `# Vibe:` file gets `draft` on every bare project invariant and
loses the line. A `# Firm:` file loses the line; its invariants become held,
which is one change of behaviour (their tests now hold), and the tool should
say so and offer `iz4 draft NAME`. `: solid` and `: firm` become bare, with
the same note for firm.

The four realistic files in this syntax are `eval/files/S3-word-draft--*.IZ4`.
The pump file carries no marker at all; the habit app marks all three; the
payments file marks two of four; the ledger marks only the assistant's.

## The strongest argument against this recommendation

It removes the only state in which a failing protecting test is linked,
visible to everyone, and not blocking. Teams with slow or flaky invariant
tests will be pushed one of two ways: leave the test unlinked, so status shows
a question mark and nobody sees the red, or mark the invariant draft, which
frees the words when the problem was the evidence. The first is the quiet
loss of evidence the tool exists to prevent; the second uses the wrong lever.
Firm existed for exactly this phase, and the lifecycle brief named it as a
state real projects occupy.

Two smaller ones. Bare is held makes every hand-written invariant maximally
strict, so a pre-MVP owner who forgets the word meets a signature request on
a typo; the fail-safe default costs most where the vibe idea came from. And
`draft` risks being read by an agent as "not yet in force", licensing it to
ignore the invariant rather than merely edit its words; the cold round shows
the word carries direction less well than `vibe` does.

If the middle state is kept, C is the form: `name: agreed`, not `firm`.
