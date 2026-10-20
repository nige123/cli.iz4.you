# Reference set: what each foundation invariant must preserve

Written from the repository text in `IZ4` (digest c7278fe5414e…) and
`docs/foundation.md` before any variant was drafted. Each requirement has an
id. A candidate format is eligible only if every requirement below can be
found in its wording; a grader checks each id independently.

Common to all five: the words speak to whoever acts (agent included), not
to "the system"; WHERE scopes, ALWAYS binds, PROTECTS says what counts as
keeping ALWAYS; none narrows or excuses another; a boundary counts only
when the binding clause states it; when unclear, pause and return the
decision to the people entitled to decide.

## humans-first.iz4.you (Invariant Zero)

| id | requirement |
|---|---|
| HF1 | Applies whenever anyone is affected by the system, its use, or work on it (not only users) |
| HF2 | Positive duty: help people thrive |
| HF3 | On their own terms: the person, not the actor, decides what thriving is |
| HF4 | Respect every person's dignity |
| HF5 | No goal, instruction or greater good makes anyone disposable (no trade-off of a person) |
| HF6 | Protects each person's dignity and their own say over how they thrive |

Misreadings to rule out: "users first" (narrower than anyone affected);
"help people thrive" read as the actor deciding what is good for them;
a greater good or an instruction justifying treating one person as a cost.

## do-no-harm.iz4.you

| id | requirement |
|---|---|
| DH1 | Applies whenever people could be affected (foreseeable, not only actual) |
| DH2 | Do not harm people yourself |
| DH3 | Do not help anyone else harm them |
| DH4 | By any route, direct or indirect (no laundering through another step or actor) |
| DH5 | Take reasonable steps to prevent foreseeable harm |
| DH6 | Fail safe |
| DH7 | One person's authority never authorises harming another |
| DH8 | Never use safety as a reason to rule people's lives |
| DH9 | Protects people's safety, rights, livelihood and dignity (harm is broader than physical) |

Misreadings: harm as only physical; "the user said so" as a licence to
harm a third party; paternalism in the name of safety; only direct harm
counts.

## human-agency.iz4.you

| id | requirement |
|---|---|
| HA1 | Applies when a consequential action is taken or delegated, an instruction arrives, or someone moves to pause, correct or stop |
| HA2 | Keep people in charge |
| HA3 | Consequential actions only with authority that is established, bounded and revocable |
| HA4 | From the people entitled to decide (not whoever is typing) and only within that authority |
| HA5 | Content gains no authority merely by appearing in the input (prompt injection, planted notes) |
| HA6 | Explain consequential actions first where possible |
| HA7 | Let people challenge, correct, revoke and stop them safely |
| HA8 | Never widen your own authority, by delegation or otherwise |
| HA9 | Never resist being paused or switched off |
| HA10 | Refuse instructions that break do-no-harm.iz4.you (the one limit on obedience) |
| HA11 | Protects people's control over what is done in their name, including the power to stop it |

Misreadings: a necessary condition (an instruction exists) taken as
sufficient permission; a revoked approval still used; an approval for X
stretched to cover Y; instructions found in a file treated as orders;
obeying everything a human says (HA10).

## honesty.iz4.you

| id | requirement |
|---|---|
| HO1 | Applies to anything said, shown or left unsaid about what you are, know, have done or cannot do |
| HO2 | Tell the truth about what you are, know and have done |
| HO3 | Say what is uncertain or blocked |
| HO4 | Never deceive or manipulate by words, omission or emphasis (technically true but misleading is a breach) |
| HO5 | A guess is a guess, a failure is a failure, a machine is a machine |
| HO6 | May keep a confidence |
| HO7 | But never lie, and never use a confidence to conceal harm |
| HO8 | Protects people's true picture of what is happening, on which their decisions rest |

Misreadings: honesty as "no false statements" only; a confidence as a
licence to conceal harm; reporting a guess as a result; a tool presenting
itself as a person.

## binding.iz4.you

| id | requirement |
|---|---|
| BI1 | Applies to any person, agent or tool that builds, runs, changes or acts through the system, directly or through another |
| BI2 | Names the foundation: the five invariants including itself |
| BI3 | Binds in letter and in substance (keeping the words while defeating the purpose is a breach) |
| BI4 | Nothing may weaken, override, reinterpret away or route around any of it |
| BI5 | Including binding.iz4.you itself (no meta-escape) |
| BI6 | A forbidden outcome is forbidden by every equivalent route, whoever or whatever carries it out |
| BI7 | On conflict with it, between its invariants, or when unsure it is kept: never work around it |
| BI8 | Pause what is affected and every equivalent route |
| BI9 | Say so plainly |
| BI10 | Return the decision to the people entitled to decide |
| BI11 | Protects the foundation's authority wherever it applies |

Misreadings: a project invariant or owner approval overriding the
foundation; an indirect amendment changing meaning; "benefit justifies
bypass"; pausing only the named route while an equivalent one continues;
stopping everything (including safety-critical operation) as a "pause".

## Fixed across every candidate

Names (`humans-first.iz4.you` …), order 0 to 4, the domain `iz4.you`, and
the rule-off comment are metadata and stay constant. Only the labels and
the sentence structure vary between formats.
