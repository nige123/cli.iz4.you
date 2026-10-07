# The gate: commitments change only by agreement

`iz4 gate` answers one question about a change: does it alter what this
software has committed to? It compares two Git trees, never the working
directory, and reports in five words what it found. `iz4 approve` is how
a person agrees to a change that needs it. Routine commits pass without
anyone being asked. A new, revised or withdrawn project invariant, a
change to IS FOR WHAT or IS FOR WHO, or a weakened test that protects an
invariant needs a person. Altering Invariants 0-4 is blocked and no
project approval can lift it.

The file states it, Git keeps its history, the gate asks before a
commitment moves. Nothing here needs 321, a model, an account or the
register: it is Git plumbing and the tests already in the repository.

## What is compared

| Selection | Base tree | Candidate tree |
|---|---|---|
| `iz4 gate --staged` (the default) | HEAD's tree, or none when HEAD is unborn | the index, written as a tree |
| `iz4 gate --candidate=REV` | REV's first parent, or none for a root commit | REV's tree |
| `iz4 gate --candidate=REV --base=REV2` | REV2's tree | REV's tree |
| `iz4 gate --candidate=REV --base=none` | none | REV's tree |

For a pull request the base is the merge base of the target and the head
(`git merge-base origin/main HEAD`), and the candidate is the head: one
gate covers every commit in it. For a merge commit, name the first parent
as the base. A rebase changes the candidate tree, so any agreement given
before it has to be given again; nothing transfers silently.

The candidate's files are read from the tree through a temporary index,
so an edit in the working directory that is not staged is not in the
candidate, and a file staged for commit is, whatever the working copy
says.

## What is detected

Commitments, from the IZ4 in each tree:

- IS FOR WHAT or IS FOR WHO changed;
- a project invariant (5 and up) added, revised (its text or its BECAUSE)
  or removed;
- the IZ4 removed altogether;
- the candidate IZ4 does not parse (blocked);
- Invariants 0-4 missing or altered (blocked, never approvable);
- a withdrawn number reused for a different invariant (blocked;
  Invariant 13).

Protections, from the tests that name an invariant (`Invariant N` plus
the invariant's opening words, the same convention `iz4 check` uses):

- a test that named an invariant is gone, or no longer names it
  (removed, unlinked);
- a linked test gained a line that looks like a skip (`skip`, `todo`,
  `xit(`, `@pytest.mark.skip`, `t.Skip` and the like): weakened, reported
  as a suspicion for a person to look at;
- a linked test changed in some other way: noted, and its check runs.

Checks: every test naming an invariant is run from the candidate tree,
with the repository's own runner (Raku, Perl, Python, Ruby, Go or a
shell script, by the same detection `iz4 test` uses) or the command in
`--check-cmd` / `IZ4_CHECK_CMD` with `{file}` in it, under a timeout where
the system has `timeout`. A failing check is a definite finding. A check
that times out, has no known runner or cannot start is unassessed, never
passed.

The checks run in an export of the candidate tree, so tracked content
always comes from the snapshot. The checkout's ignored files (installed
dependencies such as `local/` or `node_modules/`, local configuration)
are linked into that export, because they are the machine's environment
and no part of any candidate; untracked files that are not ignored are
left out, since a commit would not carry them. Perl tests get
`-Ilocal/lib/perl5` when the project has one. A test that cannot start for
want of a dependency (`Can't locate ... in @INC`, `ModuleNotFoundError`,
`Cannot find module` and the like) is unassessed, not failed: the gate
could not look, and says so. At a CI boundary a fresh clone has no ignored
files, so install the project's dependencies before the gate runs.

Touches: which invariants the diff mentions by their own words, from
`iz4 review`'s offline layer. A pointer for a person, never a finding.

Only the deterministic checks and the tests already in the repository
decide the outcome. `iz4 review` still offers an agent's opinion, in the
protocol's honesty vocabulary; an agent calling a change compliant is an
opinion with evidence attached, never approval and never proof.

