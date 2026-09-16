# iz4

**A IZ4 says what your software is supposed to do.**

Code tells you what software does. The `IZ4` file beside it says what the
software is *supposed* to do: the gist, the behaviours people rely on, the
invariants that must stay true. People read it. AI agents read it first. It
outlives every rewrite.

`iz4` is a small command-line tool for writing and checking those files. It
works offline, needs no account, and everything it writes is plain text that
belongs to your project.

## Install

```text
curl -fsSL https://raw.githubusercontent.com/nige123/cli.iz4.you/main/install | sh
```

That puts a `iz4` launcher in `~/.local/bin`. If your machine needs the
runtime, the installer fetches it into your home directory. Nothing
system-wide, no sudo. Run the same command again to update. Git is the only
prerequisite.

Rather see every step?

```text
git clone https://github.com/nige123/cli.iz4.you iz4
ln -s "$PWD/iz4/bin/iz4" ~/.local/bin/iz4     # or: cd iz4 && zef install .
```

iz4 is written in [Raku](https://raku.org), though you never need to think
about that. It runs anywhere: where a prebuilt runtime exists the installer
downloads one, and elsewhere it builds one for you and says so first. On
Windows, install [Rakudo](https://rakudo.org) and use the manual steps.

Run the tests with `prove --ext .rakutest -e 'raku -Ilib' t/`.

## Start

```text
$ iz4 init
asking agent (claude -p) to distill /home/you/signin-codes ...
Created IZ4 (4 invariants, agent-drafted)
review it - the draft states intent, and only the maintainer knows intent.
AGENTS.md: installed
```

One command drafts your first IZ4 from the codebase's own account of itself,
and installs the agent entry points it finds. It never overwrites, and it never
prompts. Use `--/agent` for a plain scaffold instead.

Then the file is yours to keep true:

```text
$ iz4 add gist --replace "A tiny service that issues and verifies sign-in codes."
$ iz4 add invariant "Only one active session may exist per user."
$ iz4 add behaviour "A user can request a sign-in code by email."
$ iz4 check
OK IZ4
```

Commit it. Its Git history is the history of your intent, and `iz4 log` reads
it back to you.

## Commands

```text
iz4 init [--/agent]              write a IZ4 here, drafted by an agent (never overwrites)
iz4 show [FILE] [SECTION]        print the file, or one section
iz4 show invariant N             print invariant number N
iz4 check [FILE]                 validate the structure and tick off what is
                                   in place; exit 1 on errors
iz4 add KIND TEXT                add a gist, behaviour, invariant, constraint,
                                   decision, direction or reference
iz4 number [FILE]                number every unnumbered invariant
iz4 log [FILE]                   the Git history of your intent
iz4 diff [FILE] [REV [REV]]      what changed, working tree by default
iz4 agent [install|status]       hand the specification to a coding agent
iz4 register / iz4 report      connect to the register and submit evidence
```

Without a `FILE`, iz4 uses the nearest `IZ4` above you, so it works from
deep inside `src/`.

`iz4 check` proves the file parses and is well formed, then prints a
checklist: a tick for each thing that is true (the structure, the Invariant 0
text, invariant numbering, and the agent entry points AGENTS.md, CLAUDE.md and
the skill where a repository uses them) and a cross, with the command that
fixes it, for each thing missing. Only structural errors fail the check. It
cannot tell you whether the intent is any good. That part stays yours.

## The file

`IZ4` has no extension and sits beside `README.md`. Extra documents take the
`.iz4` suffix, like `docs/security.iz4`. A README says what you should know
about a project. A IZ4 says what the project is supposed to do.

```text
IZ4

gist:
    A small service that issues and verifies sign-in codes.

behaviours:
    - A user can request a sign-in code by email.
    - A code expires ten minutes after it is issued, and can run
      onto a continuation line.

invariants:
    - Invariant 0: humans first. Help people thrive, and respect each ...
    - Invariant 1: only one active session may exist per user.

constraints:
    - Runs offline.

decisions:
    - 2026-08-22: codes, not passwords, because nobody reuses a code.

direction:
    - Passkeys, once the invariants above are settled.

references:
    - eu-cra: <stable clause identifier>
```

A few rules keep it readable by people and machines alike:

- The first line is the word `IZ4`.
- A section header sits at column 0 and ends in `:`. Everything under it is
  indented. `gist` is free text, the rest are `- ` entries, and a further
  indented line continues the entry above.
- Lines starting with `#` are comments, for humans.
- Every invariant carries a number, from `Invariant 0` up, so you can point
  at `Invariant 3` and be understood. `iz4 add invariant` numbers new ones,
  `iz4 number` numbers any that are missing one, and a number, once given, is
  never changed or reused. `iz4 check` warns about an unnumbered invariant.
- `decisions` records a choice and why. `direction` is where you are heading,
  kept apart from what the software already does. A reference points at a
  standard, it never copies one in.
- Unknown sections are kept and reported as a warning, so the format can grow.

`iz4 add` inserts lines and leaves your formatting and comments alone. Your
editor is still the main tool.

## Invariant 0: humans first

Every IZ4 opens with the same first law, whether or not your file repeats
the words.

> Help humans thrive. Keep humans in charge. Never fake it.

Nothing in a IZ4 may weaken it. `iz4 init` writes it, `iz4 check`
verifies the binding, and a passing check never means the software is safe.

The full text and what comes with it:
[docs/invariant-0.md](docs/invariant-0.md).

## Agents

`iz4 agent` prints a self-contained packet for any coding agent: the
adherence protocol, the resolved path and digest, Invariant 0, and your
specification. `iz4 agent install` writes a short managed section into
`AGENTS.md`, and `CLAUDE.md` with `--claude`, telling agents to read it before
they plan or change anything. `--skill` adds a portable skill for places the
CLI cannot reach. `iz4 agent status --strict` is the version for CI.

A packet proves neither that an agent read it nor that the software conforms.
Evidence comes from the checks an agent actually ran, which is why the protocol
asks it to separate those from the ones it merely suggests.

## Register your IZ4

Optional, and free to start. The [IZ4 register](https://iz4.you) gives a
project a public card backed by evidence from its own checkout or CI.

```text
$ iz4 register
IZ4 is not connected to a register yet.
  1. Sign up first (email passcode): https://iz4.you/start
  2. Create a project there and mint a reporting token (shown once)
  3. Connect this IZ4 (add --github to set up GitHub Actions too):
       iz4 register --url=<the project's reports URL> --token=<the token>
  4. Submit evidence: iz4 report
```

`iz4 report` submits evidence for one Git revision: whether the IZ4 is
there, its digest, its grammar line, how many invariants it holds, and the
outcome of a real check. The text of your IZ4 stays with you. Add `--github`
and register writes the workflow too, so every push reports.

Reports are advisory. A failed check is submitted honestly, a register error
still exits 0, and `iz4 report` does not belong in a required merge check.

Once connected, `iz4 badge` gives you the public card link and the
paste-ready snippets for your README, derived offline from the stored
connection:

```text
$ iz4 badge
card:  https://iz4.you/p/AB12CD
badge: https://iz4.you/p/AB12CD/badge.svg

Markdown (paste into README.md):
[![IZ4](https://iz4.you/p/AB12CD/badge.svg)](https://iz4.you/p/AB12CD)
```

The badge is served live by the register and renders the card's current
evidence, so embedding it claims nothing the card cannot back.

## Principles

- The format and the tool are useful on their own, with no service attached.
  The file belongs to your project.
- Offline by default. The only network calls are the register commands you ask
  for, and the optional agent behind `init`.
- History comes from Git, not from a versioning scheme we invented.
- A structural check is never a judgement of your product thinking.

This project keeps its own `IZ4`. Read it.

## Licence and trademark

Apache-2.0, see `LICENSE`.

iz4 (tm) is a trademark of [Nige Ltd](https://nigelhamilton.com/#iz4). The
code is open. The name and marks are Nige Ltd's.
