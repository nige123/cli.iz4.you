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

## vibe mode

While a project's invariants are still settling, `iz4 mode vibe` puts one
line in the file. In vibe mode a change to your own invariants does not wait
for a yes, a failing test of one does not hold a commit, and the gate says
one line. The foundation holds exactly as ever. `iz4 mode solid` when they
are ready to mean it. Entering or leaving vibe mode is itself a change you
agree to.

## For tools

`iz4 gate --staged --json` gives the proposal as data: `outcome`,
`changes`, `protections`, `checks`, `proposal_digest`, and `words`, the
proposal in plain language for a page to show a person. `--enforce` makes
the outcome the exit code (0 pass, 2 agreement required, 3 blocked, 4
unassessed, 1 error). Approvals are `refs/iz4/approvals/<tree>` in Git.

More: [iz4.you](https://iz4.you).

The protecting tests run one at a time; `IZ4_JOBS=8` runs them in parallel where the runtime is known to be safe for it.
