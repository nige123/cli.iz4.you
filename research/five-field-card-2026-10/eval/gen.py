#!/usr/bin/env python3
"""G0 today's format; G1 the paragraph Promise Card (CHANGE BY / TEST BY); G2 the five-field card."""
import json, os, re, textwrap, importlib.util
HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('gen0', os.path.join(HERE, 'gen0.py')); g0 = importlib.util.module_from_spec(spec); spec.loader.exec_module(g0)
SC = {k: g0.SCENARIOS[k] for k in ('startup', 'payments', 'mature')}
SC['showcase'] = dict(domain='app.example.com',
  what='Letting a small team share work with the people they choose.', who='Small teams, and the people they invite.',
  inv=[('easy-onboarding','D','someone joins the application','Getting started is straightforward.',"people's time and attention"),
       ('deleted-means-gone','D','a person deletes something they own','It is gone from every view within the hour, not merely hidden.',"a person's say over what they keep"),
       ('private-profile','F','a profile is marked private','Only its owner and people they choose can learn what it reveals.',"the owner's privacy and control"),
       ('export-is-complete','H','a team exports its workspace','The export holds everything the team can see, nothing less.',"a team's ownership of its own work"),
       ('single-use-code','H','a sign-in code is submitted','It works at most once, before expiry, including concurrent submissions.','accounts from unauthorised access')])
STATE = {'D': ('none','report'), 'F': ('signed','report'), 'H': ('signed','block')}
G1_CH = {'none': 'anyone, without approval; this promise is still being worked out', 'signed': "a person's signed approval, bound to the exact change", 'canon': 'a foundation release only; no project can change it'}
G1_TE = {'report': 'its linked tests; a failure is reported, the commit is not held', 'block': 'its linked tests; a failure holds the commit until a person decides', 'canon': 'matching its words to the foundation, word for word; no tests apply'}
G2_CH = {'none': 'wording may change without approval', 'signed': 'signed approval from an authorised person, bound to the exact change', 'canon': 'verified foundation release only; never within a project'}
G2_CK = {'report': 'failing linked tests warn, never block', 'block': 'failing linked tests block the commit, pending authorised override', 'canon': 'exact match to canonical foundation'}

def parse_foundation():
    out = []
    for m in re.finditer(r'^(\S+?):\n((?:  .*\n)+)', g0.FOUNDATION, re.M):
        name, body = m.group(1), m.group(2); cl = {}
        for c in ('WHERE','ALWAYS','PROTECTS'):
            mm = re.search(r'  ' + c + r':\s+(.*?)(?=\n  [A-Z]+:|\Z)', body, re.S); cl[c] = ' '.join(mm.group(1).split())
        out.append((name, cl))
    return out
FOUND = parse_foundation()

def field(label, text, col=12, width=72):
    return textwrap.fill(text, width, initial_indent=f"  {label + ':':<{col-2}}", subsequent_indent=' ' * col)
def g0_block(name, where, always, protects, head=''):
    return '\n'.join([f"{name}:{(' '+head) if head else ''}", field('WHERE', where), field('ALWAYS', always), field('PROTECTS', protects)]) + '\n\n'
def g1_card(fqn, where, always, protects, ch, ck):
    f = lambda t: textwrap.fill(t, 74, initial_indent='  ', subsequent_indent='  ')
    return f"PROMISE {fqn}\n\n{f('When ' + where + ':')}\n\n{f(always)}\n\n{f('Protects ' + protects + '.')}\n\n  CHANGE BY: {G1_CH[ch]}\n  TEST BY:   {G1_TE[ck]}\n\n"
def g2_card(fqn, where, always, protects, ch, ck, kw='PROMISE'):
    top = '\n'.join([field('WHEN', where, 12, 66), field('ALWAYS', always, 12, 66), field('PROTECTS', protects, 12, 66)])
    foot = '\n'.join([field('CHANGE BY', G2_CH[ch], 13, 66), field('CHECK BY', G2_CK[ck], 13, 66)])
    return f"{kw} {fqn}\n\n{top}\n\n{foot}\n\n"

G3_CH = dict(G2_CH, none='wording may change without approval; until it does, the promise binds as written')
def g3_card(fqn, where, always, protects, ch, ck, kw='PROMISE'):
    top = '\n'.join([field('WHEN', where, 12, 66), field('ALWAYS', always, 12, 66), field('PROTECTS', protects, 12, 66)])
    foot = '\n'.join([field('CHANGE BY', G3_CH[ch], 13, 66), field('CHECK BY', G2_CK[ck], 13, 66)])
    return f"{kw} {fqn}\n\n{top}\n\n{foot}\n\n"

def render(fmt, key):
    sc = SC[key]; d = sc['domain']
    head = [f"IZ4 {d}\n\n", f"IS FOR WHAT?  {sc['what']}\n\n", f"IS FOR WHO?   {sc['who']}\n\n"]; out = []
    states = [i[1] for i in sc['inv']]
    if fmt == 'G0-current':
        rank = {'D':0,'F':1,'H':2}; base = min(states, key=rank.get)
        if base == 'D': head.insert(1, g0.VIBE + '\n\n')
        if base == 'F': head.insert(1, g0.FIRM + '\n\n')
        for name, st, w, a, p in sc['inv']:
            out.append(g0_block(name, w, a, p, head={'D':'vibe','F':'firm','H':'solid'}[st] if rank[st] > rank[base] else ''))
        return ''.join(head + out) + g0.FOUNDATION
    sep = "# ----------------------------------------------------------------------\n# The foundation: the same words in every IZ4.\n\n"
    for name, st, w, a, p in sc['inv']:
        ch, ck = STATE[st]
        out.append(g1_card(f"{name}.{d}", w, a, p, ch, ck) if fmt == 'G1-paragraph' else g3_card(f"{name}.{d}", w, a, p, ch, ck) if fmt == 'G3-five-field-binds' else g2_card(f"{name}.{d}", w, a, p, ch, ck))
    out.append(sep)
    for name, cl in FOUND:
        out.append(g1_card(name, cl['WHERE'], cl['ALWAYS'], cl['PROTECTS'], 'canon', 'canon') if fmt == 'G1-paragraph'
                   else g3_card(name, cl['WHERE'], cl['ALWAYS'], cl['PROTECTS'], 'canon', 'canon', kw='FOUNDATION') if fmt == 'G3-five-field-binds'
                   else g2_card(name, cl['WHERE'], cl['ALWAYS'], cl['PROTECTS'], 'canon', 'canon', kw='FOUNDATION'))
    return ''.join(head + out).rstrip('\n') + '\n'

FORMATS = ['G0-current', 'G1-paragraph', 'G2-five-field', 'G3-five-field-binds']
if __name__ == '__main__':
    os.makedirs('files', exist_ok=True); truth = {}
    for k, sc in SC.items():
        truth[k] = [dict(name=n, fqn=f"{n}.{sc['domain']}", state=STATE[st], where=w, always=a, protects=p) for n, st, w, a, p in sc['inv']]
        hf = dict(FOUND)['humans-first.iz4.you']
        truth[k].append(dict(name='humans-first.iz4.you', fqn='humans-first.iz4.you', state=('canon','canon'), where=hf['WHERE'], always=hf['ALWAYS'], protects=hf['PROTECTS']))
        for f in FORMATS: open(f'files/{f}--{k}.IZ4', 'w').write(render(f, k))
    json.dump(truth, open('truth.json', 'w'), indent=1); print('ok')
