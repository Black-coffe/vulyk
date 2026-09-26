"""validate.py - compare parsed usage (main+subagents) against the harness cost-state modelUsage per session"""
import json, collections
S = {}
for l in open('sessions.jsonl', encoding='utf-8'):
    d = json.loads(l); S[(d['project'], d['session'])] = d
A = collections.defaultdict(lambda: collections.defaultdict(collections.Counter))
for l in open('agents.jsonl', encoding='utf-8'):
    d = json.loads(l)
    for m, t in d['totals'].items():
        A[(d['project'], d['session'])][m].update(t)
rows = []
for k, d in S.items():
    cs = d.get('cost_state')
    if not cs or not cs.get('modelUsage'):
        continue
    mine = collections.defaultdict(collections.Counter)
    for m, t in d['main_totals'].items(): mine[m].update(t)
    for m, t in A[k].items(): mine[m].update(t)
    for m, u in cs['modelUsage'].items():
        mm = mine.get(m, {})
        rows.append((k[0][:22], k[1][:8], m[:18], u.get('cacheReadInputTokens'), mm.get('cr', 0), u.get('cacheCreationInputTokens'), mm.get('cw', 0), u.get('outputTokens'), mm.get('out', 0), u.get('inputTokens'), mm.get('in', 0)))
import statistics
rat = [r[4] / r[3] for r in rows if r[3] and r[3] > 1e6]
print('n sessions w/ cost_state rows', len(rows), 'cache-read ratio mine/harness median', statistics.median(rat), 'min', min(rat), 'max', max(rat))
rat2 = [r[8] / r[7] for r in rows if r[7] and r[7] > 1e5]
print('output ratio median', statistics.median(rat2), min(rat2), max(rat2))
for r in sorted(rows, key=lambda r: -(r[3] or 0))[:12]:
    print(r)
