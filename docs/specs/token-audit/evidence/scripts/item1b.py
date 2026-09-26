"""item1b.py - model split per recent cycle task (Queen calls + agent calls), using the same slug allocation as task_table.py"""
import pandas as pd, json, re
tasks = pd.read_csv('item1_recent_tasks.csv', keep_default_na=False)
keys = set(zip(tasks.project, tasks.slug))
st = pd.read_csv('session_table.csv'); vk = set(zip(st[st.vulyk == 1].project, st[st.vulyk == 1].session))
cm = pd.read_csv('calls_main.csv', keep_default_na=False)
cm = cm[[(p, s) in vk for p, s in zip(cm.project, cm.session)]]
cm['who'] = 'queen'
ag = pd.read_csv('agent_table.csv', keep_default_na=False)
wfspec = {}
for l in open('workflows.jsonl', encoding='utf-8'):
    w = json.loads(l); a = w['args'] if isinstance(w['args'], dict) else {}
    wfspec[(w['session'], w['runId'])] = (a.get('spec') or '').rstrip('/').split('/')[-1]
ag['tslug'] = [wfspec.get((s, w)) if w else '' for s, w in zip(ag.session, ag.wf)]
ag['tslug'] = [t or s or '-' for t, s in zip(ag.tslug, ag.slug)]
amap = dict(zip(ag.agent_id, zip(ag.tslug, ag.agent_type)))
ca = pd.read_csv('calls_agent.csv', keep_default_na=False)
ca = ca[[(p, s) in vk for p, s in zip(ca.project, ca.session)]]
ca['slug'] = [amap.get(a, ('-', ''))[0] for a in ca.agent_id]
ca['who'] = 'agent'
c = pd.concat([cm[['project', 'slug', 'model', 'in', 'cw5', 'cw1h', 'cr', 'out', 'who']], ca[['project', 'slug', 'model', 'in', 'cw5', 'cw1h', 'cr', 'out', 'who']]])
c = c[[(p, s) in keys for p, s in zip(c.project, c.slug)]]
c['model'] = c.model.str.replace(r'\[.*\]$', '', regex=True)
c['raw'] = c['in'] + c.cw5 + c.cw1h + c.cr + c.out
c['w'] = c['in'] + 1.25 * c.cw5 + 2 * c.cw1h + 0.1 * c.cr + c.out
g = c.groupby(['model']).agg(raw=('raw', 'sum'), w=('w', 'sum'), inp=('in', 'sum'), cw5=('cw5', 'sum'), cw1h=('cw1h', 'sum'), cr=('cr', 'sum'), out=('out', 'sum'), calls=('raw', 'size'))
g['raw_share'] = (g.raw / g.raw.sum()).round(3); g['w_share'] = (g.w / g.w.sum()).round(3)
print(g.sort_values('raw', ascending=False).to_string())
g.to_csv('item1_models.csv')
pm = c.groupby(['project', 'slug', 'model']).raw.sum().unstack(fill_value=0)
pm = (pm.div(pm.sum(axis=1), axis=0) * 100).round(0)
pm.to_csv('item1_task_model_share.csv')
tot = c.agg({'in': 'sum', 'cw5': 'sum', 'cw1h': 'sum', 'cr': 'sum', 'out': 'sum', 'raw': 'sum', 'w': 'sum'})
print(tot.to_dict())
