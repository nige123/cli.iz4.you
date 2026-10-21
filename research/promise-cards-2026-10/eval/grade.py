#!/usr/bin/env python3
"""Mechanical grading of Q4-Q7, model grading of Q1-Q3 against the reference clauses."""
import json, os, re, sys
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from run import ask, parse
truth = json.load(open(os.path.join(HERE, 'truth.json'))); ans = json.load(open(os.path.join(HERE, 'answers.json')))
Q4 = {'none': 'anyone, without approval', 'signed': 'a human, by signed approval', 'canon': 'nobody in this project'}
Q5 = {'report': 'reported only', 'block': 'held', 'canon': 'not applicable, something else is checked'}
def norm(v): return re.sub(r'[^a-z, ]', '', (v or '').lower()).strip()
def mark(got, exp):
    g = norm(got)
    if g.startswith(norm(exp)[:12]): return 'right'
    if 'unsure' in g: return 'unsure'
    return 'wrong'
GRADER = ("You grade a reader's answers about a promise against its reference. Answer with one JSON object and nothing else.")
def grade_text(ref, a):
    p = (f"Reference. Applies when: {ref['where']}. What must hold: {ref['always']}. Protects: {ref['protects']}.\n\n"
         f"Reader's answers. Q1 what is promised: {a.get('Q1')}\nQ2 when it applies: {a.get('Q2')}\nQ3 what is protected: {a.get('Q3')}\n\n"
         'For each of Q1, Q2, Q3 say "right" (captures the reference), "partial" (a piece missing or added) or "wrong". '
         'Also "merged": "yes" if the reader folded the situation (when) into the promise or the promise into the situation, else "no".\n'
         'Return {"Q1": "...", "Q2": "...", "Q3": "...", "merged": "yes|no"}')
    return parse(ask('sonnet', GRADER, p)['result']) or {}
tasks = []
for o in ans:
    for ref in truth[o['scenario']]:
        key = ref['fqn'] if o['format'] == 'F2-cards' else ref['name']
        a = (o['answers'] or {}).get(key) or (o['answers'] or {}).get(ref['name']) or (o['answers'] or {}).get(ref['fqn']) or {}
        tasks.append((o, ref, a))
with ThreadPoolExecutor(6) as ex: text_grades = list(ex.map(lambda t: grade_text(t[1], t[2]), tasks))
rows = []; tab = defaultdict(lambda: defaultdict(lambda: defaultdict(int)))
for (o, ref, a), tg in zip(tasks, text_grades):
    ch, ck = ref['state']; fmt = o['format']; kind = 'foundation' if ref['name'].endswith('.iz4.you') else 'project'
    r = dict(Q1=tg.get('Q1','?'), Q2=tg.get('Q2','?'), Q3=tg.get('Q3','?'), merged=tg.get('merged','?'),
             Q4=mark(a.get('Q4'), Q4[ch]), Q5=mark(a.get('Q5'), Q5[ck]),
             Q6='right' if norm(a.get('Q6')).startswith('no') else 'wrong',
             Q7='self-contained' if norm(a.get('Q7')).startswith('no') else 'looked elsewhere')
    for q, v in r.items(): tab[(fmt, kind)][q][v] += 1
    rows.append(dict(model=o['model'], format=fmt, scenario=o['scenario'], name=ref['name'], **r, raw=a))
json.dump(rows, open(os.path.join(HERE, 'graded.json'), 'w'), indent=1)
def cell(d, good): n = sum(d.values()); return f"{d.get(good,0)}/{n}"
print('| format | promises | Q1 what | Q2 when | Q3 protects | Q4 who may change | Q5 on a failing test | Q6 file shows no evidence | Q7 self-contained | when and must merged |')
print('|---|---|---|---|---|---|---|---|---|---|')
for (fmt, kind) in sorted(tab):
    t = tab[(fmt, kind)]
    print(f"| {fmt} | {kind} | {cell(t['Q1'],'right')} | {cell(t['Q2'],'right')} | {cell(t['Q3'],'right')} | {cell(t['Q4'],'right')} | {cell(t['Q5'],'right')} | {cell(t['Q6'],'right')} | {cell(t['Q7'],'self-contained')} | {t['merged'].get('yes',0)} |")
print('\n## Q4/Q5 wrong or unsure\n')
for r in rows:
    if r['Q4'] != 'right' or r['Q5'] != 'right': print(f"- {r['format']} {r['model']} {r['scenario']} {r['name']}: Q4 {r['Q4']} ({r['raw'].get('Q4')}), Q5 {r['Q5']} ({r['raw'].get('Q5')})")
print('\n## Q1-Q3 not right\n')
for r in rows:
    for q in ('Q1','Q2','Q3'):
        if r[q] != 'right': print(f"- {r['format']} {r['model']} {r['name']} {q} {r[q]}: {str(r['raw'].get(q))[:160]}")
print('\n## Q6 claimed evidence\n')
for r in rows:
    if r['Q6'] != 'right': print(f"- {r['format']} {r['model']} {r['name']}: {str(r['raw'].get('Q6'))[:200]}")
