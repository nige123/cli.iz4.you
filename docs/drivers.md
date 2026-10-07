# Drivers: how an agent environment calls iz4

**321 knows how the harness works. IZ4 knows what must remain true.**

iz4 does not install itself into agent environments. Claude Code, Codex, Pi,
Gemini CLI and whatever comes next each keep their configuration somewhere
different, expose different lifecycle events and change them often. Knowing
all that would make iz4 a harness manager. So that knowledge lives in an
*environment driver*, and iz4 gives every driver the same small interface.

[321](https://321.do) is the reference multi-harness driver: it detects the
harnesses on a machine, wires iz4 into each as strongly as the harness
allows, translates their native events into iz4's terms, and reports how
strongly the IZ4 is really being enforced. 321 installs and drives iz4
wherever 321 is used.

iz4 does not need 321. A native hook, a Git hook, a CI job, an IDE plugin or
another launcher can call the same five commands. Adding support for a new
agent environment should normally mean teaching a driver about that
environment, not changing iz4.

```text
your environment            a driver                         iz4
----------------            --------                         ---
session starts      ->      knows the event          ->      iz4 context
a tool is about     ->      turns it into a           ->     iz4 check action
  to run                      generic action
work is finished    ->      hands over the last       ->     iz4 verify
                              thing the agent said
a commit, a push,   ->      names two Git trees       ->     iz4 check change
  a pull request
```

## The five operations

Every command takes `--json` and prints one line of JSON. Without it the
same facts are printed for a person. None of them needs a network, an
account, 321, or anything but Git.

### `iz4 discover`

Does an IZ4 govern this directory? Never an error: no IZ4 is an answer.

```json
{"schema":"iz4-discover/1","present":true,"file":"/repo/IZ4","sha256":"9020...",
 "valid":true,"errors":[],
 "invariants":[{"number":0,"foundation":true,"summary":"..."},{"number":5,"foundation":false,"summary":"..."}],
 "tool":"iz4/0.15.0"}
```

`--dir=PATH` asks about another directory. `file` and `sha256` identify
exactly which IZ4 applied; record them with any evidence you keep.

### `iz4 context`

What to tell an agent before it works: `instruction` (a few lines saying the
invariants govern the work, are not optional, must not be reinterpreted or
routed around, and that changing one is a person's decision), `effective`
(the foundation and the project's own invariants), and `text` (the two
together, ready to hand over). Schema `iz4-context/1`. An invalid IZ4 is an
error (exit 1), never an empty context.

The instruction also asks for the per-invariant report that `verify` looks
for, so an agent given only this context is never checked for something it
was not asked.

### `iz4 check action`

One consequential action, before it happens. The action is JSON on standard
input (or `--action=JSON`), in terms no harness owns:

```json
{"operation":"write","target":"lib/profile.txt",
 "parameters":{"content":"..."},
 "resource":"","repository":"/repo","recipient":"","context":"tool Write"}
```

Only `operation` and `target` are needed. `operation` is a plain verb:
`write`, `edit`, `delete`, `execute`, `send`, `fetch`, `commit`, or whatever
your environment does. The action is generic so the same check serves an
agent that sends email as well as one that edits code.

### `iz4 check change`

Does a change alter what the project commits to? This is [the gate](gate.md)
in the check vocabulary, with the gate's own document as the evidence.
Choose what to compare:

```text
iz4 check change --worktree      the working directory, uncommitted work included
iz4 check change --staged        the index
iz4 check change --candidate=REV [--base=REV|none]
```

`--worktree` reads the working directory through a throwaway index, so the
caller's index, HEAD and branches are untouched: nothing is staged and
nothing is committed.

### `iz4 verify`

What can be established about finished work. It takes the same selection as
`check change`, and optionally the agent's last words:

```text
iz4 verify --worktree --summary=FILE --json
```

`--summary=FILE` is a file of plain text. Knowing where a harness keeps a
transcript, and which part of it is the agent's final answer, is the
driver's job. `evidence.parts` says what each part found:

| Part | Establishes |
|---|---|
| `structure` | the IZ4 is well formed |
| `change` | the change alters no commitment or protection without agreement |
| `report` | work that changed files ends with a per-invariant report |

A part that was not run is `not_checked` and is never counted as a pass.
`evidence.report.uncertain` lists the invariants the report itself calls
uncertain or conflicting, in its own words.

## One result document

`check action`, `check change` and `verify` all answer with `iz4-check/1`:

```json
{"schema":"iz4-check/1","check":"change","result":"needs_human",
 "reason":"the change alters what the project commits to, or what protects it; a person must agree",
 "invariants_considered":[5],
 "evidence":{"gate":{"schema":"iz4-gate/1","outcome":"agreement-required"}},
 "proposed_invariant_change":{"kind":"change","summary":"1 commitment change(s), 0 protection change(s)",
   "changes":[{"kind":"revised","number":5}],"proposal_digest":"...",
   "agree_with":"iz4 approve --candidate=<tree> --base=HEAD"},
 "iz4":{"file":"/repo/IZ4","sha256":"..."},
 "limits":"what this check did not establish",
 "exit_code":2,"tool":"iz4/0.15.0"}
```

| `result` | Means | Exit |
|---|---|---|
| `pass` | nothing here needs a decision | 0 |
| `warn` | let it proceed, and tell someone | 0 |
| `needs_human` | a person must decide before this stands | 2 |
| `block` | a definite finding no agreement can lift | 3 |

Exit 1 means the check could not run. Treat it as a gap, never as a pass.

Always read `limits`. A check never claims more than it established: a
`pass` means "nothing here needs an invariant decision", not "this honours
the invariants". Whether code keeps a natural-language invariant is for
tests, review and people.

## What `check action` decides, and what it does not

iz4 applies only rules it can actually establish:

| The action | Result |
|---|---|
| changes or removes the `IZ4` (or a `*.iz4`), directly or through a shell command that names it | `needs_human` |
| changes a test that names an invariant | `warn`, naming the invariant; `check change` compares the test before and after |
| anything else | `pass`, listing the invariants whose own words appear in the action as a pointer for review |

It does not guess whether an ordinary action honours an invariant. An agent
that circumvents an invariant while leaving its wording alone is caught, if
it is caught, by the test that names the invariant failing in `check change`
or `verify`, by review, or by the report it must give. That is why an
invariant worth keeping should gain a test: `iz4 test`.

## `needs_human` is never yours to answer

When a result is `needs_human`, ordinary work stops at that point. Show a
person `proposed_invariant_change` and let them decide. The only way an
agreement is recorded is a person running `iz4 approve` at a terminal; with
no terminal it prints the proposal, exits 2 and records nothing. There is no
`--yes`.

A driver must never supply the agreement, and must not treat any of these as
one: the agent's own text, silence, the run continuing, or an approval given
earlier for different work. Use whatever real approval mechanism your
environment has (an interactive prompt, a review, a signed approval for a
boundary; see [gate.md](gate.md)), and stop when it has none.

## The minimum a driver does

1. **Discover.** `iz4 discover --json` in the working directory. If
   `present` is false, do nothing at all.
2. **Give the context.** `iz4 context --json`; put `text` where your
   environment's agent will treat it as authoritative, at the start and
   again after anything that loses it (a compaction, a resume).
3. **Check actions, where you can intercept them.** Translate the native
   event to an action, call `iz4 check action --json`, and translate the
   result back: let `pass` through, surface `warn`, stop on `block`, and put
   `needs_human` to a person.
4. **Verify at the end.** `iz4 verify --worktree --summary=FILE --json`.
5. **Say what you could not do.** If your environment cannot intercept
   writes, shell commands or network use, report that. Context in a prompt
   is not interception; never present one as the other.

Steps 1, 2 and 4 are possible in any environment. Step 3 depends on what the
harness exposes, which is exactly the knowledge a driver exists to hold.

## With 321

```text
321 harness detect           the harnesses 321 knows, and each one's controls
321 iz4 install              wire iz4 into them, as strongly as each allows
321 iz4 status               what is enforced, and what cannot be
321 iz4 remove               take out only what 321 installed
```

`iz4 agent install --hooks` asks 321 to do this (`--strict` for everything
the harness can enforce; without it, the context only). With no 321 of
0.4.0 or later, iz4 says that it defines the checks and installs no hooks,
names what to install, and writes nothing.

Hooks an earlier iz4 wrote into Claude Code's settings keep working and are
reported by `iz4 agent status` as legacy wiring; `321 iz4 install` adopts
them ([hooks.md](hooks.md)).

## The older hook

`iz4 hook session-start | pre-edit | stop` ([hooks.md](hooks.md)) predates
this interface and still works: it delivers the packet, refuses one edit
made before the packet, and refuses one turn end that changed files without
a report. It reads Claude Code's event shape directly, which is why new
integrations should use the operations above and keep harness shapes in the
driver.
