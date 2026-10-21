# The gate: a promise changes only by agreement

`iz4 gate` compares two states of a repository, the IZ4 and the tests that
name its invariants, and says in a word what a change does to what the
software promises. Nothing in it is a judgement about the code; it is about
commitments, and whether a person has agreed to them.

| Outcome | Meaning |
|---|---|
| `pass` | no commitment or protection changed, and every check that could run passed |
| `agreement-required` | a commitment changed: an invariant added, revised, withdrawn, `IS FOR` changed, or a test that protects an invariant removed or rewritten; a person says yes |
| `blocked` | something no approval lifts: a failing linked test, an invalid IZ4, an altered foundation, a reused name |
| `unassessed` | a check could not run; nothing is claimed |

`iz4 init` installs it as the commit hook in a Git repository, so a commit
that changes a promise stops and asks you there and then.

## Approving

```text
$ git commit -m "..."
INVARIANT charged-once.orders.honeywillow.com added: A customer is charged once for an order.
  WHERE every order
  PROTECTS a customer's money
Is that right? [y/n]
```

`iz4 approve` walks each change, one at a time. `y` agrees, `a` agrees to the
rest, `n` stops. It finds your key, signs the approval for that exact tree,
and offers to push it. An approval covers only what was shown: a changed
file is a new proposal. It is a person's act; an agent never supplies it.

Where a test says an invariant no longer holds, approve asks which is right:
the software, the invariant, or neither yet. Choosing the invariant lets you
reword it; choosing the software keeps the invariant and the commit stops.

## Three modes, and one word for one invariant

Software does not become solid all at once. The IZ4 says how far along it
is, in one line, and the gate reads it:

| mode | a change to your own invariants | a failing protecting test | the foundation |
|---|---|---|---|
| `vibe` | waits for nobody; the gate says one line | reported, holds nothing | holds, as ever |
| `firm` | waits for your yes | reported, holds nothing | holds |
| `solid` (no line) | waits for your yes | holds the commit | holds |

`iz4 mode vibe`, `iz4 mode firm` and `iz4 mode solid` write or remove the
line. Entering or leaving a mode is itself a change you agree to.

One invariant can be protected more than the file: `iz4 mode solid NAME`
writes the word after its name (`charged-once: solid`), so a payments
project can be in vibe mode while the one promise that matters is solid
from its first day. Protecting more is free in a settling file. Lowering a
protection, for the file or for one invariant, waits for a yes at the level
it had, and so does renaming, removing or replacing a protected invariant:
what governs a change is what the base declared, so a candidate cannot
lower a protection and use the lower one in the same step.

## For tools

`iz4 gate --staged --json` gives the proposal as data: `outcome`,
`changes`, `protections`, `checks`, `proposal_digest`, and `words`, the
proposal in plain language for a page to show a person. `--enforce` makes
the outcome the exit code (0 pass, 2 agreement required, 3 blocked, 4
unassessed, 1 error). Approvals are `refs/iz4/approvals/<tree>` in Git.

More: [iz4.you](https://iz4.you).

The protecting tests run one at a time; `IZ4_JOBS=8` runs them in parallel where the runtime is known to be safe for it.