## Outcomes and exit codes

| Outcome | Meaning | `--enforce` exit |
|---|---|---|
| `pass` | no commitment or protection changed, and every check that could run passed | 0 |
| `agreement-required` | a commitment or protection changes and no valid approval covers it | 2 |
| `blocked` | a definite finding no approval can lift: a failing linked test, an invalid IZ4, an altered foundation, a reused number | 3 |
| `unassessed` | a check could not be run; this is not a pass, and the result says what to do | 4 |
| `error` | the gate could not complete (not a repository, unknown revision, unmergeable index) | 1 |

Without `--enforce` the gate is advisory: it prints the same outcome,
says so, and exits 0 for everything but `error`. Advisory is for adoption
and for a local hook that should speak and never refuse. Under
`--enforce` every outcome but `pass` rejects: `unassessed` rejects too,
because a gate that could not look is not a gate that passed, and the
result names the test it could not run so the fix is one step away.
Ordinary commits that touch no invariant test and no IZ4 pass without a
check being run, so they stay fast.

`--json` prints the result as `iz4-gate/1`: `outcome`, `exit_code`,
`mode`, `repository` (the root commit), `base`, `candidate` (tree
hashes), `changes`, `protections`, `checks`, `touches`, `approval`,
`proposal_digest`, `notes`, `next`. The identifiers are what an approval
binds to and what a harness or CI should quote.

## Proposing, then agreeing

```text
$ iz4 gate --staged
gate: candidate tree 9882b2ce7c93 (index) against base b782ea6ec478 (HEAD), advisory
commitments and protections:
  Invariant 6 added: Employers cannot contact someone first.
    BECAUSE No new inbox.
checks, run from the candidate tree:
  ✓ tests/invariant-5.sh (Invariant 5) passed
approval: none for this candidate tree
outcome: agreement-required - a commitment or protection changes; a person has to agree
next:
  1. iz4 approve --staged
```

`iz4 approve` shows the proposal: the exact before and after wording of
every commitment change, the protections touched, and the identifiers
the agreement covers. At a terminal it asks accept, reject or revise.
Without a terminal it prints the proposal, says `pending`, records
nothing and exits 2. There is no `--yes`: a script, an agent or a
harness cannot supply the agreement.

Accepting writes a detached approval, an `iz4-approval/1` document bound
to the repository (its root commit), the base tree, the exact candidate
tree and the digest of the proposal (the changes and protections, so the
same proposal on the same trees always has the same digest). It is stored
as a blob under `refs/iz4/approvals/<candidate tree>`, outside every
tree, so recording it cannot change the tree it approves. The gate then
finds it by the candidate tree hash. Change anything the approval covers
and it no longer applies: the gate says which identifier differs and
asks again. `iz4 approve --out=FILE` also writes the document to a file
for a CI artifact; `iz4 gate --approval=FILE` reads one.

Two levels of approval:

- **terminal**: a person said yes at the terminal that ran `iz4 approve`.
  It is recorded as such, with the Git user as a label. It counts in
  advisory mode and for local hooks. It is not evidence a protected
  boundary can check, because whoever has the shell can write one.
- **signed**: `iz4 approve --sign=KEY --by=PRINCIPAL` signs the document
  with an SSH key (`ssh-keygen -Y sign`). `iz4 gate --enforce` accepts an
  approval only when it verifies against the allowed-signers file named by
  `--approvers` or `IZ4_APPROVERS` (the sshd `allowed_signers` format:
  principal, options, key), with the principal in `--by`. A signed
  approval whose document was edited afterwards does not verify. Push it
  for the boundary to fetch: `git push origin refs/iz4/approvals/<tree>`.

Who may approve is whoever holds a key in that file. The file lives with
the enforcing installation, not in the candidate tree. 123.do or another
human-approval service can take the place of the key: whatever it issues
has to be the same document, signed by a key the boundary lists.

