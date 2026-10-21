#!/usr/bin/env python3
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from parser import parse, Bad
G = open('files/G2-five-field--showcase.IZ4').read()
card = """PROMISE charged-once.app.paydance.com

  WHEN:     payment is attempted for an order
  ALWAYS:   no more than one successful charge per order,
            even with retries
  PROTECTS: customers from paying twice

  CHANGE BY: signed approval from an authorised person,
             bound to the exact change
  CHECK BY:  failing linked tests block the commit,
             pending authorised override
"""
def expect(name, text, ok, needle=None):
    try:
        cards = parse(text); result = 'parsed'
        if not ok: print(f"- FAIL {name}: parsed but should be rejected"); return
        print(f"- ok   {name}: parsed {len(cards)} card(s)" + (f"; {needle}" if needle else ''))
    except Bad as e:
        if ok: print(f"- FAIL {name}: rejected: {e}"); return
        print(f"- ok   {name}: rejected: {e}")
expect('the whole showcase file, five project cards and the foundation', G, True)
cs = parse(G)
hf = [c for c in cs if c['name'] == 'humans-first.iz4.you'][0]
print(f"  humans-first ALWAYS reassembled across wrapped lines, colon inside prose kept: {hf['fields']['ALWAYS']!r}")
print(f"  five-field footer values recognised: change={hf['change']} check={hf['check']}; project single-use-code: " + str([(c['change'], c['check']) for c in cs if c['name'].startswith('single-use')]))
expect('the brief\'s own example card, wrapped footer values', card, True, 'wrapped CHANGE BY/CHECK BY rejoined and matched')
expect('a colon in ordinary prose (ALWAYS: "dignity: no goal")', card.replace('no more than one successful charge per order', 'one rule: one successful charge per order'), True)
expect('a field re-wrapped at a different width', card.replace('one successful charge per order,\n            even with retries', 'one successful charge\n            per order, even with retries'), True, 'wrapping does not change the parsed text')
expect('missing PROTECTS', card.replace('  PROTECTS: customers from paying twice\n', ''), False)
expect('CHANGE BY given twice', card.replace('  CHECK BY:', '  CHANGE BY: wording may change without approval\n  CHECK BY:'), False)
expect('fields reordered (PROTECTS before ALWAYS)', card.replace('  ALWAYS:   no more than one successful charge per order,\n            even with retries\n  PROTECTS: customers from paying twice', '  PROTECTS: customers from paying twice\n  ALWAYS:   no more than one successful charge per order,\n            even with retries'), False)
expect('a footer value off by one word', card.replace('never within', 'never within').replace('pending authorised override', 'pending an authorised override'), False)
expect('free wording with blocking tests', card.replace('signed approval from an authorised person,\n             bound to the exact change', 'wording may change without approval'), False)
expect('foundation values on a project promise', card.replace('signed approval from an authorised person,\n             bound to the exact change', 'verified foundation release only; never within a project').replace('failing linked tests block the commit,\n             pending authorised override', 'exact match to canonical foundation'), False)
expect('PROMISE heading on a foundation name', G.replace('FOUNDATION humans-first.iz4.you', 'PROMISE humans-first.iz4.you'), False)
expect('project values on a foundation card', G.replace('  CHANGE BY: verified foundation release only; never within a\n             project\n  CHECK BY:  exact match to canonical foundation', '  CHANGE BY: wording may change without approval\n  CHECK BY:  failing linked tests warn, never block', 1), False)
expect('a name without a domain', card.replace('charged-once.app.paydance.com', 'charged-once'), False)
expect('a name with a capital letter', card.replace('charged-once.app.paydance.com', 'Charged-once.app.paydance.com'), False)
expect('no blank line between the two groups', card.replace('twice\n\n  CHANGE', 'twice\n  CHANGE'), True, 'the blank line is for people; the parser does not need it')
expect('a continuation line indented like a label', card.replace('            even with retries', '  even with retries'), False)
expect('a lower-case label', card.replace('  CHECK BY:', '  check by:'), False)
expect('a stray line between cards', card + '\nnot a card\n', False)
expect('a comment line inside a card', card.replace('  PROTECTS:', '  # why: refunds are not charges\n  PROTECTS:'), True)
