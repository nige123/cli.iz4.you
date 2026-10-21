#!/usr/bin/env python3
"""Render four realistic IZ4 files in each candidate protection syntax.
States: D = still settling (words free, tests advisory), F = words agreed, tests advisory,
H = held (words wait for a signed yes, a failing linked test holds the commit)."""
import json, os, sys, textwrap
HERE = os.path.dirname(os.path.abspath(__file__))
FOUNDATION = open(os.path.join(HERE, '..', 'foundation-block.txt')).read()

SCENARIOS = {
 'startup': dict(domain='nudge.example.com',
   what='Reminding people of the small habits they chose, at the moments they chose.',
   who='People building a habit, one nudge at a time.',
   inv=[('one-nudge-per-habit-per-day','D','a reminder is sent','A habit gets at most one reminder a day.','a person\'s attention, which the app borrows and must give back'),
        ('quiet-hours-are-quiet','D','the person set quiet hours','No reminder is sent inside the hours they set.','a person\'s sleep and rest'),
        ('leaving-takes-everything','D','a person deletes their account','Their habits, history and contact details go with it.','a person\'s say over what is kept about them')]),
 'payments': dict(domain='pay.example.com',
   what='Paying suppliers what they are owed, to the account they named.',
   who='Small businesses, and the suppliers they pay.',
   inv=[('paid-to-the-named-beneficiary','H','an invoice is paid','The money goes to the beneficiary and account named on the invoice being paid, never to details remembered from another.','a supplier\'s money reaching that supplier'),
        ('a-person-releases-large-payments','F','a payment over the limit is released','A payment over the limit is released only when a named person approved it; the system never approves on their behalf.','the owner\'s say over where large sums go'),
        ('config-from-trusted-paths','D','the service reads its configuration','Configuration is read only from the paths the operator installed; the working directory is never one of them.','the operator\'s control over what the service believes'),
        ('receipts-are-kept','D','a payment completes','A receipt is kept for every payment made.','a business\'s record of what it paid')]),
 'mature': dict(domain='ledger.example.com',
   what='Keeping a small company\'s books balanced and auditable.',
   who='Company owners and the accountants who check their books.',
   inv=[('every-entry-balances','H','an entry is posted','Debits equal credits in every posted entry.','the books being books at all'),
        ('posted-is-permanent','H','an entry has been posted','A posted entry is never edited or deleted; a correction is a new entry.','an auditor\'s trust that what they see is what happened'),
        ('exports-match-the-ledger','H','an export is produced','An export shows exactly what the ledger holds, nothing added and nothing left out.','an accountant\'s picture of the company'),
        ('ai-suggestions-are-marked','D','a categorisation is suggested by the assistant','A suggested categorisation is shown as a suggestion until a person accepts it.','a person\'s judgement over their own books')]),
 'safety': dict(domain='dose.example.com',
   what='Delivering the dose a clinician prescribed, at the rate they prescribed, and nothing else.',
   who='Patients on an infusion, and the clinicians caring for them.',
   inv=[('never-above-the-prescribed-rate','H','the pump is delivering','The delivery rate never exceeds the prescribed rate, whatever the input.','a patient\'s life'),
        ('stop-means-stop','H','a clinician presses stop','Delivery stops within one second, and nothing restarts it without a clinician.','a clinician\'s power to stop the machine'),
        ('alarm-cannot-be-silenced-forever','H','an alarm is sounding','An alarm can be paused, never disabled; a paused alarm returns.','a patient who cannot call for help themselves')]),
}

def level3(s): return {'D':'vibe','F':'firm','H':'solid'}[s]

VIBE = "# Vibe: this project's invariants are still settling. 'iz4 mode solid' when they are ready to hold."
FIRM = "# Firm: this project's invariants are agreed; their tests are still settling. 'iz4 mode solid' when the tests hold."

def body(name, where, always, protects, head_word='', extra=None):
    w = textwrap.fill(always, 72, initial_indent='  ALWAYS:   ', subsequent_indent='            ')
    lines = [f"{name}:{(' ' + head_word) if head_word else ''}",
             f"  WHERE:    {where}", w, f"  PROTECTS: {protects}"]
    if extra: lines.append(extra)
    return '\n'.join(lines) + '\n\n'

def render(syntax, sc):
    d = sc['domain']; out = [f"IZ4 {d}\n\n", f"IS FOR WHAT?  {sc['what']}\n\n", f"IS FOR WHO?   {sc['who']}\n\n"]
    states = [i[1] for i in sc['inv']]
    if syntax == 'S1-current':
        rank = {'D':0,'F':1,'H':2}; base = min(states, key=rank.get)
        if base == 'D': out.insert(1, VIBE + '\n\n')
        if base == 'F': out.insert(1, FIRM + '\n\n')
    for name, st, where, always, protects in sc['inv']:
        if syntax == 'S1-current':
            word = level3(st) if rank[st] > rank[base] else ''
            out.append(body(name, where, always, protects, head_word=word))
        elif syntax == 'S2-clause-vfs':
            out.append(body(name, where, always, protects, extra=f"  HOLD:     {level3(st)}"))
        elif syntax == 'S3-word-draft':
            out.append(body(name, where, always, protects, head_word='draft' if st == 'D' else ''))
        elif syntax == 'S4-clause-describes':
            v = {'D':'nothing yet','F':'the words','H':'the words and the tests'}[st]
            out.append(body(name, where, always, protects, extra=f"  HOLD:     {v}"))
        elif syntax == 'S5-word-three':
            out.append(body(name, where, always, protects, head_word={'D':'draft','F':'agreed','H':''}[st]))
        else: raise SystemExit(syntax)
    return ''.join(out) + FOUNDATION

SYNTAXES = ['S1-current','S2-clause-vfs','S3-word-draft','S4-clause-describes','S5-word-three']
if __name__ == '__main__':
    os.makedirs('files', exist_ok=True)
    for s in SYNTAXES:
        for k, sc in SCENARIOS.items():
            open(f'files/{s}--{k}.IZ4','w').write(render(s, sc))
    json.dump({k:[(i[0],i[1]) for i in sc['inv']] for k,sc in SCENARIOS.items()}, open('truth.json','w'), indent=1)
    print('ok', len(SYNTAXES)*len(SCENARIOS), 'files')
