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
IS FOR WHAT?
Helping people find work they would come alive doing.

IS FOR WHO?
People looking for that work, and the employers hoping to find them.

INVARIANT come-alive.matching.love2.do
A match answers "would they come alive doing this work?". It must never
quietly degrade into keyword matching.

BECAUSE
Plenty of people could do a job. The point is finding the one they'd love.
```

## Why

- **Promises stop disappearing.** A refactor or an agent can't quietly
  build away what people depend on.
- **Agents read it first.** Any model, any harness, the same file.
- **Change by agreement.** A change to a promise waits for a person's yes.
- **Move fast first.** MVP mode stays out of your way until the invariants
  are ready to hold.
- **Humans first, built in.** Every IZ4 carries the same foundation:

| | |
|---|---|
| 0 | [humans-first](https://humans-first.iz4.you): help people thrive, on their own terms |
| 1 | [do-no-harm](https://do-no-harm.iz4.you): do not harm people, or help anyone harm them |
| 2 | [human-agency](https://human-agency.iz4.you): keep people in charge |
| 3 | [honesty](https://honesty.iz4.you): tell the truth; a machine is a machine |
| 4 | [keystone](https://keystone.iz4.you): nothing may weaken the foundation |

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
[gate and MVP mode](docs/gate.md) ·
[agents](docs/drivers.md)

## Licence

Code: Apache-2.0. IZ4 (tm), its name, logo and badge are trademarks of
[Nige Ltd](https://nigelhamilton.com/#iz4), protected so that "IZ4" keeps
meaning the foundation is intact. See [TRADEMARKS.md](TRADEMARKS.md) and
[IZ4-CONFORMANCE.md](IZ4-CONFORMANCE.md).
