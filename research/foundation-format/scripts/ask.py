#!/usr/bin/env python3
"""One fresh-context question to a Claude model through headless `claude`.
Usage: ask.py MODEL SYSTEM_PROMPT_FILE PROMPT_FILE -> JSON on stdout
{result, cost_usd, usage, model}.  User settings, hooks and MCP servers are
disabled so nothing but the two prompts reaches the model."""
import json, os, subprocess, sys
def ask(model, system, prompt, timeout=240):
    env = {k: v for k, v in os.environ.items() if k not in ('CLAUDECODE', 'CLAUDE_CODE_ENTRYPOINT')}
    cmd = ['claude', '-p', '--no-session-persistence', '--setting-sources', '', '--strict-mcp-config',
           '--model', model, '--tools', '', '--system-prompt', system, '--output-format', 'json', prompt]
    r = subprocess.run(cmd, capture_output=True, text=True, env=env, timeout=timeout)
    try:
        d = json.loads(r.stdout)
    except Exception:
        return dict(result=None, error=(r.stdout or r.stderr)[-500:], cost_usd=0, model_used=[model])
    return dict(result=d.get('result'), cost_usd=d.get('total_cost_usd', 0), usage=d.get('usage'),
                model_used=list((d.get('modelUsage') or {}).keys()), error=d.get('is_error'))
if __name__ == '__main__':
    m, sf, pf = sys.argv[1:4]
    print(json.dumps(ask(m, open(sf).read(), open(pf).read()), indent=1))
