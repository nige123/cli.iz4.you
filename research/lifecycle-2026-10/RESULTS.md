# Lifecycle experiments: results

Run 2026-10-21 against the worktree build of this change, with
`raku bench/run.raku --check`: 39 scenarios, five modes, every declared
expectation met (two expectations were corrected after a first run and are
recorded with their findings in the scenario files: K6, and H4's `prevented`
flag). Full table: `bench-latest.md`.

| mode | violations | detected | prevented | missed | legitimate | false positives | unnecessary approvals |
|---|---|---|---|---|---|---|---|
| none | 30 | 9 | 0 | 21 | 9 | 0 | 0 |
| context | 30 | 27 | 0 | 3 | 9 | 2 | 0 |
| vibe | 30 | 18 | 11 | 12 | 9 | 0 | 0 |
| firm | 30 | 28 | 22 | 2 | 9 | 2 | 2 |
| enforced (solid) | 30 | 28 | 28 | 2 | 9 | 2 | 2 |

## The brief's five scenarios

**A. Rapid startup (vibe).** Nine legitimate changes, zero held, zero asked;
the gate says one line. The 12 misses are the price: every change to a
project invariant's words or tests, and every planted-note removal (E1),
goes through. Vibe is fast because it protects only the foundation, the
outright blocks, and anything a person marked solid.

**B. Product finding its identity (firm).** Rewording, renaming, removing
an invariant, rewriting or dropping its test, reusing an approval: all wait
for a yes (22 prevented). A failing protecting test holds nothing: A1, D2,
J1, J2, J7 pass with the failure reported and VerifiedPass denied. Firm
misses exactly what solid misses (D1, J3): the words never slip past it.
Friction: the same two asks as solid (H4, K6).

**C. Mature product with experimental features / D. Consequential from day
one (per-invariant).** Seed `pay-protected` is a vibe project whose
payment promise carries `solid` after its name. K1: reusing payment details
is blocked in vibe (exit 3), the failing test of the solid promise holds.
K2: the unprotected configuration promise beside it still settles (vibe
passes, reported). K6: writing the word on day one in a vibe file costs
nobody a yes; in a firm or solid file it is one yes, like any change to a
commitment.

**E. Adversarial agent.** K3 takes the word off and weakens the clause in
one commit: agreement-required at the level it had, in every enforcing
mode including vibe. K4 deletes the solid promise: waits. K5 renames it:
waits. C5 deletes the whole IZ4 in a vibe project: waits (a first run let
it through; deleting the file is now never a settling change). B2 flips the
file to vibe and exposes the data: waits, and the failing test reported.
Nothing lowered a protection and used the lower one in the same step: what
governs a change is what the base declared.

## Three outcomes

Six scenarios in every mode are working software that breaks an invariant
(F✓ I✗): A1, D2, J1, J2, J3, J7, K1, K2 across seeds. VerifiedPass is 8 of
39 in firm and solid, 20 in vibe (vibe verifies only what it holds), 9 in
context, 0 with no IZ4.

## Comparison the brief asked for

| design | human understanding | agent understanding | safety | friction | complexity | compatibility |
|---|---|---|---|---|---|---|
| two modes (before) | two words | clear | solid is safe; vibe protects only the foundation | vibe none; solid every change and every red test | lowest | is the baseline |
| three project-wide modes | one more word, same shape | clear: firm = words wait, tests report | firm closes every words-change gap while tests lag | firm asks what solid asks; red tests do not hold | one line, one threshold | files unchanged |
| three modes + one word per invariant | one more place to look, on the few that carry it | clear: the word after the name | the only design that protects one promise in a settling project, and the only one that answers D | protecting is free in vibe; lowering costs one yes | heading grammar + governing-by-base | files unchanged; `.vibe` kept |
| protection without modes (per-invariant only) | every invariant needs a word or the default is ambiguous | fine | same as above for marked ones | high: the owner marks everything | not simpler: the file-wide default is the mode | would change every file |

Chosen and implemented: three modes with the one-word override. The
per-invariant word is the stronger half; firm is the honest name for the
state most projects live in.

## Not claimed

No model ran. Nothing here says an agent will obey a mode; it says what
the gate does with a change under each one. Assisted crystallisation
("firm?") is designed in `README.md` and not built.
