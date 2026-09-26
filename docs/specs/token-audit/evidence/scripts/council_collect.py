"""council_collect.py - merge memory/stats/council.jsonl from every VULYK project into council_all.jsonl"""
import json, glob, os
roots = glob.glob('E:/Projects/*') + ['C:/laragon/www/mmorpg', 'D:/YouTube_AI'] + glob.glob('C:/Projects/*')
out = open('council_all.jsonl', 'w', encoding='utf-8')
seen = set()
for r in roots:
    f = os.path.join(r, 'memory', 'stats', 'council.jsonl')
    if not os.path.exists(f):
        continue
    ver = None
    for vf in ('.claude/vulyk-version',):
        p = os.path.join(r, vf)
        if os.path.exists(p):
            ver = open(p, encoding='utf-8').read().strip()
    n = 0
    for l in open(f, encoding='utf-8'):
        l = l.strip()
        if not l:
            continue
        try:
            d = json.loads(l)
        except Exception:
            continue
        d['_project'] = os.path.basename(r.rstrip('/'))
        d['_version'] = ver
        k = (d['_project'], d.get('spec'), d.get('round'), d.get('ts'))
        if k in seen:
            continue
        seen.add(k)
        out.write(json.dumps(d, ensure_ascii=False) + '\n'); n += 1
    print(r, ver, n)
