"""item1.py - distribution of per-task cost for recent VULYK cycle tasks (task_table.csv)."""
import pandas as pd, json, collections
t = pd.read_csv('task_table.csv', keep_default_na=False)
t = t[t.slug != '-']
t['cycle'] = (t.wf_runs > 0) | (t.seats > 0) | (t.ledger_rounds > 0)
r = t[(t.recent == 1) & t.cycle].copy()
o = t[(t.recent == 0) & t.cycle].copy()
def q(s):
    return {'median': s.median(), 'p75': s.quantile(.75), 'max': s.max(), 'mean': s.mean()}
out = {}
for name, df in (('recent', r), ('older', o)):
    out[name] = {'n': int(len(df))}
    for c in ('raw', 'weighted', 'wf_totalTokens', 'queen_raw', 'agents_raw', 'cr', 'cw5', 'cw1h', 'out', 'in', 'active_min', 'elapsed_h', 'dispatches', 'clerks', 'workers', 'seats', 'lead_review', 'wf_runs', 'ledger_rounds', 'n_sessions'):
        out[name][c] = {k: round(float(v), 1) for k, v in q(df[c]).items()}
    out[name]['share_cr_of_raw'] = round(float(df.cr.sum() / df.raw.sum()), 3)
    out[name]['share_queen_raw'] = round(float(df.queen_raw.sum() / df.raw.sum()), 3)
    out[name]['share_queen_w'] = round(float(df.queen_w.sum() / df.weighted.sum()), 3)
json.dump(out, open('item1_stats.json', 'w'), indent=1)
for k in ('raw', 'weighted', 'wf_totalTokens', 'active_min', 'dispatches', 'clerks', 'workers', 'seats', 'wf_runs', 'ledger_rounds', 'n_sessions', 'queen_raw', 'agents_raw'):
    print(k, out['recent'][k], '| older', out['older'][k]['median'])
print('recent n', out['recent']['n'], 'older n', out['older']['n'], 'cr share', out['recent']['share_cr_of_raw'], 'queen share raw', out['recent']['share_queen_raw'], 'queen share w', out['recent']['share_queen_w'])
print('ratio raw/wf_totalTokens (tasks with wf):', ((r[r.wf_totalTokens > 0].raw) / r[r.wf_totalTokens > 0].wf_totalTokens).median())
r.sort_values('raw', ascending=False).to_csv('item1_recent_tasks.csv', index=False)
# model split for recent cycle tasks: need per-agent models -> use calls
