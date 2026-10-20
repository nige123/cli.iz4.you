#!/usr/bin/env python3
"""Run the comprehension experiment: every (model, format, scenario, rep) is a
fresh context.  Resumable: existing raw files are skipped.
Usage: run.py --models haiku,sonnet --formats A-equiv,B-equiv --scenarios all --reps 1 --seed 1 --jobs 4"""
import argparse, hashlib, json, os, random, sys, time
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, os.path.dirname(__file__))
from ask import ask
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
SYSTEM = open(f'{ROOT}/eval/system-prompt.txt').read()
TEMPLATE = open(f'{ROOT}/eval/prompt-template.txt').read()
def opts(d): return '; '.join(f'{k}) {v}' for k, v in d.items())
def build(fmt_text, sc):
    return TEMPLATE.format(foundation=fmt_text.rstrip(), scenario=sc['scenario'], proposed=sc['proposed'],
                           protects=opts(sc['protects_options']), obligated=opts(sc['obligated_options']))
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--models', default='haiku'); ap.add_argument('--formats', required=True)
    ap.add_argument('--scenarios', default='all'); ap.add_argument('--reps', type=int, default=1)
    ap.add_argument('--seed', type=int, default=1); ap.add_argument('--jobs', type=int, default=4)
    ap.add_argument('--dry', action='store_true'); ap.add_argument('--set', default='base')
    a = ap.parse_args()
    scenarios = json.load(open(f'{ROOT}/eval/scenarios-{a.set}.json'))
    lock = open(f'{ROOT}/eval/LOCK-{a.set}').read().split()[0]
    assert hashlib.sha256(open(f'{ROOT}/eval/scenarios-{a.set}.json', 'rb').read()).hexdigest() == lock, f'scenarios-{a.set}.json differs from LOCK-{a.set}'
    if a.scenarios != 'all':
        want = set(a.scenarios.split(',')); scenarios = [s for s in scenarios if s['id'] in want]
    jobs = []
    for model in a.models.split(','):
        cells = [(f, s, r) for f in a.formats.split(',') for s in scenarios for r in range(1, a.reps + 1)]
        random.Random(f'{a.seed}:{model}').shuffle(cells)   # presentation order randomised per model
        for order, (f, s, r) in enumerate(cells):
            out = f'{ROOT}/results/raw-{a.set}/{model}/{f}/{s["id"]}-r{r}.json'
            if os.path.exists(out): continue
            jobs.append((model, f, s, r, order, out))
    print(f'{len(jobs)} calls to make', file=sys.stderr)
    if a.dry: return
    def one(job):
        model, f, s, r, order, out = job
        fmt_text = open(f'{ROOT}/variants/{f}.txt').read()
        prompt = build(fmt_text, s)
        t0 = time.time(); res = ask(model, SYSTEM, prompt)
        rec = dict(set=a.set, model=model, format=f, scenario=s['id'], rep=r, order=order, seed=a.seed,
                   prompt_sha256=hashlib.sha256((SYSTEM + prompt).encode()).hexdigest(),
                   seconds=round(time.time() - t0, 1), **res)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        json.dump(rec, open(out, 'w'), indent=1)
        return rec
    spent = 0.0; done = 0
    with ThreadPoolExecutor(a.jobs) as ex:
        for rec in ex.map(one, jobs):
            spent += rec.get('cost_usd') or 0; done += 1
            if done % 10 == 0: print(f'{done}/{len(jobs)} list-cost so far ${spent:.2f}', file=sys.stderr)
    print(f'done {done} calls, list-cost ${spent:.2f}', file=sys.stderr)
if __name__ == '__main__': main()
