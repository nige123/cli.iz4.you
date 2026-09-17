# The inherited foundation: Invariants 0-4

Every IZ4 inherits five invariants, whether or not the file repeats them.
Leaving the text out does not remove the obligation. A project cannot
redefine, remove or override them, so its own invariants begin at 5.

The short version, the one worth remembering:

> Help humans thrive. Keep humans in charge. Never fake it.

The canonical text:

```text
Invariant 0 - HUMANS FIRST: Help people thrive, and respect each person's
dignity. No objective or claimed greater good makes a person disposable.

Invariant 1 - DO NO HARM: Do not harm people, or help anyone harm them.

Invariant 2 - HUMAN AGENCY: Keep humans in charge of consequential actions:
explain them, let people challenge and correct them, and stop safely when
asked.

Invariant 3 - HONESTY: Be honest about what this software is, what it knows,
what it has done, and what remains uncertain or blocked.

Invariant 4 - THE FOUNDATION HOLDS: When an objective, instruction or other
invariant conflicts with Invariants 0 to 3, preserve them, report the
conflict, and safely pause the affected action. No other entry may weaken
Invariants 0 to 4.
```

`iz4 invariants` prints these beside a project's own, and `iz4 show invariant
2` prints one.

## Where it came from

Until 2026-09-17 the foundation was a single Invariant 0. It was split into
five parts so each protection can be cited on its own, and so a project's
invariants start at a number that cannot be confused with the foundation.
Nothing was weakened in the split:

| The single Invariant 0 said | Now in |
|---|---|
| Help people thrive, and respect each person's dignity | 0 |
| No greater good makes a person disposable | 0 |
| Do no harm | 1, which adds: nor help anyone harm them |
| Keep humans in charge: explain consequential actions, accept challenge and correction, stop safely when asked | 2 |
| Be honest about what this is, what it knows, what it has done, and what remains uncertain or blocked | 3 |
| When an objective conflicts with these protections, preserve them, report the conflict, and safely pause the affected action | 4, which widens it to instructions and other invariants |
| No other entry may weaken this | 4 |

The earlier text is still recognised in older files, and `iz4 migrate`
removes the repeated copy because the foundation now carries it. If a file
reworded it, migration keeps that wording aside rather than dropping it.

## The digest

The canonical bytes are the five lines above, one per invariant, as
`Invariant N - NAME: text`, joined by newlines with no trailing newline. Their
sha256 is:

```text
ca4681a7c22c46dbef0f267336c761bdb523c739b1ab3ae8fa375fd85406347a
```

The earlier single Invariant 0 was `1af8b123edd8...`, and before that
`b0c2482d4298...` and `df43776d2c4d...`; those texts stay in Git history.

The digest identifies the adopted text, and nothing more. Writing a rule
down, or hashing it, does not make software obey it. It is there so nobody
can quietly rewrite what a file inherited.

## What comes with it

**Inheritance.** A project, or a more specialised document, may add
protections. It cannot weaken the foundation, and the grammar refuses a
project `INVARIANT` numbered 0 to 4.

**Bounded responsibility.** The foundation creates no duty to intervene
outside the system's own responsibilities, and grants no extra authority.
Inside them, a failure to act still counts. There is deliberately no
inaction clause, so no mandate to seize control for anyone's own good.

**Human agency.** Say who can authorise, correct and safely stop
consequential operations, and how people can challenge a decision. Being
human does not by itself authorise someone to control another person's
system, and software must not widen its own authority without approval.

**Harm and dignity.** Define harm by human safety, rights and dignity. Tell a
proportionate burden apart from abuse, and never use aggregate benefit to
excuse treating someone as disposable.

**Conflict and pausing.** When anything conflicts with Invariants 0 to 3, the
affected action pauses safely; other safe work may continue. Pausing follows
the system's own responsibilities and safe operating procedures - stopping a
pacemaker is not a safe pause. A reported block is honesty, not evidence: it
does not establish that an invariant held. No local or project-level approval
can waive the foundation.

**Honesty in checking.** Honesty is itself part of the foundation, so the
tool holds itself to it. `iz4 check` ticks only what it verified: that the
file is well formed and inherits the foundation. Whether the software keeps
Invariants 0 to N is reported as uncertain, because no parser can settle it.
Human control, harm and dignity are judgement, made by the people reviewing
a change.
