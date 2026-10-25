# The gate: a promise changes only by agreement

`iz4 gate` compares two states of a repository, the IZ4 and the tests that
name its promises, and says in a word what a change does to what the
software promises. Nothing in it is a judgement about the code; it is about
commitments, and whether a person has agreed to them.

| Outcome | Meaning |
|---|---|
| `pass` | no commitment or protection changed, and every check that could run passed |
| `agreement-required` | a commitment changed: a promise added, revised, withdrawn, `IS FOR` changed, or a test that protects a promise removed or rewritten; a person says yes |
| `blocked` | something no approval lifts: a failing linked test, an invalid IZ4, an altered foundation, a reused name |
| `unassessed` | a check could not run; nothing is claimed |

`iz4 init` installs it as the commit hook in a Git repository, so a commit
that changes a promise stops and asks you there and then.

## Approving

```text
$ git commit -m "..."
PROMISE charged-once.orders.honeywillow.com added: A customer is charged once for an order.
  WHEN every order
  PROTECTS a customer's money
Is that right? [y/n]
```

`iz4 approve` walks each change, one at a time. `y` agrees, `a` agrees to the
rest, `n` stops. It finds your key, signs the approval for that exact tree,
and offers to push it. An approval covers only what was shown: a changed
file is a new proposal. It is a person's act; an agent never supplies it.

Where a test says a promise no longer holds, approve asks which is right:
the software, the promise, or neither yet. Choosing the promise lets you
reword it; choosing the software keeps the promise and the commit stops.

## What each promise requires, on its card

Software does not settle all at once, and not all of it at the same
pace. Each promise says on its own card what a change to it requires and
what is checked, and the gate reads the card:

| the card says | a change to its words | a failing linked test |
|---|---|---|
| `CHANGES REQUIRE no approval; current promise still applies` | waits for nobody; the gate says one line | reported, holds nothing |
| `CHANGES REQUIRE signed human approval for the exact change` | waits for your signed yes | holds the commit |
| `CHANGES REQUIRE verified foundation release only` (the foundation) | no project approval can make it | holds the commit; the words are matched to the canonical foundation |

A new invariant is born exploring. `iz4 establish NAME` writes the second
pair on its card, so a payments project can explore everywhere while the one
promise that matters is established from its first day. `iz4 explore NAME`
writes the first pair again. Raising what an invariant requires is free.
Lowering it waits for a yes, and so does renaming, removing or replacing an
established promise, and weakening or unlinking a test that names it: what
governs a change is what the base declared, so a candidate cannot lower a
promise's requirement and use the lower one in the same step. A commit that
raises a requirement is held to what it asks: a failing test on a promise
the candidate establishes holds the commit.

A change to the file as a whole, its purpose or its people, waits for a yes
unless every invariant of the project's own is exploring. Removing the file
always waits.

Where every invariant of the project's own is exploring, the gate says what it
noticed in one line and asks for nothing. The foundation holds in every case:
a changed word in it is blocked, and no approval lifts that.

### The runner is a trust boundary

The gate runs the tests that name a promise with the runner for their
language, or the one `IZ4_CHECK_CMD` or `--check-cmd` names. That command
comes from the environment, not from the tree: a project cannot weaken it
from inside a commit, but whoever controls the environment can point it at a
runner that always succeeds. A local hook runs with the committer's
authority. Where that matters, enforce at a boundary the committer does not
control: a required CI check on the protected branch, running the same gate
with its own runner and allowed signers. A required blocking check that did
not run is `unassessed`, never a pass.

## For tools

`iz4 gate --staged --json` gives the proposal as data: `outcome`,
`changes`, `protections`, `checks`, `proposal_digest`, and `words`, the
proposal in plain language for a page to show a person. `--enforce` makes
the outcome the exit code (0 pass, 2 agreement required, 3 blocked, 4
unassessed, 1 error). Approvals are `refs/iz4/approvals/<tree>` in Git.

More: [iz4.you](https://iz4.you).

The gate runs the protecting tests one at a time. `iz4 status` runs eight
at once and runs any failure again alone before calling an invariant
broken: a test that fails beside the others and passes alone is reported
as exactly that. Tests that share a database or a port collide when run
together; `git config iz4.jobs 1` says so once for the repository, and
every command honours it. `IZ4_JOBS` sets the number for one run.
