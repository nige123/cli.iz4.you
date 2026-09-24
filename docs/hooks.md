# Hooks: what a harness can insist on

A model cannot be made to obey prose. A harness can be made to refuse to
let the mechanical steps be skipped. `iz4 hook` is the harness-neutral
core; each harness needs only a thin adapter that calls it.

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

## Claude Code

`iz4 agent install --hooks` writes the session-start hook into the
repository's `.claude/settings.json`, merged with whatever is there, and
refuses to touch a file it cannot parse. `--strict` adds the two refusing
hooks. Re-running is idempotent, and running without `--strict` removes the
gates again. `iz4 agent status` reports which are installed.

```json
{
  "hooks": {
    "SessionStart": [{ "matcher": "startup|resume|compact",
                       "hooks": [{ "type": "command", "command": "iz4 hook session-start" }] }],
    "PreToolUse":   [{ "matcher": "Edit|Write|MultiEdit|NotebookEdit",
                       "hooks": [{ "type": "command", "command": "iz4 hook pre-edit" }] }],
    "Stop":         [{ "hooks": [{ "type": "command", "command": "iz4 hook stop" }] }]
  }
}
```

Claude Code speaks the contract exactly: it passes JSON on standard input
with those field names, adds a session-start hook's standard output to the
context, and treats exit code 2 as a refusal whose standard error the model
sees.

## Other harnesses

The same three moments exist in most agent harnesses, under different
names. An adapter is a few lines that call `iz4 hook` and translate the
input fields. Where a harness offers fewer moments, the ones it has still
help, and Git supplies two more that every harness passes through.

| Harness | Session start | Before an edit | Turn end | Notes |
|---|---|---|---|---|
| Claude Code | SessionStart | PreToolUse | Stop | Built in: `iz4 agent install --hooks`. |
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
