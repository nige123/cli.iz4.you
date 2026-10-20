#!/usr/bin/env python3
"""Mechanical readability and parsing measures for every variant: words, lines,
labels, longest clause, lines over 80 columns, words per invariant, and
whether the current iz4 grammar (WHERE/ALWAYS/PROTECTS) would accept it.
Prints a markdown table and writes results/measures.md."""
import os, re, sys
sys.path.insert(0, os.path.dirname(__file__)); from preserve import blocks, NAMES
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
CURRENT = {'WHERE', 'ALWAYS', 'PROTECTS'}
def measure(v):
    text = open(f'{ROOT}/variants/{v}.txt').read(); b = blocks(text)
    labels = sorted(set(re.findall(r'^\s+([A-Z]+):', text, re.M)))
    clauses = []
    for n, t in b.items():
        body = t.split('\n', 1)[1] if '\n' in t else ''
        parts = re.split(r'^\s+[A-Z]+:\s*', body + '\n', flags=re.M)
        clauses += [len(p.split()) for p in parts if p.strip()]
    per_inv = [len(t.split()) - 1 for t in b.values()]
    return dict(variant=v, words=sum(per_inv), lines=sum(1 for l in text.split('\n') if l.strip()),
                labels='/'.join(labels) or '(statement)', n_labels=len(labels), longest_clause=max(clauses) if clauses else 0,
                mean_clause=round(sum(clauses) / len(clauses), 1) if clauses else 0, over80=sum(1 for l in text.split('\n') if len(l) > 80),
                min_inv=min(per_inv), max_inv=max(per_inv), parses_today='yes' if set(labels) == CURRENT else 'no')
def main():
    vs = sorted(f[:-4] for f in os.listdir(f'{ROOT}/variants') if f.endswith('.txt') and f != 'none.txt')
    rows = [measure(v) for v in vs]
    hdr = ['variant', 'words', 'lines', 'labels', 'longest clause', 'mean clause', 'words/invariant min..max', 'lines > 80 cols', 'parses with iz4 0.24']
    out = ['| ' + ' | '.join(hdr) + ' |', '|' + '---|' * len(hdr)]
    for r in rows:
        out.append(f"| {r['variant']} | {r['words']} | {r['lines']} | {r['labels']} | {r['longest_clause']} | {r['mean_clause']} | {r['min_inv']}..{r['max_inv']} | {r['over80']} | {r['parses_today']} |")
    open(f'{ROOT}/results/measures.md', 'w').write('# Mechanical measures\n\n' + '\n'.join(out) + '\n')
    print('\n'.join(out))
if __name__ == '__main__': main()
