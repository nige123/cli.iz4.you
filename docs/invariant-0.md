# Invariant 0: humans first

Every SPOZ2 document carries Invariant 0, whether or not the file repeats
the text. Leaving the
text out does not remove the obligation, and nothing in a SPOZ2 may weaken it.

The short version, the one worth remembering:

> Help humans thrive. Keep humans in charge. Never fake it.

The canonical text:

```text
invariants:
    - Invariant 0: humans first. Help people thrive, and respect each
      person's dignity. Do no harm, and no greater good makes a person
      disposable. Keep humans in charge: explain consequential actions,
      accept challenge and correction, and stop safely when asked. Be honest
      about what this is, what it knows, what it has done, and what is
      uncertain. No other entry may weaken this.
```

## The digest

There is one canonical text, and it evolves in Git like everything else. It
was shortened on 2026-09-12, from 118 words to 62, with the meaning kept.

The digest identifies the adopted text, and nothing more. Writing a rule down,
or hashing it, does not make software obey it. It is there so nobody can
quietly rewrite what a file bound itself to.

## What comes with it

**Inheritance.** Descendant and specialist specifications may add protections.
They cannot weaken Invariant 0.

**Bounded responsibility.** It creates no duty to intervene outside the
system's own responsibilities, and grants no extra authority. Inside them, a
failure to act still counts. That is the deliberate difference from Asimov's
first law: no inaction clause, so no mandate to seize control for our own good.

**Human control.** Say who can authorise, correct and safely stop
consequential operations, and how people can challenge a decision. Being human
does not by itself authorise someone to control another person's system, and
software must not widen its own authority without approval.

**Harm and dignity.** Define harm by human safety, rights and dignity. Tell a
proportionate burden apart from abuse, and never use aggregate benefit to
excuse treating someone as disposable.

**Honesty in checking.** `spoz2 init` writes the canonical text. `spoz2 check`
compares any repeated text with the canonical
wording, and reports the conflicts it can see. It describes what it verified.
It never implies the software has been proven harmless.

## What the tool enforces

Structure and the text. It seeds the canonical text, warns when a local copy
has drifted or sits in the wrong place, and prints what it verified.

Everything else here is for authors and reviewers. Human control, harm and
descendant specifications are judgement, and no parser settles those.
