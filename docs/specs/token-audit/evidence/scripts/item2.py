"""item2.py - where tokens go inside recent cycle tasks: Queen vs each agent type.
Also the same breakdown over ALL recent VULYK sessions (session_table vulyk=1, recent=1)."""
import pandas as pd, json
tasks = pd.read_csv('item1_recent_tasks.csv', keep_default_na=False)
keys = set(zip(tasks.project, tasks.slug))
ty = pd.read_csv('task_agent_types.csv', keep_default_na=False)
ty = ty[[(p, s) in keys for p, s in zip(ty.project, ty.slug)]]
g = ty.groupby('agent_type').agg(n=('n', 'sum'), raw=('raw', 'sum'), w=('w', 'sum'), calls=('calls', 'sum'), tasks=('slug', 'size'))
q = pd.DataFrame([{'agent_type': 'QUEEN (main session)', 'n': tasks.n_sessions.sum(), 'raw': tasks.queen_raw.sum(), 'w': tasks.queen_w.sum(), 'calls': tasks.queen_calls.sum(), 'tasks': len(tasks)}]).set_index('agent_type')
g = pd.concat([q, g])
T = g.raw.sum(); TW = g.w.sum()
g['turns/disp'] = (g.calls / g.n).round(1)
g['avg_raw_M'] = (g.raw / g.n / 1e6).round(2)
g['avg_w_M'] = (g.w / g.n / 1e6).round(2)
g['total_raw_M'] = (g.raw / 1e6).round(1)
g['total_w_M'] = (g.w / 1e6).round(1)
g['share_raw%'] = (g.raw / T * 100).round(1)
g['share_w%'] = (g.w / TW * 100).round(1)
g['disp/task'] = (g.n / len(tasks)).round(1)
g = g.sort_values('w', ascending=False)
print('tasks', len(tasks), 'total raw', T / 1e6, 'total w', TW / 1e6)
print(g[['n', 'disp/task', 'turns/disp', 'avg_raw_M', 'avg_w_M', 'total_raw_M', 'total_w_M', 'share_raw%', 'share_w%']].to_markdown())
g.to_csv('item2_types_cycle_tasks.csv')
# per-type medians from agent_table for recent vulyk sessions
ag = pd.read_csv('agent_table.csv', keep_default_na=False)
st = pd.read_csv('session_table.csv')
vk = set(zip(st[(st.vulyk == 1) & (st.recent == 1)].project, st[(st.vulyk == 1) & (st.recent == 1)].session))
a = ag[[(p, s) in vk for p, s in zip(ag.project, ag.session)]].copy()
a['dur_min'] = pd.to_numeric(a.dur_s, errors='coerce') / 60
m = a.groupby('agent_type').agg(n=('raw', 'size'), med_calls=('n_calls', 'median'), p90_calls=('n_calls', lambda x: x.quantile(.9)), med_raw=('raw', 'median'), med_w=('weighted', 'median'), med_dur_min=('dur_min', 'median'), p90_dur_min=('dur_min', lambda x: x.quantile(.9)), max_ctx_med=('max_ctx', 'median'))
m = m[m.n >= 5].sort_values('n', ascending=False)
for c in ('med_raw', 'med_w', 'max_ctx_med'):
    m[c] = (m[c] / 1000).round(0)
m['med_dur_min'] = m.med_dur_min.round(1); m['p90_dur_min'] = m.p90_dur_min.round(1)
print(m.to_markdown())
m.to_csv('item2_type_medians_recent_sessions.csv')
