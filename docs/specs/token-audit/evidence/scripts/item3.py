"""item3.py - fixed overhead per dispatch (first API request of each subagent) for recent VULYK sessions,
its share of total spend, and the cycle-clerk economics (verbs, durations, cost)."""
import pandas as pd, json, re, collections
st = pd.read_csv('session_table.csv')
vk = set(zip(st[(st.vulyk == 1) & (st.recent == 1)].project, st[(st.vulyk == 1) & (st.recent == 1)].session))
ag = pd.read_csv('agent_table.csv', keep_default_na=False)
a = ag[[(p, s) in vk for p, s in zip(ag.project, ag.session)]].copy()
a = a[a.fc_ctx != '']
for c in ('fc_ctx', 'fc_cw', 'fc_cr', 'n_calls', 'raw', 'weighted', 'instr_chars', 'prompt_chars'):
    a[c] = pd.to_numeric(a[c], errors='coerce').fillna(0)
a['fc_hit'] = a.fc_cr / a.fc_ctx.clip(lower=1)
# fixed prefix carried through every turn: first ctx re-read on each later call
a['fixed_raw'] = a.fc_ctx * a.n_calls
a['fixed_w'] = a.fc_cw * 1.25 + a.fc_cr * 0.1 + a.fc_ctx * 0.1 * (a.n_calls - 1)
a['first_w'] = a.fc_cw * 1.25 + a.fc_cr * 0.1
g = a.groupby('agent_type').agg(n=('fc_ctx', 'size'), fc_med=('fc_ctx', 'median'), fc_p90=('fc_ctx', lambda x: x.quantile(.9)),
                                fc_cw_med=('fc_cw', 'median'), hit_med=('fc_hit', 'median'), instr_med=('instr_chars', 'median'), prompt_med=('prompt_chars', 'median'),
                                first_w=('first_w', 'sum'), fixed_raw=('fixed_raw', 'sum'), fixed_w=('fixed_w', 'sum'), raw=('raw', 'sum'), w=('weighted', 'sum'))
g = g[g.n >= 10].sort_values('n', ascending=False)
TOT_W = st[(st.vulyk == 1) & (st.recent == 1)].weighted.sum()
TOT_R = st[(st.vulyk == 1) & (st.recent == 1)].raw.sum()
out = g.copy()
out['first_w_share_of_type%'] = (g.first_w / g.w * 100).round(1)
out['fixed_w_share_of_type%'] = (g.fixed_w / g.w * 100).round(1)
for c in ('fc_med', 'fc_p90', 'fc_cw_med'):
    out[c] = (out[c] / 1000).round(1)
out['hit_med'] = out.hit_med.round(2)
print(out[['n', 'fc_med', 'fc_p90', 'fc_cw_med', 'hit_med', 'instr_med', 'prompt_med', 'first_w_share_of_type%', 'fixed_w_share_of_type%']].to_markdown())
print('ALL agents: first-request weighted', round(a.first_w.sum() / 1e6, 1), 'M =', round(a.first_w.sum() / TOT_W * 100, 1), '% of all recent VULYK weighted;',
      'fixed prefix carried weighted', round(a.fixed_w.sum() / 1e6, 1), 'M =', round(a.fixed_w.sum() / TOT_W * 100, 1), '%; raw', round(a.fixed_raw.sum() / TOT_R * 100, 1), '%')
print('TOTAL recent VULYK sessions weighted M', round(TOT_W / 1e6), 'raw M', round(TOT_R / 1e6), 'agents', len(a))
out.to_csv('item3_first_request.csv')
# ---- clerk economics
cl = a[a.agent_type == 'cycle-clerk']
verbs = collections.Counter(); vdur = collections.defaultdict(list); vw = collections.defaultdict(float); vdurA = collections.defaultdict(list)
recs = {}
for l in open('agents.jsonl', encoding='utf-8'):
    d = json.loads(l)
    if d['agent_type'] == 'cycle-clerk' and (d['project'], d['session']) in vk:
        recs[d['agent_id']] = d
for r in cl.itertuples():
    d = recs.get(r.agent_id)
    if not d: continue
    cmd = d['bash'][0]['cmd'] if d['bash'] else ''
    m = re.search(r'(cycle|journal)\.sh\s+([a-z-]+)', cmd)
    v = (m.group(1) + ' ' + m.group(2)) if m else ('(no bash)' if not cmd else 'other')
    verbs[v] += 1
    bd = sum((b['dur'] or 0) for b in d['bash'])
    vdur[v].append(bd)
    vdurA[v].append((d['end'] or 0) - (d['start'] or 0))
    vw[v] += r.weighted
rows = []
for v, n in verbs.most_common():
    s = pd.Series(vdur[v]); sa = pd.Series(vdurA[v])
    rows.append({'verb': v, 'n': n, 'bash_med_s': round(s.median(), 1), 'bash_p90_s': round(s.quantile(.9), 1), 'bash_max_s': round(s.max(), 1), 'bash_total_min': round(s.sum() / 60, 1), 'agent_total_min': round(sa.sum() / 60, 1), 'weighted_M': round(vw[v] / 1e6, 2)})
cv = pd.DataFrame(rows)
print(cv.to_markdown(index=False))
cv.to_csv('item3_clerk_verbs.csv', index=False)
print('clerks', len(cl), 'raw M', round(cl.raw.sum() / 1e6, 1), 'weighted M', round(cl.weighted.sum() / 1e6, 1), 'share of recent VULYK weighted %', round(cl.weighted.sum() / TOT_W * 100, 2),
      'first-call cw median', cl.fc_cw.median(), 'first-call cache hit share (cr>0)', round((cl.fc_cr > 0).mean(), 3), 'out tokens median per clerk', )
co = pd.read_csv('calls_agent.csv'); co = co[co.agent_type == 'cycle-clerk']
print('clerk output tokens total', co.out.sum(), 'clerk cache write total', co.cw5.sum() + co.cw1h.sum(), 'cache read total', co.cr.sum())
print('clerk models', co.model.value_counts().to_dict())