## Carrying protection forward

An invariant's protection is a test that names it, in the repository's
own test system: `Invariant 5` plus the invariant's opening words,
anywhere in the file. Nothing goes into the IZ4 for it. `iz4 test`
scaffolds one, `iz4 check` reports which invariants have one, and the
gate runs them from the candidate and watches them between trees. The
record of what changed when, and who agreed, is Git: the commit that
changed the IZ4 or the test, and the approval ref for the tree it was
agreed on. There is no second ledger.

Broad invariants (humans first, do no harm) usually cannot be pinned by a
unit test. Do not write a token test and call it evidence: `iz4 check`
counts only a test that can fail, and the honest state for such an
invariant is a review, documented reasoning or operational evidence,
reported as `uncertain` in the agent protocol.

## Where it is enforced, and what each tier is worth

| Tier | What runs | Worth |
|---|---|---|
| local hook | `iz4 gate --install-hook` writes a pre-commit hook that runs `iz4 gate --staged` (advisory) or `--staged --enforce`; it never overwrites a hook that is not iz4's | timely feedback for the developer or agent at the keyboard; `git commit --no-verify`, an edited hook, a changed `core.hooksPath` or a different tool all skip it |
| protected boundary | the same `iz4 gate --candidate=HEAD --base=<merge base> --enforce --approvers=FILE` run by CI on the protected branch, or by a server-side hook, from an iz4 installation and an allowed-signers file the candidate cannot change | the check the first tier cannot be trusted for, repeated where the candidate has no authority, with human agreement validated independently |

With a hooks directory shared by every repository on a machine
(`core.hooksPath`), `iz4 gate --install-hook` refuses to write and prints
the line to add. Make a shared hook opt-in per repository, so it never
fires in a temporary repository some test suite creates:

```sh
#!/bin/sh
[ "$(git config --local --get iz4.gate 2>/dev/null)" = enforce ] || exit 0
command -v iz4 >/dev/null 2>&1 || exit 0
[ -f IZ4 ] || exit 0
exec iz4 gate --staged --enforce
```

and opt a repository in with `git config iz4.gate enforce`. The setting
lives in `.git/config`, outside every tree, so a commit cannot change it.

The candidate tree may contain proposed changes to tests and controls;
that is what the gate reports. It cannot approve them: approval is a
signature by a key outside the tree, checked by an installation outside
the tree. Keep the enforcing iz4, its configuration and the allowed
signers out of the candidate's reach. On GitHub Actions that means
running the gate from a workflow defined on the protected branch (a
required check, with rulesets that pin the workflow) rather than one the
pull request can edit; a plain `pull_request` workflow file from the
branch under review is candidate-controlled and counts as the first tier.

The gate checks commits. It cannot undo what an agent did before
committing, and it does not grant or withhold runtime permissions. 321
owns those: what a run may touch, when it is paused, and what it reports.
The two are separate on purpose.

A CI step:

```yaml
- uses: actions/checkout@v4
  with: { fetch-depth: 0 }
- run: git fetch origin 'refs/iz4/approvals/*:refs/iz4/approvals/*' || true
- run: curl -fsSL https://raw.githubusercontent.com/nige123/cli.iz4.you/main/install | sh
- run: |
    BASE=$(git merge-base origin/${{ github.base_ref }} HEAD)
    ~/.local/bin/iz4 gate --candidate=HEAD --base="$BASE" --enforce --json \
      --approvers="$RUNNER_TEMP/allowed_signers"
  env:
    IZ4_APPROVERS: ${{ runner.temp }}/allowed_signers   # written from a repository variable or secret, never from the tree
```

## The contract for harnesses, and 321

IZ4 owns: parsing and comparing the IZ4, the proposal and its digest,
the evidence linkage (tests naming invariants), the checks, and the
validation of approval evidence it is handed. A harness owns: when to
call the gate, how to present the proposal to the person, how to carry
their answer, runtime permissions, and the run's receipt. A harness
should call the CLI and present its result, never re-implement the
policy.

