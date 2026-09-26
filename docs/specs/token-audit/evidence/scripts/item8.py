"""item8.py - robustness: (a) recent cycle tasks with the VULYK repo itself excluded; (b) VULYK sessions older vs recent (session level)."""
import pandas as pd, json
t = pd.read_csv('item1_recent_tasks.csv', keep_default_na=False)
for name, df in (('all 44', t), ('excl. E--Projects-vulyk', t[t.project != 'E--Projects-vulyk']), ('only E--Projects-vulyk', t[t.project == 'E--Projects-vulyk'])):
    print(f'{name}: n {len(df)} | raw med {df.raw.median()/1e6:.1f}M p75 {df.raw.quantile(.75)/1e6:.1f}M | w med {df.weighted.median()/1e6:.1f}M p75 {df.weighted.quantile(.75)/1e6:.1f}M | wf tT med {df.wf_totalTokens.median()/1e6:.2f}M | active med {df.active_min.median():.0f} | disp med {df.dispatches.median()} | clerks med {df.clerks.median()} | rounds med {df.ledger_rounds.median()}')
st = pd.read_csv('session_table.csv')
v = st[st.vulyk == 1].copy()
v['clerks'] = v.per_type.apply(lambda s: json.loads(s).get('cycle-clerk', {}).get('n', 0))
v['workers'] = v.per_type.apply(lambda s: sum(x['n'] for k, x in json.loads(s).items() if k.startswith('worker')))
v['period'] = v.date.apply(lambda d: '2026-09-13..26' if d >= '2026-09-13' else ('2026-08-16..09-12' if d >= '2026-08-16' else 'before 08-16'))
g = v.groupby('period').agg(sessions=('raw', 'size'), raw_med_M=('raw', lambda x: round(x.median() / 1e6, 1)), w_med_M=('weighted', lambda x: round(x.median() / 1e6, 1)),
                            w_p75_M=('weighted', lambda x: round(x.quantile(.75) / 1e6, 1)), queen_share_w=('q_weighted', 'sum'), tot_w=('weighted', 'sum'),
                            subagents_med=('n_sub', 'median'), clerks_med=('clerks', 'median'), workers_med=('workers', 'median'), active_med=('active_min', 'median'), cost_med=('cost_usd', lambda x: pd.to_numeric(x, errors='coerce').median()))
g['queen_share_w'] = (g.queen_share_w / g.tot_w).round(2); g = g.drop(columns='tot_w')
print(g.to_markdown())
print('date range of VULYK sessions', v.date.min(), v.date.max())
# harness-reported cost (cost-state.totalCostUSD) per session, recent, by class
st['cost'] = pd.to_numeric(st.cost_usd, errors='coerce')
r = st[st.recent == 1]
for name, df in (('VULYK sessions', r[r.vulyk == 1]), ('non-VULYK work sessions (>=3 edits, no constitution)', r[(r.vulyk == 0) & (r.instr_vulyk != 1) & (r.n_edits >= 3)])):
    d = df.dropna(subset=['cost'])
    print(f'{name}: with cost-state {len(d)}/{len(df)} | median ${d.cost.median():.2f} p75 ${d.cost.quantile(.75):.2f} max ${d.cost.max():.2f} | sum ${d.cost.sum():.0f}')
