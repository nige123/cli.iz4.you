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

## Who owns what

- **IZ4 owns intent.** What the software is for, who for, the invariants,
  their evidence, the gate, and a person's agreement.
- **321 owns environment knowledge.** Which harnesses exist, where each
  keeps its settings, what it can intercept, how to wire and verify it.
- **Drivers translate** environment events into the stable interface on
  this page, and its results back into the environment's own terms.
- **Only a person approves a change to intent.**

At run time the calls go one way:

```text
iz4 conveniences   suggest, review, test drafting, agent install --hooks, agent status
       |
       v
      321          the environment driver and agent launcher
       |
       v
   iz4 core        the file, check, the gate, approve, the agent packet,
                   discover, context, check action, check change, verify
```

The core never runs or imports 321 and holds no harness's settings, hook
formats or event shapes; iz4's own tests fail if it starts to
(`t/16-layering.rakutest`). 321 calls nothing of iz4 but the five commands
here and reads only their JSON. Both projects keep an IZ4 file and each
can gate changes to the other's repository, but that is governance of
source code, not a dependency between running programs.

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
{"schema":"iz4-discover/2","present":true,"file":"/repo/IZ4","sha256":"b083...",
 "valid":true,"errors":[],"format":"named","namespace":"honeywillow.com",
 "invariants":[{"id":"humans-first.iz4.you","foundation":true,"summary":"Help people thrive, on their own terms.","digest":"c2a8...","legacy_foundation_number":0},
   {"id":"owner-adjusted.prices.honeywillow.com","foundation":false,"summary":"A live shop price changes only by human decision.","digest":"3d8c..."}],
 "tool":"iz4/0.16.0"}
```

`--dir=PATH` asks about another directory. `file` and `sha256` identify
exactly which IZ4 applied; record them with any evidence you keep.

An invariant is identified by `id`, its full name, and a driver treats it
as an opaque string and compares it whole. The foundation's five come
first, then the project's own in file order. `digest` says which wording
of the invariant this is (rule `iz4-invariant/1`, in
[format.md](format.md#which-wording-the-digest)). `namespace` is the domain
the project's own names share. `format` is `named`, or `numbered` for a
file in the earlier format that `iz4 migrate` has not yet moved: there
each `id` is the old number as a string, such as `"5"`, and `namespace` is
null. A foundation entry in a named file also carries
`legacy_foundation_number`, the number it had in that format.

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

`check action`, `check change` and `verify` all answer with `iz4-check/2`:

```json
{"schema":"iz4-check/2","check":"change","result":"needs_human",
 "reason":"the change alters what the project commits to, or what protects it; a person must agree",
 "invariants_considered":["owner-adjusted.prices.honeywillow.com"],
 "evidence":{"gate":{"schema":"iz4-gate/2","outcome":"agreement-required"}},
 "proposed_invariant_change":{"kind":"change","summary":"1 commitment change(s), 0 protection change(s)",
   "changes":[{"kind":"revised","id":"owner-adjusted.prices.honeywillow.com",
     "before_digest":"3d8c...","after_digest":"ab6a..."}],"proposal_digest":"...",
   "agree_with":"iz4 approve --candidate=<tree> --base=HEAD --sign=<key> --by=<principal>"},
 "iz4":{"file":"/repo/IZ4","sha256":"..."},
 "limits":"what this check did not establish",
 "exit_code":2,"tool":"iz4/0.16.0"}
```

`invariants_considered` is a sorted list of names. Every change in
`proposed_invariant_change` names its invariant by `id`.

| `result` | Means | Exit |
|---|---|---|
| `pass` | nothing here needs a decision | 0 |
| `warn` | let it proceed, and tell someone | 0 |
| `needs_human` | a person must decide before this stands | 2 |
| `block` | a definite finding no agreement can lift | 3 |

Exit 1 means the check could not run. Treat it as a gap, never as a pass.

## When iz4 cannot be run

"Could not run" is any of: the `iz4` command is missing or will not start,
it exits 1, it is killed or times out, it prints no document or one that
does not parse, or the exit code and the `result` disagree. None of these
is a result, and what a driver does next depends on what the control it
is serving can do:

| The control | When iz4 cannot be run |
|---|---|
| **advisory** (it can only tell: context at session start, a note after a tool) | let the work proceed, show a clear warning where a person will see it, and say that IZ4 did **not** check this |
| **enforcing / guarded** (it can stop the thing: a pre-tool guard, an end-of-turn check) | **stop** the intercepted action and report that IZ4 enforcement could not be performed; never downgrade silently to advisory |

A control is reported as guarded only when the check behind it really ran.
A driver gives each call a time limit, so that a hung check is a failure
it can report and not a session that never ends. If the environment can
only advise, say so: context in a prompt is not interception.

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
6. **Own your hooks.** A hook a driver installs into a harness calls the
   driver, which calls iz4. It never calls iz4 directly, so that when the
   harness changes its events only the driver changes.
7. **Fail the right way.** When iz4 cannot be run, an advisory control
   lets the work through with a visible warning and an enforcing control
   stops it (above).

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
the harness can enforce; without it, the context only).

**iz4 may bootstrap its driver, and still knows no harness.** After a
successful change of intent (`iz4 init`, `add`, `because`, `withdraw`, an
approval given at `iz4 approve`), and when hooks are asked for outright,
iz4 makes sure a suitable 321 is there and then runs `321 iz4 install`:

```text
a change of intent succeeds
        |
        v
is a 321 that can drive a harness here?  --yes-->  321 iz4 install
        |no                                             |
        v                                               v
install or update the official 321  ------------>  report what 321 says
        |                                          is really in place
        v (it cannot be installed)
the change stands; iz4 says enforcement is inactive
```

What iz4 knows: that 321 is the reference driver, the minimum version it
needs, and where the official 321 is published. What it does not know, and
never will: any harness's settings format, event names, paths or hook
syntax. The installation is the one `iz4 update` already uses: only the
official release, its checksum verified, proved to run and to state its
version; a 321, or any file named 321, that iz4 did not install is never
replaced; it is idempotent; and nothing is reported as enforced until 321
has wired it and read it back. `IZ4_ENFORCE=0` or `IZ4_NO_321=1` switches
the step off. The commands 321 calls (the five above) never call 321, so
the calls still go one way.

Hooks an earlier iz4 wrote into Claude Code's settings keep working and are
reported by `iz4 agent status` as legacy wiring; `321 iz4 install` adopts
them ([hooks.md](hooks.md)).

## The older hook: deprecated, compatibility only

`iz4 hook session-start | pre-edit | stop` ([hooks.md](hooks.md)) is the
hook an iz4 before 0.15 wired into Claude Code itself. It reads that
harness's event shape directly, which the core no longer does, so it lives
apart from the core (`IZ4::LegacyHook`) and nothing new is ever wired to
it. It is kept, behaving exactly as it did, for one reason: a repository
wired by an earlier iz4 must keep the enforcement it has until a driver
adopts that wiring. `321 iz4 install` replaces each old command with the
driver's own for the same moment, once. Until then `iz4 agent status`
reports the hooks as active, managed by legacy IZ4 wiring.

The safe order is therefore: iz4 0.15 first (it adds this interface and
still answers the old commands), then 321 0.4 or later (it needs this
interface and adopts the old wiring). At no point does a wired command
name something that is not there.
