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

INVARIANT 5
People control whether their profile is visible.

BECAUSE
Looking for work should not mean surrendering privacy.

INVARIANT 6
Employers cannot contact someone until that person initiates contact.

BECAUSE
Job seekers should not acquire another unsolicited inbox.
```

## The rules

- **The header** is the word `IZ4` on a line by itself. Blank and comment
  lines may come before it; nothing else may.
- **A comment** is a line starting with `#`. Comments are for people; the
  tool never reads intent from them. `iz4 init` writes three: that the
  file inherits Invariants 0-4, human intention protected; where to read
  them, https://iz4.you/invariant-zero; and that project invariants begin
  at 5.
- **A block** is a keyword line at column 0, then its text: every following
  line up to a blank line, a comment or the next keyword. The lines join
  with a space, so text may wrap however you like.
- **There are four keywords.** `IS FOR WHAT?` and `IS FOR WHO?` are the two
  questions, written with their question mark, each answered once.
  `INVARIANT n` names a project invariant, numbered from 5 because 0 to 4
  are inherited. `BECAUSE` gives the reason for the invariant directly
  above it, and only that one.
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
| `INVARIANT 3` or any number below 5 | error: reserved for the inherited foundation |
| The same number twice, or the same IS FOR twice | error |
| `BECAUSE` not directly after an `INVARIANT` | error |
| An empty block | error |
| No `IS FOR WHAT?` or no `IS FOR WHO?` | error |
| A capitals line that is not a keyword | warning: unknown block, kept |
| `IS FOR WHAT` without its question mark | warning: write it as a question |
| `INVARIANT` with no number | warning: `iz4 number` numbers it |

Only errors fail `iz4 check`; warnings and the checklist's crosses never do.

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
text-line        := a line that is not blank, not a comment, not a capitals line
                    and not an indented keyword
caps-line        := [A-Z] [A-Z0-9 ]* '?'? newline
unknown-block    := caps-line text-line*
indented-keyword := spaces keyword newline text-line*
legacy-section   := [a-z] [word-chars]* ':' newline
stray            := any other line
```

Alternatives are tried in order: a keyword is a block before it is a
capitals line, and a capitals line is a block before it is stray text.
