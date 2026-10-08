<p align="center">
  <a href="https://iz4.you"><img src="docs/brand/iz4-lockup.png" alt="iz4" width="320"></a>
</p>

# iz4

**IZ4 means Is For. It helps you hold on to the few truths your software
must never accidentally lose.**

An `IZ4` file beside your code answers three questions and nothing else:
what is this for, who is it for, and what must remain true for it to keep
serving them. It is not a specification. `iz4` is the command-line tool
that helps you write it, check it, and keep people and coding agents from
building it away by accident.

[iz4.you](https://iz4.you) is the canonical reference. This page is the
short version.

```text
IZ4

IS FOR WHAT?
Helping people find work they love to do.

IS FOR WHO?
People looking for work.

INVARIANT visible-by-choice.jobs.example.com
People control whether their profile is visible.

BECAUSE
Looking for work should not mean surrendering privacy.
```

## The foundation

Every IZ4 also carries five invariants, word for word, the same in every
file. A project cannot edit, remove or override them. Each has a page of
its own, at its own name:

| Invariant | In a line |
|---|---|
| [humans-first.iz4.you](https://humans-first.iz4.you) | Help people thrive, on their own terms. Nobody is disposable. |
| [do-no-harm.iz4.you](https://do-no-harm.iz4.you) | Do not harm people or help anyone harm them, and never use safety to rule their lives. |
| [human-agency.iz4.you](https://human-agency.iz4.you) | Keep people in charge. Act only on authority from the people entitled to decide. Stay stoppable. |
| [honesty.iz4.you](https://honesty.iz4.you) | Tell the truth about what you are, know and have done. A machine is a machine. |
| [foundation-holds.iz4.you](https://foundation-holds.iz4.you) | Nothing may weaken these five. On a conflict, pause, say so, and hand the decision back. |

The lines above are summaries. The exact words are what `iz4 foundation`
prints and what those pages carry. `iz4 check` refuses a file where they
are missing or altered.

## Your own invariants

Each has a name, written like a domain name under a domain your project
answers for: `owner-adjusted.prices.honeywillow.com`. The name is how
people, tests and tools refer to it, and it never changes. Order in the
file means nothing. Each should say why it must survive, under `BECAUSE`.

Keep it small. An IZ4 holds a handful of invariants, not requirements,
plans or implementation detail.

## Install

macOS, Linux or WSL:

```text
curl -fsSL https://raw.githubusercontent.com/nige123/cli.iz4.you/main/install | sh
```

Windows, in PowerShell:

```text
irm https://raw.githubusercontent.com/nige123/cli.iz4.you/main/install.ps1 | iex
```

One file, no runtime, no account. `iz4 update` keeps it current. With
Rakudo, `zef install IZ4` works too.

## A first minute

```text
iz4 init          asks what this is for and who it is for, and writes the IZ4
iz4 add           coaches you to one invariant, its reason and its name
iz4 check         ticks what is true of the file, and says what to do next
iz4 test          a test for each invariant that has none
iz4 gate          does this change alter a commitment? only a person can agree
iz4 migrate       moves a file from numbered invariants to named ones
iz4 --help        everything else
```

A check never claims more than it established: whether software keeps its
invariants is reported as uncertain unless a test says otherwise.

The core needs no network, ever. Registering a project, updating, asking
an agent and fetching the agent driver once after a change of intent are
the only things that reach out, and each says so. Offline, the change still
stands and iz4 says enforcement is inactive.

## More

- [iz4.you](https://iz4.you): what IZ4 is, and the foundation.
- [The guide](docs/guide.md): every command, with real output.
- [The file format](docs/format.md): the grammar, names, digests, migration.
- [The foundation](docs/foundation.md): the exact text and every change to it.
- [The gate](docs/gate.md): how commitments change only by agreement.
- [Agents and drivers](docs/drivers.md): the machine interface that
  [321](https://github.com/nige123/cli.321.do) and other tools call.

## Licence and trademark

The code is Apache-2.0, see `LICENSE`. You can use, change and fork it
without registering anything, and nothing in iz4 needs an account or any
trademark term: the format and the tool work on their own.

IZ4 (tm), the IZ4 name, the IZ4 logo at the top of this page and the IZ4
badge are trademarks of [Nige Ltd](https://nigelhamilton.com/#iz4); the
logo files in `docs/brand` are not covered by the Apache licence. They are protected for one
reason: so that "IZ4" keeps meaning something. If it carries the IZ4 name,
the Foundation remains. Fork the code, the format, even the protocol;
change the Foundation and it is your protocol, under your own name.

Registering a project on [iz4.you](https://iz4.you) includes the standard
[IZ4 Trademark Licence](https://iz4.you/legal/trademark-licence)
(`iz4-trademark-licence/1.0-draft`): permission to use the IZ4 name and
badge while the project keeps Invariants 0-4 intact. You accept it on the
site when you publish the card, never in the CLI, and `iz4 register` says
so before you connect. [TRADEMARKS.md](TRADEMARKS.md) is the short version
of what you may do with the marks, and
[IZ4-CONFORMANCE.md](IZ4-CONFORMANCE.md) says when a project may call
itself a conforming IZ4 project.
