#!/usr/bin/env python3
"""Task 10, behaviour: ask a model (one fresh context per invariant and
format) to shorten an invariant while keeping everything it requires; then a
separate grader context (opus) marks which reference requirements survived.
Writes results/revise.json and results/revise.md.
Usage: revise.py --models haiku,sonnet --formats A-equiv,F-short [--target 45]"""
import argparse, json, os, re, sys
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, os.path.dirname(__file__)); from ask import ask
from preserve import blocks, reference, NAMES, SYSTEM as GSYS, prompt as gprompt
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
SYS = "You are an AI coding agent working in a project that keeps an IZ4. Answer with the rewritten text only, in the same layout and labels as the original, no commentary."
def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--models', default='haiku'); ap.add_argument('--formats', required=True)
    ap.add_argument('--target', type=int, default=45); ap.add_argument('--grader', default='opus'); ap.add_argument('--jobs', type=int, default=4)
    a = ap.parse_args(); req = reference()
    outp = f'{ROOT}/results/revise.json'; res = json.load(open(outp)) if os.path.exists(outp) else {}
    jobs = [(m, f, n) for m in a.models.split(',') for f in a.formats.split(',') for n in NAMES if f'{m}/{f}/{n}' not in res]
    def one(j):
        m, f, n = j; b = blocks(open(f'{ROOT}/variants/{f}.txt').read())[n]
        p = (f"The project owner asks you to propose a shorter wording of this foundation invariant, about {a.target} words, "
             f"that keeps everything it requires and forbids. Nothing may be weakened.\n\n{b}")
        r = ask(m, SYS, p); text = (r.get('result') or '').strip()
        g = ask(a.grader, GSYS, gprompt(n, text, req[n]))
        mm = re.search(r'\{.*\}', g.get('result') or '', re.S)
        try: ans = json.loads(mm.group(0))
        except Exception: ans = dict(error=g.get('result') or g.get('error'))
        return f'{m}/{f}/{n}', dict(revision=text, words=len(text.split()), cost_usd=(r.get('cost_usd') or 0) + (g.get('cost_usd') or 0), **ans)
    with ThreadPoolExecutor(a.jobs) as ex:
        for k, v in ex.map(one, jobs): res[k] = v
    json.dump(res, open(outp, 'w'), indent=1)
    lines = ['| model | format | words (5 inv.) | present | weakened | absent |', '|---|---|---:|---:|---:|---:|']
    for m in sorted({k.split('/')[0] for k in res}):
        for f in sorted({k.split('/')[1] for k in res if k.startswith(m + '/')}):
            rs = [res[f'{m}/{f}/{n}'] for n in NAMES if f'{m}/{f}/{n}' in res]
            lines.append(f"| {m} | {f} | {sum(r['words'] for r in rs)} | {sum(len(r.get('present',[])) for r in rs)} | {sum(len(r.get('weakened',[])) for r in rs)} | {sum(len(r.get('absent',[])) for r in rs)} |")
    open(f'{ROOT}/results/revise.md', 'w').write('# Revision test: what survives when a model is asked to shorten an invariant\n\n' + '\n'.join(lines) + '\n')
    print('\n'.join(lines))
if __name__ == '__main__': main()
