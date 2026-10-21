#!/usr/bin/env python3
"""Three formats for the same four cases: F0 the current IZ4 (mode line + heading word),
F1 the current clauses plus CHANGE and CHECK on every invariant including the foundation,
F2 Promise Cards.  States: (change, check) with change in {none, signed, canon} and
check in {report, block, canon}."""
import json, os, re, textwrap
HERE = os.path.dirname(os.path.abspath(__file__))
import importlib.util
spec = importlib.util.spec_from_file_location('gen0', os.path.join(HERE, 'gen0.py')); g0 = importlib.util.module_from_spec(spec); spec.loader.exec_module(g0)
SC = {k: g0.SCENARIOS[k] for k in ('startup', 'payments', 'mature')}
STATE = {'D': ('none', 'report'), 'F': ('signed', 'report'), 'H': ('signed', 'block')}
CHANGE = {'none': 'no approval', 'signed': 'signed human approval', 'canon': 'canonical foundation release only'}
HELDBY = {('none','report'): 'no one yet', ('signed','report'): 'signed human approval', ('signed','block'): 'signed human approval and its tests', ('canon','canon'): 'the foundation, word for word in every IZ4'}
ASKED = {'none': 'no approval needed', 'signed': 'signed human approval', 'canon': 'a foundation release; never a project'}
FAILS = {'report': 'the failure is reported', 'block': 'the commit is held', 'canon': 'no tests; the words are matched to the foundation'}
SENT_CH = {'none': 'Anyone may change this promise, without approval.', 'signed': 'Changing this promise takes signed human approval.', 'canon': 'Only a foundation release changes this promise; no project can.'}
SENT_CK = {'report': 'A failing linked test is reported.', 'block': 'A failing linked test holds the commit.', 'canon': 'Its words are matched to the canonical foundation.'}
def sentences(name, where, always, protects, ch, ck):
    import textwrap
    body = clauses(name, where, always, protects).rstrip('\n')
    return body + '\n\n  ' + SENT_CH[ch] + ' ' + SENT_CK[ck] + '\n\n'
CHECK  = {'report': 'report linked test failures', 'block': 'block on linked test failure', 'canon': 'match canonical foundation'}

# the foundation, parsed from the canonical block so the words are the canonical words
def parse_foundation():
    txt = g0.FOUNDATION; out = []
    for m in re.finditer(r'^(\S+?):\n((?:  .*\n)+)', txt, re.M):
        name, body = m.group(1), m.group(2)
        cl = {}
        for c in ('WHERE', 'ALWAYS', 'PROTECTS'):
            mm = re.search(r'  ' + c + r':\s+(.*?)(?=\n  [A-Z]+:|\Z)', body, re.S)
            cl[c] = ' '.join(mm.group(1).split())
        out.append((name, cl))
    return out
FOUND = parse_foundation()

def wrap(label, text, width=72):
    return textwrap.fill(text, width, initial_indent=f"  {label + ':':<10}", subsequent_indent=' ' * 12)

def clauses(name, where, always, protects, head='', extra=()):
    lines = [f"{name}:{(' ' + head) if head else ''}", wrap('WHERE', where), wrap('ALWAYS', always), wrap('PROTECTS', protects)]
    w = max([10] + [len(k) + 2 for k, _ in extra]); lines += [f"  {k + ':':<{w}}{v}" for k, v in extra]
    return '\n'.join(lines) + '\n\n'

def card(fqn, where, always, protects, change, check):
    w = textwrap.fill('When ' + where + ':', 60, initial_indent='    ', subsequent_indent='    ')
    a = textwrap.fill(always, 60, initial_indent='    ', subsequent_indent='    ')
    p = textwrap.fill('Protects ' + protects + '.', 60, initial_indent='    ', subsequent_indent='    ')
    return f"PROMISE {fqn}\n\n{w}\n{a}\n\n{p}\n\n    CHANGE: {change}\n    CHECK:  {check}\n\n"

