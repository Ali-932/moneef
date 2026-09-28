#!/usr/bin/env python3
"""Build a local before/after gallery from the Flutter screenshot suite."""
import argparse
import html
import json
import shutil
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--before', required=True, type=Path)
parser.add_argument('--after', type=Path, default=Path(__file__).resolve().parents[1] / 'test/screenshots/goldens')
parser.add_argument('--output', type=Path, default=Path('/tmp/moneef-design-review'))
args = parser.parse_args()
(args.output / 'images').mkdir(parents=True, exist_ok=True)
labels = {
    'home': 'Home', 'transactions': 'Activity', 'insights_overview': 'Insights · overview',
    'insights_analysis': 'Insights · analysis', 'insights_patterns': 'Insights · patterns',
    'add_transaction': 'Add transaction', 'transaction_detail': 'Transaction details',
    'profile': 'Profile', 'categories': 'Categories', 'recurrences': 'Recurring payments',
}
items = []
for name, label in labels.items():
    for theme in ('light', 'dark'):
        filename = f'{name}_{theme}.png'
        old, new = args.before / filename, args.after / filename
        if not old.is_file() or not new.is_file():
            raise SystemExit(f'Missing screenshot pair: {filename}')
        for source, suffix in ((old, 'before'), (new, 'after')):
            shutil.copy2(source, args.output / 'images' / f'{name}_{theme}_{suffix}.png')
        items.append({'id': f'{name}_{theme}', 'label': f'{label} · {theme}'})
options = ''.join(f'<option value="{i["id"]}">{html.escape(i["label"])}</option>' for i in items)
page = '''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Moneef · design review</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#f4f4f8;color:#252336;font:15px system-ui,sans-serif}
header{padding:28px max(24px,calc((100vw - 1120px)/2));background:#fff;border-bottom:1px solid #e4e4ec}
h1{font-size:24px;letter-spacing:-.5px;margin:0 0 8px}p{color:#60616f;line-height:1.6;margin:0;max-width:72ch}
nav{display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin-top:20px}
select,button{font:inherit;border:1px solid #d8d7e4;border-radius:8px;padding:12px;background:white;color:inherit;min-height:44px}
button{cursor:pointer}button[aria-pressed="true"]{background:#6250d5;color:white;border-color:#6250d5}
main{max-width:1040px;margin:24px auto;display:grid;grid-template-columns:1fr 1fr;gap:32px;padding:0 24px}
figure{margin:0;min-width:0}figcaption{display:flex;justify-content:space-between;margin-bottom:12px;font-weight:600}
figcaption span{color:#6b687b;font-size:13px;font-weight:400}img{display:block;width:100%;height:auto;border-radius:12px}
a:focus-visible,select:focus-visible,button:focus-visible{outline:3px solid #6250d5;outline-offset:4px}
body.after-only main{grid-template-columns:minmax(0,460px);justify-content:center}body.after-only #before{display:none}
footer{max-width:1040px;margin:32px auto;padding:0 24px 32px;color:#60616f;font-size:13px;line-height:1.6}
@media(max-width:650px){main{gap:12px;padding:0 12px}header{padding:22px}figcaption{display:block}figcaption span{display:block;margin-top:3px}h1{font-size:22px}}
</style>
<header><h1>Moneef, refined</h1><p>Actual Flutter screens. Compare the original layout with the new typography, cash-flow view, category breakdowns, transaction rows, forms, and navigation.</p>
<nav><label for="screen">Screen</label><select id="screen">OPTIONS</select><button id="compare" aria-pressed="true">Before &amp; after</button><button id="new" aria-pressed="false">New design only</button></nav></header>
<main><figure id="before"><figcaption>Before<span>Provided screenshots · round 8</span></figcaption><a id="before-link" target="_blank" rel="noopener"><img id="before-img" alt="Original Moneef screen"></a></figure>
<figure><figcaption>After<span>Rendered from the updated Flutter client</span></figcaption><a id="after-link" target="_blank" rel="noopener"><img id="after-img" alt="Redesigned Moneef screen"></a></figure></main>
<footer>These renders use fixture data through the native API mock. The screens, widgets, fonts, themes, and routes are the real application. Click a screenshot to inspect its full resolution.</footer>
<script>
const screens = ITEMS;
const select = document.querySelector('#screen');
function render(){for(const side of ['before','after']){const src=`images/${select.value}_${side}.png`;document.querySelector(`#${side}-img`).src=src;document.querySelector(`#${side}-link`).href=src;document.querySelector(`#${side}-img`).alt=`${screens.find(x=>x.id===select.value).label}, ${side}`;}}
select.addEventListener('change',render);
for(const id of ['compare','new'])document.querySelector(`#${id}`).addEventListener('click',()=>{document.body.classList.toggle('after-only',id==='new');for(const b of ['compare','new'])document.querySelector(`#${b}`).setAttribute('aria-pressed',b===id?'true':'false');});
render();
</script></html>'''.replace('OPTIONS', options).replace('ITEMS', json.dumps(items))
(args.output / 'index.html').write_text(page)
print(f'{len(items)} comparisons: {args.output / "index.html"}')
