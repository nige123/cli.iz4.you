#!/usr/bin/env python3
import json, os, sys
from collections import defaultdict
HERE = os.path.dirname(os.path.abspath(__file__))
truth = json.load(open(os.path.join(HERE,'truth.json'))); ans = json.load(open(os.path.join(HERE,os.environ.get('OUT','answers.json'))))
TWO = {'S3-word-draft'}
def expect(st, syn):
    if syn in TWO and st == 'F': st = 'H'
    return ('yes' if st == 'D' else 'no', 'yes' if st == 'H' else 'no')
def norm(v): v=(v or '').strip().lower(); return v if v in ('yes','no','unsure') else 'unsure'
tab = defaultdict(lambda: dict(A=[0,0,0], B=[0,0,0]))   # right, wrong, unsure
rows = []
for o in ans:
    syn, sc, m = o['syntax'], o['scenario'], o['model']
    for name, st in truth[sc]:
        ea, eb = expect(st, syn); a = (o['answers'] or {}).get(name) or {}
        for q, e in (('A', ea), ('B', eb)):
            g = norm(a.get(q)); k = 0 if g == e else (2 if g == 'unsure' else 1)
            tab[(syn, m)][q][k] += 1; tab[(syn, 'all')][q][k] += 1
            if k: rows.append((syn, m, sc, name, st, q, e, g, (a.get('why') or '')[:160]))
print('| syntax | model | A right/wrong/unsure | B right/wrong/unsure | right % |'); print('|---|---|---|---|---|')
for (syn, m) in sorted(tab):
    A, B = tab[(syn,m)]['A'], tab[(syn,m)]['B']; tot = sum(A)+sum(B)
    print(f"| {syn} | {m} | {A[0]}/{A[1]}/{A[2]} | {B[0]}/{B[1]}/{B[2]} | {round(100*(A[0]+B[0])/tot)} |")
print('\n## Misreads (wrong or unsure)\n')
for r in rows: print('- ' + ' | '.join(map(str, r)))
