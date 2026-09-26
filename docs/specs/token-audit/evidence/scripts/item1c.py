"""item1c.py - repair waves / judge rounds / empty-seat events per slug from workflow logs; top-10 table for recent cycle tasks"""
import pandas as pd, json, collections
ev = collections.defaultdict(collections.Counter)
for l in open('workflows.jsonl', encoding='utf-8'):
    w = json.loads(l); a = w['args'] if isinstance(w['args'], dict) else {}
    sl = (a.get('spec') or '').rstrip('/').split('/')[-1]
    k = (w['project'], sl)
    for x in w['logs']:
        if 'next: repair' in x: ev[k]['repair'] += 1
        if 'next: judge' in x: ev[k]['judge'] += 1
        if 'returned empty' in x: ev[k]['empty_seat'] += 1
        if 'next: open-round' in x: ev[k]['open_round'] += 1
    ev[k]['runs'] += 1
    ev[k]['wf_agents'] += len(w['agents'])
t = pd.read_csv('item1_recent_tasks.csv', keep_default_na=False)
t['repairs'] = [ev[(p, s)]['repair'] for p, s in zip(t.project, t.slug)]
t['judges'] = [ev[(p, s)]['judge'] for p, s in zip(t.project, t.slug)]
t['empty_seat'] = [ev[(p, s)]['empty_seat'] for p, s in zip(t.project, t.slug)]
t.to_csv('item1_recent_tasks.csv', index=False)
top = t.sort_values('raw', ascending=False).head(10).copy()
top['project'] = top.project.str.replace('E--Projects-', '').str.replace('C--laragon-www-', '').str.replace('D--', '')
for c in ('raw', 'weighted', 'wf_totalTokens', 'queen_raw'):
    top[c] = (top[c] / 1e6).round(1)
top['queen%'] = (top.queen_raw / top.raw * 100).round(0)
top['active_h'] = (top.active_min / 60).round(1)
print(top[['project', 'slug', 'first', 'raw', 'weighted', 'wf_totalTokens', 'queen%', 'dispatches', 'clerks', 'workers', 'seats', 'lead_review', 'wf_runs', 'ledger_rounds', 'ledger_final', 'repairs', 'empty_seat', 'active_h', 'n_sessions']].to_markdown(index=False))
print(t[['repairs', 'judges', 'empty_seat']].describe().round(2).to_string())
