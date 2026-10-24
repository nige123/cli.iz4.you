<p align="center">
  <a href="https://iz4.you"><picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/brand/iz4-lockup-dark.svg">
    <img src="docs/brand/iz4-lockup.svg" alt="iz4" width="320">
  </picture></a>
</p>

# iz4

**Ensure your software puts humans first.**

One small file beside your code says what it is for, who it is for, and
what it must never lose. People and coding agents read it before they
change anything.

```text
IZ4 love2.do

IS FOR WHAT?  Helping people find work they would come alive doing.
IS FOR WHO?   People looking for that work, and the employers hoping to find them.

PROMISE come-alive.matching.love2.do

  WHEN      a person is matched to a role
  ALWAYS    a match answers "would they come alive doing this work?" and
            never degrades into keyword matching
  PROTECTS  a person's chance of the work they would love, not merely a
            job they could do

  CHANGES REQUIRE signed human approval for the exact change
  CHECKED WITH    linked tests; failures block commit
```

An invariant is an expression that includes a promise, how it is checked,
and what a change to it requires; each is written as a card. The promise is
the first three lines: when it applies, what must always remain true, and
whose what it protects. Nothing is hidden elsewhere in the file.

## Why

- **Promises stop disappearing.** A refactor or an agent can't quietly
  build away what people depend on.
- **Agents read it first.** Any model, any harness, the same file.
- **Change by agreement.** A change to a promise waits for a person's yes.
- **Move fast first.** A new invariant is exploring: its promise moves freely
  until you establish it, and the card says which it is.
- **Humans first, built in.** Every IZ4 carries the same foundation:

| | |
|---|---|
| 0 | [humans-first](https://humans-first.iz4.you): help people thrive, on their own terms |
| 1 | [do-no-harm](https://do-no-harm.iz4.you): do not harm people, or help anyone harm them |
| 2 | [human-agency](https://human-agency.iz4.you): keep people in charge |
| 3 | [honesty](https://honesty.iz4.you): tell the truth; a machine is a machine |
| 4 | [binding](https://iz4.you/foundation): nothing may weaken, override or route around the foundation |

## Start

```text
curl -fsSL https://raw.githubusercontent.com/nige123/cli.iz4.you/main/install | sh
iz4 init
```

Windows: `irm https://raw.githubusercontent.com/nige123/cli.iz4.you/main/install.ps1 | iex`

One file, no runtime, no account. `iz4 init` drafts the IZ4 with the agent
you already use. `iz4 help` is one short screen.

The core needs no network, ever. Only registering, updating, asking an
agent and fetching the agent driver reach out. Offline, the change still
stands and iz4 says enforcement is inactive.

## More

[iz4.you](https://iz4.you) ·
[guide](docs/guide.md) ·
[format](docs/format.md) ·
[foundation](docs/foundation.md) ·
[the gate](docs/gate.md) ·
[drivers](docs/drivers.md)

## Licence

Code: Apache-2.0. IZ4 (tm), its name, logo and badge are trademarks of
[Nige Ltd](https://nigelhamilton.com/#iz4), protected so that "IZ4" keeps
meaning the foundation is intact. See [TRADEMARKS.md](TRADEMARKS.md) and
[IZ4-CONFORMANCE.md](IZ4-CONFORMANCE.md).
