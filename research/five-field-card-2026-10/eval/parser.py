#!/usr/bin/env python3
"""Reference parser for the five-field Promise Card, written to probe the parsing risks the brief lists.
A card: heading line 'PROMISE name.domain' or 'FOUNDATION name.iz4.you'; fields at indent 2 as 'LABEL:' then text;
continuation lines indented deeper than the label; blank lines separate groups and cards; '#' lines are comments."""
import re
FIELDS = ['WHEN', 'ALWAYS', 'PROTECTS', 'CHANGE BY', 'CHECK BY']
CHANGE = {'wording may change without approval': 'none',
          'signed approval from an authorised person, bound to the exact change': 'signed',
          'verified foundation release only; never within a project': 'canon'}
CHECK = {'failing linked tests warn, never block': 'report',
         'failing linked tests block the commit, pending authorised override': 'block',
         'exact match to canonical foundation': 'canon'}
FOUNDATION = {'humans-first.iz4.you', 'do-no-harm.iz4.you', 'human-agency.iz4.you', 'honesty.iz4.you', 'binding.iz4.you'}
NAME = re.compile(r'^[a-z0-9]+(-[a-z0-9]+)*(\.[a-z0-9]+(-[a-z0-9]+)*)+$')
class Bad(Exception): pass
def parse(text):
    cards, cur, field, lines = [], None, None, text.split('\n')
    for n, raw in enumerate(lines, 1):
        line = raw.rstrip()
        if line.lstrip().startswith('#'): continue
        if line.strip() and not line.startswith(' '):
            m = re.match(r'^(PROMISE|FOUNDATION) (\S+)$', line)
            if not m:
                if re.match(r'^(IZ4 |IS FOR WHAT\?|IS FOR WHO\?)', line): cur = None; field = None; continue
                raise Bad(f"line {n}: not a heading: {line!r}")
            if not NAME.match(m.group(2)): raise Bad(f"line {n}: not a domain-qualified name: {m.group(2)!r}")
            cur = dict(kind=m.group(1), name=m.group(2), fields={}, order=[], line=n); cards.append(cur); field = None; continue
        if cur is None: continue
        if not line.strip(): field = None; continue
        m = re.match(r'^  ([A-Z][A-Z ]*?):(?:\s+(.*))?$', line)
        if m and m.group(1) in FIELDS:
            label = m.group(1)
            if label in cur['fields']: raise Bad(f"line {n}: {label} given twice in {cur['name']}")
            cur['fields'][label] = (m.group(2) or '').strip(); cur['order'].append(label); field = label; continue
        if field and len(line) - len(line.lstrip()) >= 4:
            cur['fields'][field] = (cur['fields'][field] + ' ' + line.strip()).strip(); continue
        raise Bad(f"line {n}: unexpected line in {cur['name']}: {line!r}")
    for c in cards:
        missing = [f for f in FIELDS if f not in c['fields']]
        if missing: raise Bad(f"{c['name']}: missing {', '.join(missing)}")
        if c['order'] != FIELDS: raise Bad(f"{c['name']}: fields out of order: {c['order']}")
        ch, ck = CHANGE.get(c['fields']['CHANGE BY']), CHECK.get(c['fields']['CHECK BY'])
        if ch is None: raise Bad(f"{c['name']}: CHANGE BY is not a permitted value: {c['fields']['CHANGE BY']!r}")
        if ck is None: raise Bad(f"{c['name']}: CHECK BY is not a permitted value: {c['fields']['CHECK BY']!r}")
        if ch == 'none' and ck == 'block': raise Bad(f"{c['name']}: a blocking test policy with freely editable wording")
        isf = c['name'] in FOUNDATION
        if isf != (c['kind'] == 'FOUNDATION'): raise Bad(f"{c['name']}: heading {c['kind']} does not fit the name")
        if isf != (ch == 'canon') or isf != (ck == 'canon'): raise Bad(f"{c['name']}: foundation values on a project promise, or project values on the foundation")
        for f in ('WHEN', 'ALWAYS', 'PROTECTS'):
            if not c['fields'][f]: raise Bad(f"{c['name']}: {f} is empty")
        c['change'], c['check'] = ch, ck
    return cards
