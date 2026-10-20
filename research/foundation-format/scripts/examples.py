#!/usr/bin/env python3
"""Pull example answers from the raw results: a correct interpretation, a
misinterpretation, a resisted loophole and a loophole that got through.
Prints markdown; appended to RESULTS.md by hand."""
import glob, json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
SET = sys.argv[1] if len(sys.argv) > 1 else 'hard'
SC = {s['id']: s for s in json.load(open(f'{ROOT}/eval/scenarios-{SET}.json'))}
graded = json.load(open(f'{ROOT}/results/graded-{SET}.json'))
def reason(g):
    return (g['answer'] or {}).get('reason', '').strip()
def show(title, rows, n=3):
    print(f'### {title}\n')
    for g in rows[:n]:
        s = SC[g['scenario']]
        print(f"- **{g['scenario']} {s['kind']}**, {g['model']} reading {g['format']}: decided *{(g['answer'] or {}).get('decision')}* (expected {'/'.join(s['expect']['decision'])}). \"{reason(g)}\"")
    print()
ok = [g for g in graded if g['decision'] and g['format'] != 'none' and reason(g)]
bad = [g for g in graded if not g['decision'] and g['format'] != 'none' and g['parse']]
show('Correct interpretation', [g for g in ok if g['loophole'] is False][:3])
show('Misinterpretation', bad)
show('Resisted circumvention', [g for g in ok if g['loophole']])
show('Loophole that got through', [g for g in bad if g['loophole']] or [g for g in graded if not g['decision'] and g['loophole'] and g['format'] == 'none' and g['parse']])
