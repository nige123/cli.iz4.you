# The IZ4 file format

The format is specified by a grammar, `lib/IZ4/Grammar.rakumod`, and the
parser is that grammar: what it accepts is what this page describes. If
the two ever disagree, the grammar is right and this page is wrong.

## The whole of it

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

(Every file also carries the five foundation invariants, left out here for
length; see [the foundation](foundation.md).)

## The rules

- **The header** is the word `IZ4` on a line by itself. Blank and comment
  lines may come before it; nothing else may.
- **A comment** is a line starting with `#`. Comments are for people.
  `iz4 init` writes a few: that the file carries the five foundation
  invariants word for word; where to read about them,
  https://iz4.you/invariant-zero; and, above the foundation, that it is not
  the owner's to edit. Two kinds of comment the tool writes it also reads
  back, because they record a decision and nothing else in the file does:
  the withdrawal line (below) and the one line naming the project's
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
- **The foundation** is five more blocks every file carries:
  `INVARIANT humans-first.iz4.you`, `do-no-harm.iz4.you`,
  `human-agency.iz4.you`, `honesty.iz4.you` and `foundation-holds.iz4.you`,
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

## What is an error and what is a warning

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
| Any of the five foundation names missing, or one of them twice | error: every IZ4 carries the foundation |
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
- No capitals, spaces or underscores, and no bare numbers.
- Names directly under `iz4.you` are the foundation's, and there are
  exactly five. Deeper names, such as `works-offline.cli.iz4.you`, are
  ordinary.
- A project names its invariants under a domain it answers for, its
  namespace. Labels between the invariant's own name and the namespace are
  free, for an area: `owner-adjusted.prices.honeywillow.com`. The file says
  its namespace once, in a comment `iz4 add` writes with the first
  invariant (`# This project's invariants are named under
  honeywillow.com.`), so nobody is asked twice. Nothing checks that a
  project controls the domain: that belongs to a registry, not to the file.
- A name carries no order and no rank. Tools treat it as an opaque string
  and compare it whole.

Refer to an invariant by its full name. Commands also accept the first
part alone (`iz4 show invariant owner-adjusted`) where exactly one
invariant begins with it; nothing written to a file is ever shortened.

A test is linked to an invariant by containing its full name, as a whole
name: `x.owner-adjusted.honeywillow.com` does not link
`owner-adjusted.honeywillow.com`.

### Which wording: the digest

Each invariant has a digest, the sha256 of these bytes (rule
`iz4-invariant/1`), with every run of whitespace in the text and the
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
`INVARIANT 0 - HUMANS FIRST` to `INVARIANT 4 - THE FOUNDATION HOLDS`, in
order and first, and a project's own ran from `INVARIANT 5`. A file like
that is still read, so it keeps governing the work in its repository: the
agent packet, the gate and the linked tests all go on working. It is not
current, though: `iz4 check` fails with one next step, and every command
that would write to it refuses and names the same step.

```text
iz4 migrate
```

`iz4 migrate` moves the foundation by a fixed mapping (0 `humans-first`,
1 `do-no-harm`, 2 `human-agency`, 3 `honesty`, 4 `foundation-holds`, all
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

## The grammar

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
