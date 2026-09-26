"""item7c.py - how vulyk-cycle runs end: final stage and the recorded `stop` reason, all runs in workflows.jsonl."""
import json, collections
c = collections.Counter(); stops = collections.Counter(); n = 0
for l in open('workflows.jsonl', encoding='utf-8'):
    w = json.loads(l)
    if w['workflowName'] != 'vulyk-cycle': continue
    n += 1
    try: r = json.loads(w['result']) if w['result'] else {}
    except Exception: r = {}
    r = r if isinstance(r, dict) else {}
    c[r.get('stage')] += 1
    s = r.get('stop')
    if s: stops[(s.get('verb'), str(s.get('exit')), (s.get('error') or s.get('reason') or '')[:70])] += 1
print('runs', n, c.most_common())
for k, v in stops.most_common(20): print(v, k)
