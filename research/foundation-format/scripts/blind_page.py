#!/usr/bin/env python3
"""Render human/blind-review.md as a page: the lettered formulations, a timer
per invariant, the six questions with answer boxes kept in the reader's own
browser, and a button that copies every answer as markdown to paste back.
The key is never in the page.  Writes human/blind-review.html."""
import html, os, re, sys
sys.path.insert(0, os.path.dirname(__file__)); from preserve import NAMES
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
md = open(f'{ROOT}/human/blind-review.md').read()
QUESTIONS = ["Which formulation did you understand fastest? Rank your top two (letters).",
             "In one sentence, what does your top choice mean?",
             "Who does it protect, and who carries the obligation?",
             "Name one thing that would violate it.",
             "Is anything confusing or ambiguous in any of the seven? Which letters?",
             "How confident are you in your reading of your top choice: low, medium or high?"]
SHORT = ['humans-first', 'do-no-harm', 'human-agency', 'honesty', 'binding']
sections = re.split(r'^## Invariant (\d): `(\S+)`\n', md, flags=re.M)[1:]
inv = []
for i in range(0, len(sections), 3):
    num, name, body = sections[i], sections[i+1], sections[i+2]
    blocks = re.findall(r'^### ([A-Z])\n\n```text\n(.*?)```', body, flags=re.S | re.M)
    inv.append((int(num), name, blocks))
css = """
<title>Foundation blind review</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
/* layout: one reading column, 68ch, the clauses as they sit in an IZ4 file, answers under each invariant */
:root{--bg:#f6f7f4;--fg:#1c2420;--muted:#5e6a63;--rule:#d3d9d4;--panel:#ffffff;--accent:#1f7a4c;--accent-ink:#ffffff;--code:#eef2ee;
 --sans:'IBM Plex Sans',system-ui,-apple-system,'Segoe UI',sans-serif;--mono:'IBM Plex Mono',ui-monospace,Menlo,Consolas,monospace}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#111614;--fg:#e8ebe7;--muted:#9aa49d;--rule:#2a332d;--panel:#171d1a;--accent:#5fcf8f;--accent-ink:#0d130f;--code:#1b2320;color-scheme:dark}}
:root[data-theme="dark"]{--bg:#111614;--fg:#e8ebe7;--muted:#9aa49d;--rule:#2a332d;--panel:#171d1a;--accent:#5fcf8f;--accent-ink:#0d130f;--code:#1b2320;color-scheme:dark}
body{background:var(--bg);color:var(--fg);font-family:var(--sans);font-size:17px;line-height:1.55;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px));padding-block:32px 96px}
main{max-width:72ch;margin:0 auto}
h1{font-size:2rem;line-height:1.15;text-wrap:balance;margin:0 0 .5rem;font-weight:600}
h2{font-size:1.35rem;margin:0;font-weight:600;text-wrap:balance}
h3{font-size:1rem;margin:0;font-weight:600;color:var(--muted);letter-spacing:.04em;text-transform:uppercase}
p{margin:0}
.lead{color:var(--muted);max-width:65ch}
ol.howto{padding-left:1.3rem;margin:0;display:grid;gap:.35rem}
.intro{display:grid;gap:1rem;padding-bottom:2rem;border-bottom:1px solid var(--rule)}
.name{font-family:var(--mono);font-size:.95rem;color:var(--accent)}
section.inv{display:grid;gap:1.25rem;padding-block:2.5rem;border-bottom:1px solid var(--rule)}
.head{display:flex;flex-wrap:wrap;gap:.75rem 1.5rem;align-items:baseline;justify-content:space-between}
.timer{display:flex;gap:.5rem;align-items:center;font-family:var(--mono);font-size:.9rem;color:var(--muted)}
button{font:inherit;font-family:var(--mono);font-size:.85rem;padding:.4rem .8rem;border-radius:6px;border:1px solid var(--rule);background:var(--panel);color:var(--fg);cursor:pointer}
button.primary{background:var(--accent);color:var(--accent-ink);border-color:var(--accent)}
button:focus-visible,textarea:focus-visible,input:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
.forms{display:grid;gap:1rem}
.form{display:grid;grid-template-columns:2.2rem 1fr;gap:0 .75rem;align-items:start}
.letter{font-family:var(--mono);font-weight:500;color:var(--accent);font-size:1.1rem;padding-top:.6rem}
pre{margin:0;font-family:var(--mono);font-size:.86rem;line-height:1.5;background:var(--code);padding:.75rem 1rem;border-radius:6px;overflow-x:auto;min-width:0}
.answers{display:grid;gap:.9rem;background:var(--panel);border:1px solid var(--rule);border-radius:8px;padding:1.1rem 1.1rem 1.25rem}
label{display:grid;gap:.3rem;font-size:.95rem}
textarea,input[type=text]{font:inherit;font-size:.95rem;width:100%;box-sizing:border-box;border:1px solid var(--rule);border-radius:6px;padding:.5rem .65rem;background:var(--bg);color:var(--fg);min-height:2.4rem}
textarea{min-height:3.6rem;resize:vertical}
.foot{display:grid;gap:1rem;padding-top:2.5rem}
.row{display:flex;flex-wrap:wrap;gap:.75rem;align-items:center}
.status{font-family:var(--mono);font-size:.85rem;color:var(--muted)}
#out{display:none}
@media (prefers-reduced-motion:no-preference){button{transition:background .15s}}
</style>
"""
out = [css, '<main>', '<div class="intro">',
       '<p class="name">IZ4 &middot; the foundation</p>',
       '<h1>Seven ways to say each invariant. Which did you understand?</h1>',
       '<p class="lead">Each of the foundation&#8217;s invariants follows in seven formulations, under letters that change from one invariant to the next. One of them is the current text. There is no right ranking; reading time and your own sense of clarity are what is being measured.</p>',
       '<ol class="howto"><li>Press <b>Start</b> before you read an invariant&#8217;s seven formulations, and <b>Done</b> when you have read them.</li><li>Answer the six questions under it. Answers stay in this browser until you copy them.</li><li>At the end, <b>Copy answers</b> and paste them to Nige&#8217;s session or into <code>human/answers-&lt;you&gt;.md</code>. The key that says which letter is which is not on this page.</li></ol>',
       '</div>']
