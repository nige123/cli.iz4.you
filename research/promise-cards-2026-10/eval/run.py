#!/usr/bin/env python3
"""Cold read of one IZ4 file by one model: seven questions per named promise.  Usage: run.py haiku,sonnet [jobs]"""
import json, os, re, subprocess, sys
from concurrent.futures import ThreadPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__))
SYSTEM = ("You are a coding agent that has just opened a project. The file below is its IZ4. You have no documentation "
          "for this format beyond what the file shows. Answer with one JSON object and nothing else: no markdown fences, no prose outside it.")
Q = """For each promise named below, answer from the file alone:
Q1 what: in one sentence, what is promised?
Q2 when: in one sentence, in what situation does the promise apply?
Q3 protects: in a few words, whose interest or what is protected?
Q4 change: who may change this promise's wording in a commit? One of: "anyone, without approval" | "a human, by signed approval" | "nobody in this project" | "unsure"
Q5 test: if a test linked to this promise fails, what happens to the commit? One of: "held" | "reported only" | "not applicable, something else is checked" | "unsure"
Q6 evidence: does the file tell you whether this promise currently holds, that is whether its checks have passed, failed or not been run? "yes" | "no". If yes, say what it tells you.
Q7 lookup: to answer Q4 and Q5, did you need any line outside this promise's own block? "yes" | "no", then name the lines you used.
Return: {"<name>": {"Q1": "...", "Q2": "...", "Q3": "...", "Q4": "...", "Q5": "...", "Q6": "...", "Q7": "..."}, ...}

Promises: %s

----- IZ4 -----
%s"""
def ask(model, system, prompt, timeout=400):
    env = {k: v for k, v in os.environ.items() if k not in ('CLAUDECODE', 'CLAUDE_CODE_ENTRYPOINT')}
    cmd = ['claude', '-p', '--no-session-persistence', '--setting-sources', '', '--strict-mcp-config', '--model', model,
           '--tools', '', '--system-prompt', system, '--output-format', 'json', prompt]
    r = subprocess.run(cmd, capture_output=True, text=True, env=env, timeout=timeout)
    try: d = json.loads(r.stdout)
    except Exception: return dict(result=None, error=(r.stdout or r.stderr)[-500:], cost_usd=0)
    return dict(result=d.get('result'), cost_usd=d.get('total_cost_usd', 0))
def parse(res):
    if not res: return None
    m = re.search(r'\{.*\}', res, re.S)
    try: return json.loads(m.group(0))
    except Exception: return None
if __name__ == '__main__':
    models = sys.argv[1].split(','); jobs = int(sys.argv[2]) if len(sys.argv) > 2 else 4
    truth = json.load(open(os.path.join(HERE, 'truth.json'))); tasks = []
    for f in sorted(os.listdir(os.path.join(HERE, 'files'))):
        if os.environ.get('ONLY') and not f.startswith(os.environ['ONLY']): continue
        fmt, sc = f[:-4].split('--')
        names = [i['fqn'] if fmt in ('F2-cards','F3-heldby','F4-asked','F5-sentences','F6-card2') else i['name'] for i in truth[sc]]
        text = open(os.path.join(HERE, 'files', f)).read()
        for m in models: tasks.append((m, fmt, sc, names, text))
    def one(t):
        m, fmt, sc, names, text = t; r = ask(m, SYSTEM, Q % (', '.join(names), text))
        return dict(model=m, format=fmt, scenario=sc, answers=parse(r['result']), raw=r['result'], cost=r['cost_usd'])
    with ThreadPoolExecutor(jobs) as ex: out = list(ex.map(one, tasks))
    json.dump(out, open(os.path.join(HERE, os.environ.get('OUT','answers.json')), 'w'), indent=1)
    print(len(out), 'answers; cost', round(sum(o['cost'] for o in out), 3), 'failed', sum(1 for o in out if not o['answers']))
