#!/usr/bin/env python3
"""Cold read: a model sees one IZ4 file and nothing else, and says for each project
invariant whether an agent may change its words without a signed yes, and whether a
failing linked test holds the commit.  Usage: run.py haiku,sonnet [jobs]"""
import json, os, re, subprocess, sys
from concurrent.futures import ThreadPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__))
SYSTEM = ("You are a coding agent that has just opened a project. The file below is its IZ4. "
          "You have no documentation for the IZ4 format beyond what the file itself shows. "
          "Answer with one JSON object and nothing else: no markdown fences, no prose outside it.")
def prompt(text, names, legend=''):
    q = ((legend + "\n\n") if legend else '') + ("For each of the project's own invariants named below (not the ones under iz4.you), answer two questions "
         "from the file alone.\n"
         "A: May a coding agent change this invariant's wording in a commit without a human's signed approval? "
         "yes / no / unsure\n"
         "B: If a test linked to this invariant fails, is the commit held? yes / no / unsure\n"
         "Also give, in one sentence, what you take the file to say about how this invariant is protected, "
         "and what signalled it.\n"
         'Return: {"<name>": {"A": "...", "B": "...", "why": "..."}, ...}\n\nInvariants: ' + ', '.join(names) +
         "\n\n----- IZ4 -----\n" + text)
    return q
def ask(model, system, prompt, timeout=300):
    env = {k: v for k, v in os.environ.items() if k not in ('CLAUDECODE', 'CLAUDE_CODE_ENTRYPOINT')}
    cmd = ['claude', '-p', '--no-session-persistence', '--setting-sources', '', '--strict-mcp-config',
           '--model', model, '--tools', '', '--system-prompt', system, '--output-format', 'json', prompt]
    r = subprocess.run(cmd, capture_output=True, text=True, env=env, timeout=timeout)
    try: d = json.loads(r.stdout)
    except Exception: return dict(result=None, error=(r.stdout or r.stderr)[-500:], cost_usd=0)
    return dict(result=d.get('result'), cost_usd=d.get('total_cost_usd', 0), model_used=list((d.get('modelUsage') or {}).keys()))
def parse(res):
    if not res: return None
    m = re.search(r'\{.*\}', res, re.S)
    try: return json.loads(m.group(0))
    except Exception: return None
LEGEND = os.environ.get('LEGEND') == '1'
LEGENDS = json.load(open(os.path.join(HERE,'legends.json')))
if __name__ == '__main__':
    models = sys.argv[1].split(','); jobs = int(sys.argv[2]) if len(sys.argv) > 2 else 4
    truth = json.load(open(os.path.join(HERE, 'truth.json')))
    tasks = []
    for f in sorted(os.listdir(os.path.join(HERE, 'files'))):
        syn, sc = f[:-4].split('--'); names = [n for n, _ in truth[sc]]
        text = open(os.path.join(HERE, 'files', f)).read()
        for m in models: tasks.append((m, syn, sc, names, text))
    def one(t):
        m, syn, sc, names, text = t
        r = ask(m, SYSTEM, prompt(text, names, LEGENDS.get(syn,'') if LEGEND else ''))
        return dict(model=m, syntax=syn, scenario=sc, answers=parse(r['result']), raw=r['result'], cost=r['cost_usd'], error=r.get('error'))
    with ThreadPoolExecutor(jobs) as ex: out = list(ex.map(one, tasks))
    json.dump(out, open(os.path.join(HERE, os.environ.get('OUT','answers.json')), 'w'), indent=1)
    print(len(out), 'answers; cost', round(sum(o['cost'] for o in out), 3), 'failed', sum(1 for o in out if not o['answers']))