The contract is the CLI: `iz4 gate --candidate=<rev> [--base=<rev>]
--enforce --json [--approvers=FILE]`, exit code `0 2 3 4 1`, result
`iz4-gate/1`. An interactive harness shows `proposal_digest`, `changes`
and `protections` and, when the person agrees, runs `iz4 approve` on the
person's behalf at the person's terminal, or has the person sign the
document it is given. A harness never fabricates an approval: an
`iz4-approval/1` document without a signature a boundary lists is a
terminal approval and is treated as one.

What exists in 321 today (cli.321.do, inspected on 2026-10-06): a
`role Adapter` (`lib/Do321/Adapter.rakumod`) with `name`, `detect`,
`enforcement` and `run(Cancel, Spec, Control --> Outcome)`, implemented
by `ClaudeCode` and by `ProcedureAdapter`; shape tables `WorkPackage`
(with an `approval` pointer to an `Approval` of `proposalRef`,
`approvalRef`, `approvedBy`, `action`, `target`, `params`, `paramsHash`
and `proposal`, a `DeploymentProposal` carried verbatim: 321's approvals
are deployment-shaped, and its boundary re-plans the same service and
target and fails the approval if parameters, manifest digest or deployed
revision moved) and `RunReceipt` (`status` including `blocked`, `blockedOn`,
`uncertain`, `evidence.approvalCheck`) in `lib/Do321/Shape.rakumod`; and,
in `lib/Do321/Run.rakumod`, `apply-iz4-policy` (the packet into the
prompt), `refresh-iz4-packet` and `check-iz4-report` (`iz4 hook stop`
after a run, turning a missing per-invariant report into
`status: blocked`). There is no Codex adapter and nothing in 321 calls a
gate. Since 321 0.3.3, `policy.standingApprovals` in `trust.json` lets an
unattended `321 <agent> go` deploy without a person at the terminal;
those are deploy-only and approve nothing about an IZ4, so they are not a
precedent for gate approvals. None of that is changed by this
repository.

What a 321 integration would be, as work in 321, not done here:

- after `fill` and beside `check-iz4-report` in `Session.drive`, run
  `iz4 gate --staged --enforce --json` (or over the run's commits) and
  map `agreement-required` to `status: blocked` with `blockedOn` carrying
  the proposal, `blocked` to `blocked`, `unassessed` to an `uncertain`
  line; the gate's JSON goes under `evidence`;
- in `cmd-agent`, when a blocked receipt carries a proposal, show it and,
  if the operator accepts at the terminal, run `iz4 approve` there and
  resume; today `--continue <receipt.json>` exists only on `321 run`, so
  this needs continuation added to the agent path or `cmd-agent`
  re-issuing the same package through the run path. An unattended run
  leaves the receipt blocked, as `iz4 approve` itself does;
- carrying an iz4 agreement on a `WorkPackage.approval` is new protocol
  work in 321, not a fit for what is there: `proposalRef` is a string
  reference, `proposal` must be a `DeploymentProposal`, and
  `Control.approval(action, target, params)` is a callback adapters use
  at execution time to check the package's approval against an external
  action. An `iz4-approval/1` document would need a new action kind, a
  non-deployment proposal type in `work-package.v1`, and its own check
  (the gate's validation, run by the boundary). That is the shape an
  exact-action approval from 123.do would take.

Any other harness has the same contract and the same two obligations:
call the gate on the real trees, and hand the proposal to a person
instead of answering it.

## What this does not claim

The gate proves nothing about behaviour; it reports what two trees say
and what the linked tests did. A pass means no commitment moved and the
checks that exist passed. A terminal approval is a label, not evidence.
A local hook is a courtesy. Only the protected tier, with signed
approvals and an installation the candidate cannot touch, is
enforcement, and only for commits.
