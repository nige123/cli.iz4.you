# iz4: the guide

IZ4 means Is For. One small file beside your code says what the software is
for, who it is for, and the few invariants that must stay true as it changes.
People and coding agents read it before they change anything, and a change to
a promise waits for a person's yes. The file is plain text and belongs to your
project: iz4 works offline and needs no account.

## Start

```text
curl -fsSL https://raw.githubusercontent.com/nige123/cli.iz4.you/main/install | sh
iz4 init
```

`iz4 init` asks what this is for, who it is for, and the domain your project
answers for, then writes the file and sets up the commit hook and your agents.
With the agent you already use on the machine, it drafts the two answers from
the repository and you keep each or type your own. Two answers are a real IZ4.

## Finding an invariant

```text
$ iz4 add
Where does this apply? The situation, not the people.
> a profile marked private could reveal anything beyond its owner
Where ...: what must remain true, whatever is rebuilt?
> Only its owner, and the people they choose, may learn what it reveals.
If the whole system were rewritten tomorrow, would we regret not telling the people rebuilding it this? [y/n] y
PROTECTS: What must not be defeated? Say whose what.
> the owner's privacy, and their control over who learns they are looking
WHEN      a profile marked private could reveal anything beyond its owner
ALWAYS    Only its owner, and the people they choose, may learn what it reveals.
PROTECTS  the owner's privacy, and their control over who learns they are looking
Add it as a promise? [Y/n] y
Name it: a few lower-case words joined by hyphens.
> private-stays-private
Added PROMISE private-stays-private.jobs.example.com to IZ4, exploring: anyone may change its words while it settles. 'iz4 establish private-stays-private' when it is agreed.
```

Three questions, one at a time: where it applies, what must always remain
true there, what must not be defeated. The coach pushes back on a task, a
mechanism, a requirement or "the system", and on a reason that only restates
the rule. If nothing a person would lose comes to mind, that is the sign of a
constraint for the README, not an invariant, and it says so. Already know the
words? `iz4 add invariant '...' --where='...' --protects='...' --name=NAME`.

The golden test: if the whole system were rewritten tomorrow, would we regret
not telling the people and agents rebuilding it this? If not, it is not an
invariant. Uses PostgreSQL, shows 20 results, runs the tests before deploy:
not invariants. Private data is deleted when an account is deleted: yes.

`iz4 suggest` asks your agent for a few candidates from the repository;
nothing is added without your yes. `iz4 withdraw NAME` takes one out, with
the tests that exist only for it; the name is retired for good.

## Keeping it true

- `iz4 status` is the screen to type first: the foundation, each invariant
  with its mark (◆ held by a passing test, ◇ promised, ✕ broken, ? not
  checked), what is staged, how agents are wired, and the one next command.
- `iz4 check` ticks what is true of the file and lists the next steps. It
  never claims the software keeps its invariants; it cannot know.
- `iz4 test` writes a failing test for each invariant without one, in your
  test language, and drafts a real one with your agent for your approval. A
  test is linked to an invariant by naming it in full.
- The commit hook runs `iz4 gate`: a change to a promise stops and asks you,
  one thing at a time, through `iz4 approve`. See [the gate](gate.md).
- A new promise is exploring: its card says `CHANGES REQUIRE no approval;
  current promise still applies`, so its words move without a yes and a
  failing test warns. `iz4 establish NAME` when it is agreed: from then on a
  change waits for your signed yes and a failing linked test holds the
  commit. `iz4 explore NAME` lets it move again, which is itself a change
  the gate asks about. The foundation holds in every case.

## Agents

`iz4 agent` prints what any coding agent must read before it works here: the
effective invariants and a short protocol, including how to read a card. `iz4 agent install` writes a short section into `AGENTS.md` (and
`CLAUDE.md` and a skill where Claude is in use). With 321 0.4.0 or later,
`321 iz4 install` wires the harness so the agent gets the packet at the start
of a session, before a consequential action, and when it finishes. None of
this proves an agent read anything; `iz4 agent status` says what is in place.

## The register

`iz4 register` connects your IZ4 to iz4.you, `iz4 report` sends evidence of
each release (never the text), and `iz4 badge` gives the card and badge for
your README. The core needs none of it.

## Commands

```text
iz4 init                   write the IZ4, hook and agent files
iz4 add                    find an invariant, one question at a time
iz4 where NAME WHAT        say where an invariant applies
iz4 because NAME WHAT      say what an invariant protects
iz4 withdraw NAME          take an invariant out, with its tests
iz4 status                 where things stand: each invariant's mark, this change, the next step
iz4 check                  what is true of the file, and what to do next
iz4 test [NAME]            a test for each invariant without one
iz4 gate --staged          does this change alter a promise?
iz4 approve                a person's yes, one change at a time
iz4 establish NAME         a promise is agreed: changes wait for your yes, failing tests hold
iz4 explore NAME           let a promise move again while it settles
iz4 show invariant NAME    one invariant; iz4 invariants shows them all
iz4 foundation             the foundation every IZ4 carries
iz4 agent                  what an agent reads first
iz4 suggest / review       an agent's candidates; a change read against the invariants
iz4 register / report / badge
iz4 update                 bring iz4 up to date
iz4 help COMMAND           more on one command, with an example
```

The file format: [docs/format.md](format.md). The foundation:
[docs/foundation.md](foundation.md). The machine interface for drivers and CI:
[docs/drivers.md](drivers.md). Everything else: [iz4.you](https://iz4.you).