for num, name, blocks in inv:
    sid = SHORT[num]
    out.append(f'<section class="inv" id="{sid}">')
    out.append(f'<div class="head"><div><p class="name">Invariant {num}</p><h2>{html.escape(name)}</h2></div>'
               f'<div class="timer"><button id="start-{sid}" type="button" data-start="{sid}">Start</button><button id="done-{sid}" type="button" data-done="{sid}">Done</button><span id="time-{sid}">not timed yet</span></div></div>')
    out.append('<div class="forms">')
    for letter, text in blocks:
        out.append(f'<div class="form"><span class="letter">{letter}</span><pre>{html.escape(text.rstrip())}</pre></div>')
    out.append('</div>')
    out.append('<div class="answers"><h3>Your answers</h3>')
    for qi, q in enumerate(QUESTIONS, 1):
        tag = 'input type="text"' if qi in (1, 6) else 'textarea'
        close = '' if qi in (1, 6) else '</textarea>'
        out.append(f'<label for="a-{sid}-{qi}">{qi}. {html.escape(q)}<{tag} id="a-{sid}-{qi}" data-answer="{sid}:{qi}">{close}</label>')
    out.append('</div></section>')
out.append('<div class="foot"><h3>When you have finished</h3>'
           '<div class="row"><button class="primary" id="copy" type="button">Copy answers as markdown</button><button id="clear" type="button">Clear everything on this page</button><span class="status" id="status"></span></div>'
           '<p class="lead">If copying is refused by your browser, the text appears below to select by hand.</p><textarea id="out" rows="14" readonly></textarea></div>')
out.append('</main>')
names_js = ','.join(f'"{s}":"{n}"' for s, n in zip(SHORT, NAMES))
qs_js = ','.join('"' + q.replace('"', '\\"') + '"' for q in QUESTIONS)
out.append("""<script>
(function(){
var NAMES={%s}; var QS=[%s]; var KEY='iz4-blind-review-v1';
function load(){try{return JSON.parse(localStorage.getItem(KEY)||'{}')}catch(e){return {}}}
function save(d){try{localStorage.setItem(KEY,JSON.stringify(d))}catch(e){}}
var data=load();
function fmt(ms){var s=Math.round(ms/1000);return Math.floor(s/60)+'m '+String(s%%60).padStart(2,'0')+'s'}
function showTime(id){var t=(data.time||{})[id];var el=document.getElementById('time-'+id);
  if(!t||!t.start){el.textContent='not timed yet';return}
  if(!t.done){el.textContent='reading…';return}
  el.textContent=fmt(t.done-t.start)}
document.querySelectorAll('[data-start]').forEach(function(b){b.addEventListener('click',function(){var id=b.dataset.start;data.time=data.time||{};data.time[id]={start:Date.now()};save(data);showTime(id)})});
document.querySelectorAll('[data-done]').forEach(function(b){b.addEventListener('click',function(){var id=b.dataset.done;data.time=data.time||{};var t=data.time[id]||{start:Date.now()};t.done=Date.now();data.time[id]=t;save(data);showTime(id)})});
document.querySelectorAll('[data-answer]').forEach(function(el){var k=el.dataset.answer;if((data.answers||{})[k])el.value=data.answers[k];
  el.addEventListener('input',function(){data.answers=data.answers||{};data.answers[k]=el.value;save(data)})});
Object.keys(NAMES).forEach(showTime);
function markdown(){var lines=['# Blind review answers','','Reader: ','Date: '+new Date().toISOString().slice(0,10),''];
  Object.keys(NAMES).forEach(function(id){var t=(data.time||{})[id];lines.push('## '+NAMES[id]);lines.push('');
    lines.push('Reading time: '+(t&&t.done?fmt(t.done-t.start):'not timed'));lines.push('');
    QS.forEach(function(q,i){lines.push((i+1)+'. '+q);lines.push('   '+(((data.answers||{})[id+':'+(i+1)])||'').replace(/\\n/g,'\\n   '));lines.push('')})});
  return lines.join('\\n')}
var status=document.getElementById('status'),outEl=document.getElementById('out');
document.getElementById('copy').addEventListener('click',function(){var md=markdown();outEl.value=md;
  function fallback(){outEl.style.display='block';outEl.focus();outEl.select();status.textContent='Select the text below and copy it.'}
  if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(md).then(function(){status.textContent='Copied. Paste it to the session or into your answers file.'},fallback)}else fallback()});
document.getElementById('clear').addEventListener('click',function(){if(status.textContent!=='Press Clear again to confirm.'){status.textContent='Press Clear again to confirm.';return}
  data={};save(data);document.querySelectorAll('[data-answer]').forEach(function(el){el.value=''});Object.keys(NAMES).forEach(showTime);outEl.value='';outEl.style.display='none';status.textContent='Cleared.'});
})();
</script>""" % (names_js, qs_js))
open(f'{ROOT}/human/blind-review.html', 'w').write('\n'.join(out))
print('written', len('\n'.join(out)), 'bytes;', sum(len(b) for _, _, b in inv), 'formulations')
