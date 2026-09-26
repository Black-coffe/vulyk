"""item5.py - council circles: rounds per spec (ledger, deduped across worktrees/installer copies), what made a round RED,
before vs after v0.17.0 (2026-09-24), and the token cost of a round / of an extra circle from workflow agents."""
import json, collections, pandas as pd, re
rows, seen = [], {}
for l in open('council_all.jsonl', encoding='utf-8'):
    d = json.loads(l); k = (d['spec'], d['ts'], d['head'])
    if k in seen:
        seen[k]['_projects'].add(d['_project']); continue
    d['_projects'] = {d['_project']}; seen[k] = d; rows.append(d)
L = pd.DataFrame(rows)
def owner(ps):
    if 'vulyk' in ps: return 'vulyk'
    f = [p for p in ps if p.startswith('fibi')]
    if f: return 'fibi-next' if 'fibi-next' in ps else sorted(f)[0]
    return sorted(ps)[0]
L['owner'] = L._projects.apply(owner)
L['date'] = L.ts.str[:10]
L = L.sort_values('ts')
print('ledger rows (unique rounds)', len(L), 'specs', L.spec.nunique())
L['period'] = L.date.apply(lambda d: 'after 0.17.0 (>=09-24)' if d >= '2026-09-24' else ('recent 09-13..23' if d >= '2026-09-13' else 'older'))
sp = L.groupby(['owner', 'spec']).agg(first=('ts', 'first'), rounds=('round', 'size'), max_round=('round', 'max'), first_verdict=('verdict', 'first'), final=('verdict', 'last'), period=('period', 'first'))
print(sp.groupby('period').agg(specs=('rounds', 'size'), rounds_mean=('rounds', 'mean'), rounds_median=('rounds', 'median'), rounds_max=('rounds', 'max'),
                               green_first_round=('first_verdict', lambda x: (x == 'GREEN').sum()), final_green=('final', lambda x: (x == 'GREEN').sum()),
                               final_escalate=('final', lambda x: (x == 'ESCALATE').sum()), final_red=('final', lambda x: (x == 'RED').sum())).round(2).to_markdown())
print(sp.groupby('period').rounds.value_counts().unstack(fill_value=0).to_markdown())
sp.to_csv('item5_specs.csv')
# causes of non-GREEN rounds
nr = L[L.verdict != 'GREEN'].copy()
def causes(r):
    c = []
    if r['review'] == 'BLOCK': c.append('lead-review BLOCK')
    for s in ('sonnet', 'opus', 'haiku'):
        if r[s] == 'RED': c.append(f'{s} RED')
        if isinstance(r[s], str) and r[s] not in ('GREEN', 'RED', 'N/A', ''): c.append(f'{s} {r[s]}')
    if isinstance(r['escalate'], str) and r['escalate']: c.append('escalate:' + r['escalate'][:30])
    return c or ['(no seat RED, no BLOCK)']
nr['causes'] = nr.apply(causes, axis=1)
cc = collections.Counter(); only = collections.Counter()
for r in nr.itertuples():
    for c in r.causes: cc[(r.period, c)] += 1
    only[(r.period, ' + '.join(sorted(r.causes)))] += 1
print('non-GREEN rounds', len(nr), nr.period.value_counts().to_dict())
print(pd.Series(cc).unstack(0, fill_value=0).sort_values(by=list(pd.Series(cc).unstack(0).columns)[0], ascending=False).to_markdown())
print(pd.Series(only).unstack(0, fill_value=0).to_markdown())
print('red asks per non-GREEN round', nr.red.apply(len).describe().round(2).to_dict())
print('seat value distribution', {s: L[s].value_counts().to_dict() for s in ('sonnet', 'opus', 'haiku', 'review')})
nr[['owner', 'spec', 'round', 'ts', 'verdict', 'review', 'sonnet', 'opus', 'haiku', 'red', 'red_unevidenced', 'escalate', 'note']].to_csv('item5_nongreen_rounds.csv', index=False)