def render(fmt, key):
    sc = SC[key]; d = sc['domain']
    head = [f"IZ4 {d}\n\n", f"IS FOR WHAT?  {sc['what']}\n\n", f"IS FOR WHO?   {sc['who']}\n\n"]
    out = []
    states = [i[1] for i in sc['inv']]
    if fmt == 'F0-current':
        rank = {'D': 0, 'F': 1, 'H': 2}; base = min(states, key=rank.get)
        if base == 'D': head.insert(1, g0.VIBE + '\n\n')
        if base == 'F': head.insert(1, g0.FIRM + '\n\n')
        for name, st, where, always, protects in sc['inv']:
            word = {'D': 'vibe', 'F': 'firm', 'H': 'solid'}[st] if rank[st] > rank[base] else ''
            out.append(clauses(name, where, always, protects, head=word))
        return ''.join(head + out) + g0.FOUNDATION
    sep = "# ----------------------------------------------------------------------\n# The foundation: the same words in every IZ4.\n"
    for name, st, where, always, protects in sc['inv']:
        ch, ck = STATE[st]
        if fmt == 'F1-clauses':
            out.append(clauses(name, where, always, protects, extra=(('CHANGE', CHANGE[ch]), ('CHECK', CHECK[ck]))))
        elif fmt == 'F3-heldby':
            out.append(clauses(f"{name}.{d}", where, always, protects, extra=(('HELD BY', HELDBY[(ch, ck)]),)))
        elif fmt == 'F4-asked':
            out.append(clauses(f"{name}.{d}", where, always, protects, extra=(('TO CHANGE', ASKED[ch]), ('IF A TEST FAILS', FAILS[ck]))))
        elif fmt == 'F5-sentences':
            out.append(sentences(f"{name}.{d}", where, always, protects, ch, ck))
        else:
            out.append(card(f"{name}.{d}", where, always, protects, CHANGE[ch], CHECK[ck]))
    out.append(sep)
    for name, cl in FOUND:
        if fmt == 'F1-clauses':
            out.append(clauses(name, cl['WHERE'], cl['ALWAYS'], cl['PROTECTS'], extra=(('CHANGE', CHANGE['canon']), ('CHECK', CHECK['canon']))))
        elif fmt == 'F3-heldby':
            out.append(clauses(name, cl['WHERE'], cl['ALWAYS'], cl['PROTECTS'], extra=(('HELD BY', HELDBY[('canon','canon')]),)))
        elif fmt == 'F4-asked':
            out.append(clauses(name, cl['WHERE'], cl['ALWAYS'], cl['PROTECTS'], extra=(('TO CHANGE', ASKED['canon']), ('IF A TEST FAILS', FAILS['canon']))))
        elif fmt == 'F5-sentences':
            out.append(sentences(name, cl['WHERE'], cl['ALWAYS'], cl['PROTECTS'], 'canon', 'canon'))
        else:
            out.append(card(name, cl['WHERE'], cl['ALWAYS'], cl['PROTECTS'], CHANGE['canon'], CHECK['canon']))
    return ''.join(head + out).rstrip('\n') + '\n'

FORMATS = ['F0-current', 'F1-clauses', 'F2-cards', 'F3-heldby', 'F4-asked', 'F5-sentences']
if __name__ == '__main__':
    os.makedirs('files', exist_ok=True)
    truth = {}
    for k, sc in SC.items():
        truth[k] = [dict(name=n, fqn=f"{n}.{sc['domain']}", state=STATE[st], where=w, always=a, protects=p) for n, st, w, a, p in sc['inv']]
        hf = dict(FOUND)['humans-first.iz4.you']
        truth[k].append(dict(name='humans-first.iz4.you', fqn='humans-first.iz4.you', state=('canon', 'canon'), where=hf['WHERE'], always=hf['ALWAYS'], protects=hf['PROTECTS']))
        for f in FORMATS: open(f'files/{f}--{k}.IZ4', 'w').write(render(f, k))
    json.dump(truth, open('truth.json', 'w'), indent=1)
    print('ok')
