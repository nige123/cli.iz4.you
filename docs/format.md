# The IZ4 file

One plain-text file, `IZ4`, at the root of your project. This is a whole one,
with the foundation shortened:

```text
IZ4 jobs.example.com

IS FOR WHAT?  Helping people find work they love to do.
IS FOR WHO?   People looking for work.

private-stays-private:
  WHERE:    a profile marked private could reveal anything beyond its owner
  ALWAYS:   Only its owner, and the people they choose, may learn what it
            reveals.
  PROTECTS: the owner's privacy, and their control over who learns they are
            looking

contact-by-invitation:
  WHERE:    an employer would contact a job seeker
  ALWAYS:   No employer contacts a job seeker until that person has started
            the contact.
  PROTECTS: a job seeker's say over who may approach them

# ----------------------------------------------------------------------
# The foundation: the same words in every IZ4.

humans-first.iz4.you:
  WHERE:    anyone is affected by the system, by its use, or by work on it
  ALWAYS:   Help people thrive, on their own terms. ...
  PROTECTS: each person's dignity, and their own say over how they thrive
```

## What is in it

- **The header**: `IZ4` and the domain your project answers for. It is said
  once, so the names below can be short.
- **Two questions**, `IS FOR WHAT?` and `IS FOR WHO?`, each answered once.
- **Your invariants.** Each is a name and a colon, then three clauses:

  | Clause | Says | Write |
  |---|---|---|
  | `WHERE:` | where it applies | the situation, not who benefits and not "the system" |
  | `ALWAYS:` | what must remain true there | a state about the system, or a duty on whoever acts |
  | `PROTECTS:` | what must not be defeated | whose what, as a noun phrase, never a sentence |

  All three are required. `iz4 add` asks the three questions in that order.
- **The foundation**, last, behind a comment rule-off: the same invariants in
  every IZ4, word for word. `iz4 foundation` prints them; they are not yours
  to edit, and `iz4 check` says so if they change.
- **Plain characters only.** A line that carries an invisible or
  direction-changing character (a zero-width space, a right-to-left
  override) is an error: what a person reads must be what is stored.
- **Comments** start with `#` and may sit anywhere. A blank line ends a
  clause. Indentation is for the eye: a file with every line at column 0 reads
  the same.

## Names

- A name is lower-case words joined by hyphens: `private-stays-private`.
  Written in the file without the domain, it means
  `private-stays-private.jobs.example.com`; an area label comes along
  (`owner-adjusted.prices` under `honeywillow.com`).
- Cite the full name in tests, commits and reviews. A test is linked to an
  invariant by containing its full name.
- A name is for good. Withdrawing an invariant retires it; the same words
  under a new name are a new invariant.
- Names directly under `iz4.you` belong to the foundation.

## How to read an invariant

> All three clauses bind together. WHERE scopes; ALWAYS binds; PROTECTS
> decides what counts as keeping ALWAYS. None narrows or excuses another,
> and PROTECTS adds no duty of its own.

So `ALWAYS` holds throughout `WHERE` with no moment or pressure excepted,
whether or not what it protects seems at stake in the case at hand. Keeping
its words while defeating what it `PROTECTS` is a breach, and so is reaching
the forbidden outcome another way. `PROTECTS` can rule out an evasive reading
and create nothing else: a boundary counts only when `ALWAYS` states it. When
the words or the situation are genuinely unclear, pause what is affected, say
so, and return the decision to the people entitled to decide.

## For tools

The grammar is `lib/IZ4/ClausesGrammar.rakumod`, and the parser is that
grammar. `iz4 discover --json` gives each invariant with its full name and a
digest of its exact words (rule `iz4-invariant/4`: four lines, the identity
and the three clauses, whitespace collapsed, Unicode NFC, UTF-8). Re-wrapping
changes nothing; one changed word changes the digest.

More, including the thinking behind the three clauses:
[iz4.you](https://iz4.you).
