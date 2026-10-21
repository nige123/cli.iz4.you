# The lifecycle of human intent: vibe, firm, solid

Design note, 2026-10-21. Software does not become solid all at once, and
its intentions crystallise at different speeds. IZ4 had two modes; this
work asked whether a third, and a per-invariant protection, earn their
place. Results: `RESULTS.md`. Code: `lib/IZ4/Gate.rakumod` (what governs a
change), `lib/IZ4/Document.rakumod` (`mode`, `protection-of`), `bin/iz4`
(`iz4 mode`), `bench/scenarios/K*`.

## The dimensions, kept apart

| dimension | where it lives | what moves it |
|---|---|---|
| maturity of the words | the file's mode line, and a word after one name | a person, by `iz4 mode` |
| protection of the intention | what the gate does with a change to an invariant: waits for a yes, or not | the mode or word that governed it before the change |
| evidence that it holds | the protecting tests, and what the gate does with a failure: holds, or reports | mode: solid holds, firm and vibe report |
| consequence of failure | not IZ4's to know; it is why a person marks one promise solid on day one | the person |

The model: a change is governed by what the base declared, never by what
the candidate declares. So protecting more is free in a settling file, and
lowering any protection, for the file or one invariant, waits for a yes at
the level it had. Renaming, removing or replacing a protected invariant is
a change to it and waits the same way.

## Names

Chosen: **vibe, firm, solid**. Vibe and solid were already the product's
words, in files on this machine and in talks; dropping them would cost
recognition for no gain. The middle state is the one where the words have
set but the evidence has not. "Firm" says that in one syllable, continues
the physical metaphor (fluid, firm, solid), is common English with
cognates in the Romance and Germanic languages, collides with nothing in
Git or the shell, and tells a model the operational fact: a change waits,
a failing test does not hold.

Rejected: *form* and *shape* (verbs as often as states; "form mode" misreads);
*align*, *guard*, *anchor* (actions, not states; "guard mode" suggests the
gate itself); *explore, agree, enforce* and *discover, define, defend* (good
behavioural ladders, but they replace vibe and solid, and "enforce" names
the gate's option, not the file's state); *fluid, forming, firm* (loses
solid, which is the word people already use for the end state). Per the
brief, *commit* was not considered.

## Is a third mode justified?

Yes, narrowly, and because of what it is not. Without it, a team whose words
have settled but whose tests lag has to choose between vibe (anyone can
reword a promise silently) and solid (every red test holds every commit).
Firm is the state most real projects are in for most of their life. It adds
one line to the file and one word to the help; the gate's logic is the same
function with a different threshold.

## Is per-invariant protection worthwhile?

Yes, and it is the stronger of the two additions. A payments project that
is experimental everywhere except in where the money goes is the normal
case, not the edge case, and the brief's scenario D (strong protection from
the first day, no artificial journey) is only answerable this way. The cost
is one word after one name, on the few invariants that need it; most carry
none.

## What is not done

No automatic promotion. The signals the brief lists for "ready to be
firmer" (stable wording, tests repeatedly passing, dependents) are
observable from Git history and the record `iz4 status` keeps, and an
advisory `iz4 status` line could say "charged-once has had the same words
for 40 days and a passing test for 30: firm?" It is left out of this
change: it would be the first thing in iz4 that nudges the owner about
their intent, and that deserves its own decision.
