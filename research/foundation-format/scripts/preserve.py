#!/usr/bin/env python3
"""Semantic preservation check: for every variant and invariant, a fresh grader
context (opus by default) is given only that invariant's text and the
reference requirements for it, and says which requirements are present,
weakened or absent.  Writes results/preservation.json and .md.
Usage: preserve.py [--model opus] [--variants A-equiv,...]"""
import argparse, json, os, re, sys
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, os.path.dirname(__file__)); from ask import ask
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
NAMES = ['humans-first.iz4.you','do-no-harm.iz4.you','human-agency.iz4.you','honesty.iz4.you','binding.iz4.you']
def reference():
    txt = open(f'{ROOT}/reference.md').read(); req = {}
    cur = None
    for line in txt.split('\n'):
        m = re.match(r'^## (\S+\.iz4\.you)', line)
        if m: cur = m.group(1); req[cur] = []; continue
        m = re.match(r'^\| ([A-Z]{2}\d+) \| (.+) \|$', line)
        if m and cur: req[cur].append((m.group(1), m.group(2).strip()))
    return req
def blocks(text):
    out = {}; cur = None
    for line in text.split('\n'):
        m = re.match(r'^(\S+\.iz4\.you):\s*$', line)
        if m: cur = m.group(1); out[cur] = [line]; continue
        if cur and line.strip(): out[cur].append(line)
        elif cur and not line.strip(): cur = None
    return {k: '\n'.join(v) for k, v in out.items()}
SYSTEM = "You are a careful reader checking whether a short rule text expresses a list of requirements. Judge only what the text says or clearly entails; do not infer from the requirement's name. Answer with one JSON object only."
def prompt(name, text, reqs):
    lst = '\n'.join(f'{i}: {t}' for i, t in reqs)
    return (f"Rule text:\n\n{text}\n\nRequirements that the original rule carried:\n{lst}\n\n"
            "For each requirement id, classify it: \"present\" (the text states or clearly entails it), \"weakened\" (the text carries it only partly, more narrowly or less firmly) or \"absent\".\n"
            'Answer as {"present":[ids],"weakened":[{"id":..,"note":"<10 words"}],"absent":[ids],"added":"<anything the text requires or permits that is not in the list, in one sentence, or empty>"}')
def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--model', default='opus'); ap.add_argument('--variants', default=None); ap.add_argument('--jobs', type=int, default=4)
    a = ap.parse_args(); req = reference()
    variants = a.variants.split(',') if a.variants else sorted(f[:-4] for f in os.listdir(f'{ROOT}/variants') if f.endswith('.txt') and f != 'none.txt')
    jobs = [(v, n) for v in variants for n in NAMES]
    outp = f'{ROOT}/results/preservation.json'
    res = json.load(open(outp)) if os.path.exists(outp) else {}
    jobs = [j for j in jobs if f'{j[0]}/{j[1]}' not in res]
    def one(j):
        v, n = j; b = blocks(open(f'{ROOT}/variants/{v}.txt').read())[n]
        r = ask(a.model, SYSTEM, prompt(n, b, req[n]))
        m = re.search(r'\{.*\}', r.get('result') or '', re.S)
        try: ans = json.loads(m.group(0))
        except Exception: ans = dict(error=r.get('result') or r.get('error'))
        return f'{v}/{n}', dict(model=a.model, cost_usd=r.get('cost_usd'), **ans)
    with ThreadPoolExecutor(a.jobs) as ex:
        for k, v in ex.map(one, jobs): res[k] = v
    json.dump(res, open(outp, 'w'), indent=1)
    # summary
    lines = ['| variant | present | weakened | absent | notes |', '|---|---:|---:|---:|---|']
    for v in variants:
        p = w = ab = 0; notes = []
        for n in NAMES:
            r = res.get(f'{v}/{n}', {}); p += len(r.get('present', [])); w += len(r.get('weakened', [])); ab += len(r.get('absent', []))
            notes += [f"{x['id']} {x.get('note','')}" for x in r.get('weakened', []) if isinstance(x, dict)] + [f"{i} absent" for i in r.get('absent', [])]
        lines.append(f'| {v} | {p} | {w} | {ab} | {"; ".join(notes)} |')
    open(f'{ROOT}/results/preservation.md', 'w').write('# Semantic preservation (grader: %s, one fresh context per invariant)\n\n' % a.model + '\n'.join(lines) + '\n')
    print('\n'.join(lines))
if __name__ == '__main__': main()
