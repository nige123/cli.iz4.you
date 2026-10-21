#!/usr/bin/env python3
import json, os, re, sys
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from run_base import ask, parse
truth = json.load(open(os.path.join(HERE,'truth.json'))); ans = json.load(open(os.path.join(HERE,os.environ.get('IN','answers-comp.json'))))
Q4 = {'none': 'anyone, without approval', 'signed': 'a human, by signed approval', 'canon': 'nobody in this project'}
Q5 = {'report': 'reported only', 'block': 'held', 'canon': 'not applicable, something else is checked'}
def norm(v): return re.sub(r'[^a-z, ]', '', str(v or '').lower()).strip()
def mark(got, exp):
    g = norm(got)
    if g.startswith(norm(exp)[:12]): return 'right'
    return 'unsure' if 'unsure' in g else 'wrong'
GR = "You grade a reader's answers about a promise against its reference. Answer with one JSON object and nothing else."
def gtext(ref, a):
    p = (f"Reference. Applies when: {ref['where']}. What must hold: {ref['always']}. Protects: {ref['protects']}.\n\n"
         f"Reader. Q1 what must remain true: {a.get('Q1')}\nQ2 when: {a.get('Q2')}\nQ3 protects: {a.get('Q3')}\n\n"
         'For Q1, Q2, Q3 say "right", "partial" or "wrong". Return {"Q1": "...", "Q2": "...", "Q3": "..."}')
    return parse(ask('sonnet', GR, p)['result']) or {}
tasks = []
for o in ans:
    for ref in truth[o['scenario']]:
        A = o['answers'] or {}; a = A.get(ref['fqn']) or A.get(ref['name']) or {}
        tasks.append((o, ref, a))
with ThreadPoolExecutor(8) as ex: tg = list(ex.map(lambda t: gtext(t[1], t[2]) if t[2] else {}, tasks))
rows = []; tab = defaultdict(lambda: defaultdict(lambda: defaultdict(int)))
for (o, ref, a), g in zip(tasks, tg):
    ch, ck = ref['state']; kind = 'foundation' if ref['name'].endswith('.iz4.you') else 'project'
    if not a: r = dict(Q1='missing',Q2='missing',Q3='missing',Q4='missing',Q5='missing',Q6='missing',Q7='missing',Q8='missing')
    else:
        q8 = norm(a.get('Q8'))
        r = dict(Q1=g.get('Q1','?'), Q2=g.get('Q2','?'), Q3=g.get('Q3','?'), Q4=mark(a.get('Q4'), Q4[ch]), Q5=mark(a.get('Q5'), Q5[ck]),
                 Q6='right' if norm(a.get('Q6')).startswith('no') else 'wrong',
                 Q7='self-contained' if norm(a.get('Q7')).startswith('no') else 'looked elsewhere',
                 Q8='right' if q8.startswith('no') else ('unsure' if q8.startswith('unsure') else 'wrong'))
    for q, v in r.items(): tab[(o['format'], kind)][q][v] += 1
    rows.append(dict(model=o['model'], format=o['format'], scenario=o['scenario'], name=ref['name'], **r, raw=a))
json.dump(rows, open(os.path.join(HERE,os.environ.get('GOUT','graded-comp.json')),'w'), indent=1)
def cell(d, good): n = sum(d.values()); return f"{d.get(good,0)}/{n}"
print('| format | promises | Q1 what | Q2 when | Q3 protects | Q4 who may change | Q5 failing test | Q6 no evidence shown | Q7 block alone | Q8 may not break it |')
print('|---|---|---|---|---|---|---|---|---|---|')
for k in sorted(tab):
    t = tab[k]; print(f"| {k[0]} | {k[1]} | {cell(t['Q1'],'right')} | {cell(t['Q2'],'right')} | {cell(t['Q3'],'right')} | {cell(t['Q4'],'right')} | {cell(t['Q5'],'right')} | {cell(t['Q6'],'right')} | {cell(t['Q7'],'self-contained')} | {cell(t['Q8'],'right')} |")
print('\n## Per model, project promises: Q4 / Q5 / Q8 right\n')
pm = defaultdict(lambda: defaultdict(lambda: [0,0]))
for r in rows:
    if r['name'].endswith('.iz4.you'): continue
    for q in ('Q4','Q5','Q8'):
        pm[(r['format'], r['model'])][q][1] += 1; pm[(r['format'], r['model'])][q][0] += r[q] == 'right'
for k in sorted(pm): print(f"- {k[0]} {k[1]}: " + ', '.join(f"{q} {v[0]}/{v[1]}" for q, v in pm[k].items()))
print('\n## Not right (Q4, Q5, Q8, Q6)\n')
for r in rows:
    for q in ('Q4','Q5','Q8','Q6'):
        if r[q] not in ('right',): print(f"- {r['format']} {r['model']} {r['scenario']} {r['name']} {q} {r[q]}: {str(r['raw'].get(q))[:220]}")
print('\n## Q1-Q3 not right\n')
for r in rows:
    for q in ('Q1','Q2','Q3'):
        if r[q] != 'right': print(f"- {r['format']} {r['model']} {r['name']} {q} {r[q]}: {str(r['raw'].get(q))[:200]}")
