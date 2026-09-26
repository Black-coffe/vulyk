"""item0_check.py - what does a workflow agent's `tokens` (and the run's totalTokens) measure?
Compares it with the agent's last-request context, last context+output, and cumulative sums."""
import json, pandas as pd
c = pd.read_csv('calls_agent.csv')
c['ctx'] = c['in'] + c.cw5 + c.cw1h + c.cr
last = c.sort_values(['agent_id', 'i']).groupby('agent_id').tail(1).set_index('agent_id')
cum = c.groupby('agent_id').agg(cum_ctx=('ctx', 'sum'), cum_out=('out', 'sum'), cum_in=('in', 'sum'), cw=('cw5', 'sum'), cw1=('cw1h', 'sum'))
out = []
for l in open('workflows.jsonl', encoding='utf-8'):
    w = json.loads(l)
    for x in w['agents']:
        a = x['agentId']
        if a in last.index and x['tokens']:
            L = last.loc[a]; C = cum.loc[a]
            out.append(dict(tok=x['tokens'], last_ctx=L.ctx, last_ctx_out=L.ctx + L.out, cum_in_cw_out=C.cum_in + C.cw + C.cw1 + C.cum_out, cum_all=C.cum_ctx + C.cum_out))
d = pd.DataFrame(out)
print('agents compared', len(d))
for col in ['last_ctx', 'last_ctx_out', 'cum_in_cw_out', 'cum_all']:
    r = d[col] / d.tok
    print(f'{col:14s} median ratio {r.median():.4f}  within 2%: {((r - 1).abs() < 0.02).mean():.3f}')
w = pd.read_csv('workflow_table.csv')
v = w[(w.name == 'vulyk-cycle') & (w.totalTokens > 0)]
print('vulyk-cycle runs', len(v), 'totalTokens median', v.totalTokens.median(), 'p75', v.totalTokens.quantile(.75), 'max', v.totalTokens.max())
print('run-level raw/totalTokens median', (v.my_raw / v.totalTokens).median(), 'weighted/totalTokens', (v.my_w / v.totalTokens).median())
