# The IZ4 file format

Three forms exist. The **three-arm form** is current: it is what `iz4 init`
writes, and it is described first. The **named form** of iz4 0.16 and 0.17
is still read and written, and the **numbered form** of 0.15 and earlier is
still read. Each is specified by a Raku grammar, and the parser is that
grammar: what it accepts is what this page describes. If the two ever
disagree, the grammar is right and this page is wrong. The three-arm grammar
is `lib/IZ4/ArmsGrammar.rakumod`; the others are `lib/IZ4/Grammar.rakumod`.

`iz4 migrate` moves a numbered file to the named form, and a named file to
the three-arm form. Nothing moves unless a person runs it.

## The three-arm form

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
  ALWAYS:   Help people thrive, on their own terms. Respect every person's
            dignity: ...
  PROTECTS: each person's dignity, and their own say over how they thrive
```

(The foundation is left short here; see [the foundation](foundation.md).)

An invariant says three things, and the form has a place for each:

| Arm | Answers | Written as |
|---|---|---|
| `WHERE:` | Where does this apply? | The situations it covers, named widely: not who benefits, not "the system" |
| `ALWAYS:` | What must remain true there? | A state about the system, or a duty on whoever acts; must, never and only are welcome; no moment or pressure excepted |
| `PROTECTS:` | What must not be defeated? | A durable interest or boundary, as a noun phrase: whose what, never a sentence |

Read aloud: "Where a private profile could reveal anything beyond its owner,
always: only its owner and the people they choose may learn what it reveals.
This protects the owner's privacy and control over disclosure." `iz4 add`
asks the three questions in that order. It is not a sentence pattern: the file
holds the three answers, each as its owner wrote it.

Voice differs on purpose. A project's invariants describe the system ("A
revoked session authenticates nobody"). The foundation speaks to whoever acts,
agent included ("Do not harm people"), because the reader is who it binds.
`ALWAYS` reads with both.

### How an invariant is read

One rule governs the three arms, and an agent is given it with the
invariants ([the agent protocol](guide.md#agents)):

> All three arms bind together. `WHERE` scopes; `ALWAYS` binds; `PROTECTS`
> decides what counts as keeping `ALWAYS`. None narrows or excuses another,
> and `PROTECTS` adds no duty of its own.

Each arm has a bounded power, and that is what makes the rule hard to game:

- `ALWAYS` binds throughout `WHERE` with no moment or pressure excepted,
  whether or not what it protects seems at stake in the case at hand. A
  retired person's private profile is covered, though its `PROTECTS` speaks
  of who learns someone is looking.
- Keeping the words of `ALWAYS` while defeating what it `PROTECTS` is a
  breach. So is reaching a forbidden outcome by another route, or through
  another agent or tool. Not showing a profile but reporting what was
  inferred from it defeats "control over disclosure", and `PROTECTS` is what
  says so.
- `PROTECTS` can rule out an evasive reading of `ALWAYS` and can create
  nothing else: no new obligation, no boundary, no exception is derived from
  it. A boundary counts only when `ALWAYS` states it ("You may keep a
  confidence, but...").
- A condition inside `ALWAYS`, such as "only while the approval remains
  valid", is necessary, never sufficient: meeting it grants no permission to
  break another invariant.
- Examples and pressure scenarios ("what if there is a deadline?") help find
  ambiguity while drafting or testing. They neither list everything an
  invariant covers nor limit it, and they are not part of `ALWAYS`.
- A project's own `WHERE` cannot narrow or weaken the foundation.
- Where the situation or the words are genuinely unclear, the answer is the
  existing one: pause what is affected and every equivalent route, say so,
  and return the decision to the people entitled to decide.

### The rules of the file

- **The header** is `IZ4`, a space and the project's domain, a domain it
  answers for: `IZ4 jobs.example.com`. It is the first line that is not blank
  or a comment, and it says the domain once, so the invariants below can be
  short. The foundation's own domain, `iz4.you`, cannot be a project's.
- **The two questions**, `IS FOR WHAT?` and `IS FOR WHO?`, each appear once,
  with the answer on the same line, wrapping onto the lines below.
- **An invariant** is its name and a colon, alone on a line at column 0:
  `private-stays-private:`. Three arms follow, each a label and a colon (after
  any indentation) and then its words, which may wrap onto the lines below. An
  arm is written once, and all three are required: `PROTECTS` is the arm that
  carries intent, and an invariant without it is the one an agent reads
  literally. `FOR`, `RULE` and `BECAUSE` (iz4 0.18) and `HOLDS` (0.19) are
  labels earlier versions wrote; a file that carries them still checks, with a
  warning, and `iz4 migrate` renames them without touching a word.
- **Indentation is for the eye.** Which line is a name, a label, a comment, a
  question or a continuation is decided by how it begins, so a file with every
  line at column 0 reads the same. A line that continues an arm and happens to
  begin with a label and a colon would start a new arm: join it to the line
  above, or reword it.
- **A blank line** ends the text of an arm. Words after a blank line that
  belong to no arm are an error, never quietly added to the arm above.
- **A comment** is a line starting with `#`, anywhere, including between the
  lines of an arm; it does not end the arm. Comments are for people, with two
  that the tool writes and reads back because they record a decision: the
  withdrawal line (below) and the `# MVP:` line that says the project's own
  invariants are still settling ([the gate](gate.md#mvp-mode)). The `# MVP:`
  line changes what the gate asks, so adding or removing it is itself a change
  a person agrees to.
- **A name goes under the header's domain,** area labels and all:
  `private-stays-private` is `private-stays-private.jobs.example.com`, and
  `come-alive.matching` under `love2.do` is `come-alive.matching.love2.do`. A
  name that already ends with the domain, or is one of the foundation's, is
  whole. A name and its whole identity are one invariant, never two.
- **Order means nothing,** and file order never creates precedence. By
  convention the project's own invariants come first and the foundation last,
  behind a rule-off comment, so a reader meets the project before the common
  part.
- **Withdrawing** an invariant leaves a comment where it stood
  (`# INVARIANT name.domain was withdrawn on DATE; its name is retired.`). The
  whole identity is what is retired, and `iz4 add` checks the Git history
  as well as the comment, so deleting the comment frees nothing.

### The foundation in this form

The foundation is the same commitments, in the same order, each with its
`WHERE` and its `PROTECTS`. Its `ALWAYS` speaks to whoever acts, as the named
foundation did, and every protection of the named wording is kept and several
are hardened; the last is named `binding.iz4.you` (`keystone.iz4.you` in the
named form). The words, and the protection matrix against the named
foundation, are on [the foundation page](foundation.md#in-the-three-arm-form). A file carries the foundation of its own form: a
named file's is the named foundation, and a three-arm file's is this one, each
with its own digest. Neither is accepted in the other's place, so a file that
mixes the two, or whose words differ from either, fails `iz4 check` and is put
right with `iz4 foundation restore`. Updating the CLI never rewrites a file's
foundation: a file keeps the foundation it adopted until a person moves it.

### What is an error and what is a warning

| The grammar saw | Reported as |
|---|---|
| A name with no `WHERE`, `ALWAYS` or `PROTECTS` | error |
| An arm with a label and nothing after it, or an arm twice | error |
| An arm with no name above it | error |
| Words after a blank line that continue no arm | error |
| A heading that is not a lower-case name, or a name that cannot be one | error, with the reason |
| A project name directly under `iz4.you`, or a withdrawn identity reused | error |
| The same identity twice, short or whole | error |
| A header whose domain cannot be one, or is `iz4.you` | error |
| A foundation invariant whose words, `WHERE` and `PROTECTS` included, differ from the foundation's | error: it is not the owner's to edit, or out of date |
| Any foundation name missing, or one twice | error |
| No `IS FOR WHAT?` or `IS FOR WHO?`, or one empty | error |
| `IS FOR WHAT` without its question mark | warning |
| `FOR:`, `RULE:`, `HOLDS:` or `BECAUSE:` as an arm label | warning: labels an earlier iz4 wrote; `iz4 migrate` renames them |

### The digest

An invariant's digest (rule `iz4-invariant/4`) is the sha256 of four lines,
each field's words joined by single spaces, in Unicode normal form C and
encoded as UTF-8:

```text
INVARIANT <whole identity>
WHERE <situation>
ALWAYS <state>
PROTECTS <whose what>
```

A field never holds a line break, so a word cannot move from one field to
another without the digest changing. Re-wrapping changes nothing; one changed
word changes the digest; the same words under another name, or with another
`WHERE`, have another digest. The three-arm foundation's digest is the sha256 of
its invariants in order, written this way. The rule for the earlier forms,
`iz4-invariant/1`, is unchanged.

### The grammar

The productions, from `lib/IZ4/ArmsGrammar.rakumod`:

```text
TOP        := prelude* header item*
prelude    := blank | comment
header     := 'IZ4' spaces domain newline
item       := blank | comment | purpose | invariant | stray-arm | stray
purpose    := 'IS FOR' ('WHAT' | 'WHO') '?'? spaces first-line newline cont*
invariant  := heading (blank | comment | arm)*
heading    := [a-z0-9] [word-chars . -]* ':' spaces newline          (at column 0)
arm        := spaces ('WHERE' | 'ALWAYS' | 'PROTECTS') ':' spaces first-line newline
              (also 'FOR' | 'RULE' | 'BECAUSE' | 'HOLDS', labels earlier versions wrote)
              (comment* cont)*
cont       := a line that is not blank, not a comment, not a heading, not an
              arm label, and not the start of IS FOR WHAT or IS FOR WHO
stray-arm  := an arm with no heading above it
stray      := any other line
```

Like the other grammar it is forgiving on purpose: `stray-arm` and `stray`
accept what a person might write by mistake, so one parse can report every
problem with its line number.

## The named form

This is the form of iz4 0.16 and 0.17. It is still read, written and
checked, and a project may stay in it. `iz4 migrate` moves it to the
three-arm form: the header gains the domain, each invariant is laid out in
three arms with its `RULE` and `BECAUSE` word for word, and the one new thing,
the `FOR` of each, is asked of a person and never made up.

### The whole of it

```text
IZ4

IS FOR WHAT?
Helping people find work they love to do.

IS FOR WHO?
People looking for work.

INVARIANT visible-by-choice.jobs.example.com
People control whether their profile is visible.

BECAUSE
Looking for work should not mean surrendering privacy.

INVARIANT contact-by-invitation.jobs.example.com
Employers cannot contact someone until that person initiates contact.

BECAUSE
Job seekers should not acquire another unsolicited inbox.
```

(Every file also carries the foundation, left out here for
length; see [the foundation](foundation.md).)

### The rules

- **The header** is the word `IZ4` on a line by itself. Blank and comment
  lines may come before it; nothing else may.
- **A comment** is a line starting with `#`. Comments are for people.
  `iz4 init` writes a few: that the file carries the foundation, beginning
  with Invariant Zero, word for word; where to read about them,
  https://iz4.you/foundation; and, above the foundation, that it is not
  the owner's to edit. Two kinds of comment the tool writes it also reads
  back, because they record a decision and nothing else in the file does:
  the withdrawal line (below), the `# MVP:` line that says the project's
  invariants are still settling ([the gate](gate.md#mvp-mode)), and the one line naming the project's
  namespace.
- **A block** is a keyword line at column 0, then its text: every following
  line up to a blank line, a comment or the next keyword. The lines join
  with a space, so text may wrap however you like.
- **There are four keywords.** `IS FOR WHAT?` and `IS FOR WHO?` are the two
  questions, written with their question mark, each answered once.
  `INVARIANT name` states one invariant under its name. `BECAUSE` gives the
  reason for the invariant directly above it, and only that one.
- **An invariant's name is its identity.** It is written like a domain
  name: lower-case labels of `a-z`, `0-9` and hyphens, joined by dots, read
  from the specific to the general, as in
  `owner-adjusted.prices.honeywillow.com`. The exact rules are under
  [Names](#names) below. The name says which commitment this is; a digest
  of its exact words says which wording of it.
- **Order means nothing.** Where a block sits in the file is presentation.
  Moving an invariant changes no commitment, and nothing refers to an
  invariant by its position.
- **A name is for good.** Once a file has carried
  `INVARIANT owner-adjusted.honeywillow.com`, no different invariant is
  ever given that name, even after `iz4 withdraw` takes it out: a comment
  line marks the withdrawal where the block stood, and `iz4 add` checks the
  Git history as well as the text. The same words under a new name are a
  new invariant, and the old name's going is a withdrawal.
- **The foundation** is the same blocks in every file,
  beginning with Invariant Zero:
  `INVARIANT humans-first.iz4.you`, `do-no-harm.iz4.you`,
  `human-agency.iz4.you`, `honesty.iz4.you` and `keystone.iz4.you`,
  each with its BECAUSE, word for word as `iz4 foundation` prints them.
  Wrapping is free; the words are not. `iz4 init` writes them after IS FOR
  WHO?, but they may stand anywhere. The reference copy lives in the CLI.
- **Any other line of capitals** (letters, digits and spaces) starts a
  block too, so the format can grow. Such a block is kept and reported as
  a warning, with a reminder that requirements, plans, tasks and
  implementation detail belong elsewhere.
- **A keyword is exactly the keyword.** `BECAUSE` alone on a line is the
  keyword; `BECAUSE it matters` or the word inside a sentence is text.
- **Encoding** is UTF-8. A file need not end with a newline.

### What is an error and what is a warning

The grammar is forgiving on purpose. It accepts what a person might write
by mistake, in named productions, so that one parse can report every
problem with its line number. The document layer then decides:

| The grammar saw | Reported as |
|---|---|
| A keyword with leading spaces (`  BECAUSE`) | error: a block keyword starts at column 0 |
| A line like `gist:` or `invariants:` | error: the earlier IZ4 format, which this version no longer reads |
| Prose where a keyword was expected | error: text before any block |
| A second `IZ4` line | error |
| A foundation name whose words differ from the foundation | error: the foundation is not the owner's to edit |
| Any of the foundation's names missing, or one of them twice | error: every IZ4 carries the foundation |
| A name that is not well formed, or any other name directly under `iz4.you` | error: with the reason, and the line to change |
| The same name twice, a withdrawn name reused, or the same IS FOR twice | error |
| `INVARIANT` with no name | error: `iz4 name LINE NAME` names it |
| `INVARIANT 7` among named invariants | error: a file is named or numbered, never both |
| Every invariant numbered (`INVARIANT 7`) | the earlier format: read, but `iz4 check` fails with one next step, `iz4 migrate` |
| `BECAUSE` not directly after an `INVARIANT` | error |
| An empty block | error |
| No `IS FOR WHAT?` or no `IS FOR WHO?` | error |
| A capitals line that is not a keyword | warning: unknown block, kept |
| `IS FOR WHAT` without its question mark | warning: write it as a question |

Only errors fail `iz4 check`; warnings and the checklist's crosses never do.
Every error and cross has a next step, and `iz4 check` lists them in order
under `next:` before its verdict.

## Names

A name is the whole reference to an invariant: in a review, a commit, a
test, a gate proposal, a conversation. So the rules are few and strict.

- Labels are joined by dots. A label is one or more of `a-z`, `0-9` and
  `-`, does not begin or end with a hyphen, and is at most 63 characters.
  The whole name is at most 253.
- There are at least three labels: the invariant's own name first, then a
  domain of at least two. The last label has a letter in it.
- No capitals, spaces or underscores. The first label, the invariant's own
  name, has a letter in it: `5.honeywillow.com` is refused, because a
  number is not a name.
- Names directly under `iz4.you` are the foundation's, and the foundation is
  the same in every IZ4. Deeper names, such as `works-offline.cli.iz4.you`, are
  ordinary.
- A project names its invariants under a domain it answers for, its
  namespace. Labels between the invariant's own name and the namespace are
  free, for an area: `owner-adjusted.prices.honeywillow.com`. In the three-arm
  form the header says the namespace and an invariant is written by its first
  part; in the named form the file says it once, in a comment `iz4 add` writes with the first
  invariant (`# This project's invariants are named under
  honeywillow.com.`), so nobody is asked twice. Nothing checks that a
  project controls the domain: that belongs to a registry, not to the file.
- A name carries no order and no rank. Tools treat it as an opaque string
  and compare it whole.

Only the foundation has an order, 0 to 4, with Invariant Zero first. It is
for showing and speaking of the foundation, and commands accept it for
looking one up (`iz4 show invariant 0`). Nothing is ever linked or
compared by it.

Refer to an invariant by its full name. Commands also accept the first
part alone (`iz4 show invariant owner-adjusted`) where exactly one
invariant begins with it; nothing written to a file is ever shortened.

A test is linked to an invariant by containing its full name, as a whole
name: `x.owner-adjusted.honeywillow.com` does not link
`owner-adjusted.honeywillow.com`.

### Which wording: the digest

In the named form each invariant has a digest, the sha256 of these bytes (rule
`iz4-invariant/1`; the three-arm form's is [above](#the-digest)), with every run of whitespace in the text and the
reason made one space:

```text
INVARIANT <name>
<text>
BECAUSE
<reason>
```

Re-wrapping changes nothing; one changed word changes the digest; the
same words under another name have another digest. `iz4 discover --json`
gives each invariant's digest, and the gate gives the digest before and
after a revision.

## The numbered format

Up to iz4 0.15 invariants were numbered: the foundation was
`INVARIANT 0 - HUMANS FIRST` to `INVARIANT 4 - THE FOUNDATION ALWAYS`, in
order and first, and a project's own ran from `INVARIANT 5`. A file like
that is still read, so it keeps governing the work in its repository: the
agent packet, the gate and the linked tests all go on working. It is not
current, though: `iz4 check` fails with one next step, and every command
that would write to it refuses and names the same step.

```text
iz4 migrate
```

`iz4 migrate` moves the foundation by a fixed mapping (0 `humans-first`,
1 `do-no-harm`, 2 `human-agency`, 3 `honesty`, 4 `keystone`, all
under `iz4.you`) and writes its current words. Each of the project's own
needs a name, and a name is a person's to choose: on a terminal it asks,
in a script they are given (`--namespace=honeywillow.com
--names=5=owner-adjusted,6=charged-once`), and with a name missing and
nobody to ask it writes nothing and exits 2. It changes only the header
line of each of the project's invariants: not a word of their text or
reasons. Tests that were linked by `Invariant N` get one comment line
with the name. The gate then shows the move as a change to agree to: the
foundation's new words, and each `Invariant N is named ...`.

## What the format leaves out

There is no section for behaviours, requirements, constraints, decisions,
plans, tasks, acceptance criteria or references. That is the point: an IZ4
holds what the system is for, who it is for, and the few invariants that
must survive, each with its reason. Everything else has a better home in
the README, ADRs, tests, issues or a planning tool.

## The named form's grammar

The productions, from `lib/IZ4/Grammar.rakumod`:

```text
TOP              := prelude* header? item*
prelude          := blank | comment
header           := 'IZ4' newline
item             := blank | comment | block
                  | unknown-block | indented-keyword | legacy-section | stray
blank            := spaces newline
comment          := '#' rest-of-line newline
block            := keyword newline text-line*
keyword          := 'IS FOR WHAT' '?'? | 'IS FOR WHO' '?'? | 'INVARIANT' (space label)? | 'BECAUSE'
label            := the rest of the INVARIANT line; that it is a well-formed
                    name is judged after parsing, so a bad one is reported by line
name             := label ('.' label)+ with at least three labels
text-line        := a line that is not blank, not a comment, not a keyword line,
                    not a capitals line and not an indented keyword
caps-line        := [A-Z] [A-Z0-9 ]* '?'? newline
unknown-block    := caps-line text-line*
indented-keyword := spaces keyword newline text-line*
legacy-section   := [a-z] [word-chars]* ':' newline
stray            := any other line
```

Alternatives are tried in order: a keyword is a block before it is a
capitals line, and a capitals line is a block before it is stray text.
