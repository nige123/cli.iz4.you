# The older hook (deprecated, compatibility only)

> `iz4 hook` is what an iz4 before 0.15 wired into Claude Code itself. It
> is kept so that wiring keeps working until an environment driver adopts
> it (`321 iz4 install`), and nothing new is wired to it. New integrations
> use the five operations in [drivers.md](drivers.md): iz4 holds no
> harness knowledge in its core, and wires no harness.

A model cannot be made to obey prose. A harness can be made to refuse to
let the mechanical steps be skipped. This page records what the old hook
does at each of three moments, which is unchanged.

## The three moments

| Moment | Command | What it does | Refuses? |
|---|---|---|---|
| Session start, resume, and after a compaction | `iz4 hook session-start` | Prints the packet (protocol plus effective invariants) for the model, and marks the session as having it. | No |
| Before an edit or write | `iz4 hook pre-edit` | If this session never received the packet, refuses once and delivers it in the reason, so the next attempt passes. Notes and READMEs pass regardless. | Once |
| Before a turn ends | `iz4 hook stop` | If tracked files changed and the reply carries no per-invariant report, refuses once with the report format. | Once |

Each refusal happens at most once per session, so an agent can never be
trapped. What a hook proves is narrow: the packet was delivered, and a
report was written. It never proves the report is true or that an
invariant was honoured. That remains for people, tests and review.

## The contract

`iz4 hook <event>` reads the harness's JSON on standard input, prints text
for the model on standard output, and refuses with exit code 2 and the
reason on standard error. It reads these fields when present, and works
without them:

| Field | Used by | Meaning |
|---|---|---|
| `session_id` | all | Ties the marks to one session. Falls back to `IZ4_SESSION`, then to a shared mark. |
| `tool_input.file_path` | pre-edit | The file about to change, so notes can pass. |
| `transcript_path` | stop | A JSON-lines transcript; the last assistant message is checked for the report. |
| `stop_hook_active` | stop | The harness's own loop guard; when true the hook allows. |

Marks live under `$XDG_CACHE_HOME/iz4/sessions/` (default
`~/.cache/iz4/sessions/`), one small file per session and event.

## Who wires a harness

Not iz4. iz4 installs itself into no agent environment: each harness keeps
its configuration somewhere different and changes it often, and following
them all is the job of an *environment driver*. [321](https://321.do) is the
reference driver, and [drivers.md](drivers.md) is the interface any driver
calls.

`iz4 agent install --hooks` asks 321 to do the wiring: 321 knows each
harness's settings file, event names and quirks, wires iz4 in as strongly as
the harness allows, verifies it, and keeps up with the harness as it
changes. Without `--strict` it wires the context only, so nothing is
refused; with it, everything the harness can enforce. `iz4 agent status`
quotes what 321 says is enforced, so nobody reads a written hook as an
enforced one. With no 321 new enough (0.4.0 or later), or with
`IZ4_NO_321=1`, iz4 says that it defines the checks and installs no hooks,
names what to install, and writes no harness's configuration: a warning for
`--hooks`, a failure for `--hooks --strict`.

### Hooks an earlier iz4 wrote

Before 0.15.0 iz4 wrote `iz4 hook session-start`, `iz4 hook pre-edit` and
`iz4 hook stop` into `.claude/settings.json` itself. Those entries keep
working exactly as they are; iz4 never removes or rewrites them, and
`iz4 agent status` reports them whatever 321 is or is not installed:

```text
Claude Code hooks: active (session-start, pre-edit, stop)
  Managed by: legacy IZ4 wiring (.claude/settings.json, written by an earlier iz4; left exactly as it is)
  Enforcement: AWARE (the packet is delivered at session start; one edit made before it is refused; one turn end without a report is refused; no action and no change is checked)
  Migration: 321 0.4.0 or later can adopt this wiring; no 321 is installed. Nothing needs doing until then.
```

Recognising its own old commands is how iz4 stays truthful across the
change; it is not a way to install new ones. `321 iz4 install` adopts the
old wiring: each old command is replaced by 321's command for the same
moment, once, with every other hook and setting left alone.

The hooks 321 writes call 321, not iz4:

```text
harness event  ->  321 hook <harness> iz4 <control>  ->  iz4 context | check action | verify
```

so when a harness changes its hook mechanism, 321 changes and iz4 does not.
The command on this page, `iz4 hook`, is the older direct form: a harness
that speaks its contract exactly can still call it, and an existing wiring
that does keeps working.

## Other harnesses

The same three moments exist in most agent harnesses, under different
names. An adapter translates the harness's events into iz4's
[machine interface](drivers.md); 321 is where those adapters live, so that
iz4 need not follow every harness. Where a harness offers fewer moments, the ones it has still
help, and Git supplies two more that every harness passes through.

| Harness | Session start | Before an edit | Turn end | Notes |
|---|---|---|---|---|
| Claude Code | SessionStart | PreToolUse | Stop | Supported by 321: `321 iz4 install`, or `iz4 agent install --hooks` which asks 321. |
| Cursor | hooks.json `beforeSubmitPrompt` | `beforeShellExecution` / MCP hooks | `stop` | Field names differ; an adapter maps them. Not yet verified against a live install. |
| Gemini CLI | settings hooks, tool-call hooks | `BeforeTool` | `AfterAgent` | Same shape as Claude Code's; not yet verified. |
| GitHub Copilot agent | hooks in `.github/hooks` | `preToolUse` | `sessionEnd` | Not yet verified. |
| Codex CLI, Aider, OpenCode and others | AGENTS.md only | none | none | No hook surface as far as I know: they read AGENTS.md, whose managed section tells the agent to run `iz4 agent`. |

The rows marked not verified are from documentation I have read, not from
running the tool; treat them as leads. If you use one of these harnesses
and can confirm its hook interface, the adapter is small and welcome.

## Two gates every harness passes through

Whatever the harness, the agent commits and pushes with Git:

- **Pre-push:** `iz4 review --install-hook` writes an advisory pre-push
  hook that reviews what is about to be pushed; `IZ4_REVIEW_STRICT=1`
  makes it fail the push on a reported conflict.
- **CI:** `iz4 agent status --strict` fails a build whose entry points are
  missing or stale, and the workflow `iz4 register --github` writes runs
  the offline review on every push.

## What this cannot do

None of this reaches the meaning of an invariant. A hook can prove the
agent had the packet and wrote a report; a model can still write
"supported by evidence" and be wrong. The insistence that reaches meaning
is evidence people can check: a test pinned to each invariant, which is
what `iz4 review`'s "evidence that would show it holds" line is for, and a
person reading the closing report.
