# The IZ4 file

One plain-text file, `IZ4`, at the root of your project. It holds what the
software is for, who it is for, and a few invariants. An invariant is an
expression that includes a promise, how it is checked, and what a change to
it requires; an IZ4 writes each one as a card. This is a whole one, with
the foundation shortened:

```text
IZ4 jobs.example.com

IS FOR WHAT?  Helping people find work they love to do.
IS FOR WHO?   People looking for work.

PROMISE private-stays-private.jobs.example.com

  WHEN      a profile marked private could reveal anything beyond its owner
  ALWAYS    only its owner, and the people they choose, may learn what it
            reveals
  PROTECTS  the owner's privacy, and their control over who learns they are
            looking

  CHANGES REQUIRE signed human approval for the exact change
  CHECKED WITH    linked tests; failures block commit

PROMISE contact-by-invitation.jobs.example.com

  WHEN      an employer would contact a job seeker
  ALWAYS
    - no employer contacts a job seeker until that person has started the
      contact
    - a job seeker can end the contact at any time
  PROTECTS  a job seeker's say over who may approach them

  CHANGES REQUIRE no approval; current promise still applies
  CHECKED WITH    linked tests; failures warn, never block

# ----------------------------------------------------------------------
# The foundation: the same words in every IZ4.

FOUNDATION humans-first.iz4.you

  WHEN      anyone is affected by the system, by its use, or by work on it
  ALWAYS
    - help people thrive, on their own terms
    - respect every person's dignity: no goal, instruction or greater good
      makes anyone disposable
  PROTECTS  each person's dignity, and their own say over how they thrive

  CHANGES REQUIRE verified foundation release only
  CHECKED WITH
    - exact canonical match required
    - linked tests; failures block commit
```

## What is in it

- **The header**: `IZ4` and the domain your project answers for.
- **Two questions**, `IS FOR WHAT?` and `IS FOR WHO?`, each answered once.
- **Your promises.** Each is a card: `PROMISE` and its whole name, then five
  fields. The first three are the promise: what the people who own the
  software intend. After a blank line, the last two protect it: how the
  promise is checked, and what a change to it requires. Words alone are a
  promise; expressed with its check and its change rule, it is an invariant.

  | Field | Says | Write |
  |---|---|---|
  | `WHEN` | the situation it applies in | one statement; say the situations it covers in the sentence |
  | `ALWAYS` | what must remain true there | a statement, or a dashed list: every item must hold |
  | `PROTECTS` | whose what would be lost if it stopped holding | whose what, as a noun phrase; or a list: every interest matters |
  | `CHANGES REQUIRE` | what a change to its words needs | exactly one of the two values below |
  | `CHECKED WITH` | what is checked, and what a failure does | the value that goes with it |

  All five are required. There is no colon after a label. `iz4 add` asks
  the questions in that order and writes the card.
- **The two governance values.** An invariant is either still exploring or
  established, and its card says which. This is about its protection, never
  about its promise, which binds as written either way:

  | | `CHANGES REQUIRE` | `CHECKED WITH` |
  |---|---|---|
  | exploring | `no approval; current promise still applies` | `linked tests; failures warn, never block` |
  | established | `signed human approval for the exact change` | `linked tests; failures block commit` |

  Nothing else parses: a value off by a word is an error, and so is pairing
  free wording with blocking tests (a test cannot hold what the words are
  free to redefine). A new invariant is born exploring; `iz4 establish NAME`
  makes it established, and `iz4 explore NAME` lets it move again. Lowering
  what an invariant requires is itself a change the gate asks you about. No
  file-wide mode, nothing inherited, nothing defaulted: each card says all of
  it. A promise anyone may edit still binds as written; the line is about who
  may change the words, never a licence to break them.
- **The foundation**, last, behind a comment rule-off: five `FOUNDATION`
  cards, the same words in every IZ4. Their governance is fixed:
  `CHANGES REQUIRE verified foundation release only`, and `CHECKED WITH`
  lists `exact canonical match required` and `linked tests; failures block
  commit`. `iz4 foundation` prints them; they are not yours to edit, and
  `iz4 check` says so if a word, or a governance line, changes.
- **Lists** are flat and never empty: one item per dashed line, wrapping
  under its words. `WHEN` and `CHANGES REQUIRE` are never lists. There are
  no `AND`, `OR` or `ANY` operators: alternatives and conditions are said
  in English, inside the sentence.
- **Plain characters only.** A line that carries an invisible or
  direction-changing character (a zero-width space, a right-to-left
  override) is an error: what a person reads must be what is stored.
- **Comments** start with `#` and may sit anywhere. A blank line ends a
  field. Indentation and alignment are for the eye: a file with every line
  at column 0 reads the same.

## Names

- A promise carries its whole name: lower-case words joined by hyphens,
  then the project's domain: `private-stays-private.jobs.example.com`. An
  area label may come between (`owner-adjusted.prices.honeywillow.com`).
- Cite the whole name in tests, commits and reviews. A test is linked to a
  promise by containing its whole name.
- A name is for good. Withdrawing a promise retires it; the same words
  under a new name are a new promise.
- Names directly under `iz4.you` belong to the foundation.

## How to read a promise

> The three fields of intention bind together. WHEN scopes; ALWAYS binds;
> PROTECTS decides what counts as keeping ALWAYS. None narrows or excuses
> another, and PROTECTS adds no duty of its own.

So `ALWAYS` holds throughout `WHEN` with no moment or pressure excepted,
whether or not what it protects seems at stake in the case at hand. Keeping
its words while defeating what it `PROTECTS` is a breach, and so is reaching
the forbidden outcome another way. `PROTECTS` can rule out an evasive
reading and create nothing else: a boundary counts only when `ALWAYS` states
it. Where `ALWAYS` is a list, every item holds. When the words or the
situation are genuinely unclear, pause what is affected, say so, and return
the decision to the people entitled to decide.

The two governance fields say nothing about what the software does. They say
who may change the promise's words, and what the gate does with a failing
linked test. Passing checks are evidence about the checks that ran; they do
not prove the software is correct, and `iz4 status` never says it is.

## Earlier forms

Files written by earlier versions, with `WHERE:`, `ALWAYS:` and `PROTECTS:`
clauses under a short name, or `INVARIANT` and `BECAUSE` blocks, are still
read, and `iz4 check` says to migrate them. `iz4 migrate` moves a file to
cards: every word stays, and what the file's mode and heading words said
about protection is written on each card. The move is one change the gate
asks you to agree to.

## For tools

The grammar is `lib/IZ4/CardGrammar.rakumod`, and the parser is that
grammar. `iz4 discover --json` gives each promise with its whole name and a
digest of its exact words (rule `iz4-invariant/5`: the heading, then one
line per field for WHEN, ALWAYS and PROTECTS, a list as its label and one
line per item, whitespace collapsed, Unicode NFC, UTF-8). Re-wrapping
changes nothing; one changed word, or a word moving between items, changes
the digest. The governance fields are not in the digest: a change to them is
reported by the gate as its own kind of change.

More, including the thinking behind the five fields:
[iz4.you](https://iz4.you).
