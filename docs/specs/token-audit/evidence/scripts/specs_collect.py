"""specs_collect.py - inventory docs/specs/<slug>/ across VULYK projects -> specs_all.jsonl"""
import json, glob, os, re
roots = glob.glob('E:/Projects/*') + ['C:/laragon/www/mmorpg', 'D:/YouTube_AI'] + glob.glob('C:/Projects/*')
out = open('specs_all.jsonl', 'w', encoding='utf-8')
for r in roots:
    sd = os.path.join(r, 'docs', 'specs')
    if not os.path.isdir(sd) or not os.path.exists(os.path.join(r, '.claude', 'workflows', 'vulyk-cycle.js')) and 'seoparse' not in r:
        continue
    for s in sorted(os.listdir(sd)):
        p = os.path.join(sd, s)
        if not os.path.isdir(p):
            continue
        files = os.listdir(p)
        stories = [f for f in files if re.match(r'.*-\d\d.*\.md$', f) or re.match(r'^\d\d.*\.md$', f)]
        stories = [f for f in stories if f not in ('brief.md', 'plan.md', 'journal.md', 'report.md')]
        rounds = sorted(glob.glob(os.path.join(p, 'council', 'round-*')))
        plan = open(os.path.join(p, 'plan.md'), encoding='utf-8', errors='replace').read() if 'plan.md' in files else ''
        brief = open(os.path.join(p, 'brief.md'), encoding='utf-8', errors='replace').read() if 'brief.md' in files else ''
        tier = re.search(r'Tier[:\s*]*\**\s*(\d)', plan) or re.search(r'Tier[:\s*]*\**\s*(\d)', brief)
        shipped = re.search(r'\*\*Shipped:\*\*\s*([^\n]*)', plan)
        council = re.search(r'\*\*Council:\*\*\s*([^\n]*)', plan)
        asks = len(re.findall(r'^\s*\d+\.\s', brief.split('## Asks')[1].split('\n## ')[0], re.M)) if '## Asks' in brief else None
        jr = open(os.path.join(p, 'journal.md'), encoding='utf-8', errors='replace').read() if 'journal.md' in files else ''
        mt = os.path.getmtime(os.path.join(p, 'brief.md')) if 'brief.md' in files else os.path.getmtime(p)
        out.write(json.dumps({'project': os.path.basename(r.rstrip('/')), 'slug': s, 'n_stories': len(stories),
                              'n_round_dirs': len(rounds), 'tier': tier.group(1) if tier else None,
                              'shipped': shipped.group(1)[:80] if shipped else None,
                              'council': council.group(1)[:80] if council else None, 'asks': asks,
                              'brief_mtime': mt, 'journal_lines': jr.count('\n')}, ensure_ascii=False) + '\n')
