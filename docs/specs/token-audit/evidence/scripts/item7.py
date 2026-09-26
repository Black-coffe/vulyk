"""item7.py - timeline of one task: Queen segments, direct dispatches, and workflow runs folded into phase blocks.
usage: python item7.py <project> <session> [<session> ...]"""
import sys, json, re, collections, datetime, pandas as pd
proj, sess = sys.argv[1], sys.argv[2:]
def hm(t): return datetime.datetime.fromtimestamp(t).strftime('%m-%d %H:%M') if t else ''
def W(d): return d['in'] + 1.25 * d['cw5'] + 2 * d['cw1h'] + 0.1 * d['cr'] + d['out']
def R(d): return d['in'] + d['cw5'] + d['cw1h'] + d['cr'] + d['out']
cm = pd.read_csv('calls_main.csv', keep_default_na=False); cm = cm[(cm.project == proj) & cm.session.isin(sess)].copy(); cm['ts'] = cm.ts.astype(float)
ca = pd.read_csv('calls_agent.csv', keep_default_na=False); ca = ca[(ca.project == proj) & ca.session.isin(sess)]
AG = {}
for l in open('agents.jsonl', encoding='utf-8'):
    d = json.loads(l)
    if d['project'] == proj and d['session'] in sess: AG[d['agent_id']] = d
models = ca.groupby('agent_id').model.agg(lambda x: '/'.join(sorted(set(m.replace('claude-', '') for m in x))))
tok = ca.groupby('agent_id')[['in', 'cw5', 'cw1h', 'cr', 'out']].sum()
WF = [json.loads(l) for l in open('workflows.jsonl', encoding='utf-8')]
WF = [w for w in WF if w['project'] == proj and w['session'] in sess]
events = []  # (start, end, kind, label, model, raw, w, note)
for a in AG.values():
    if a['wf']: continue
    t = tok.loc[a['agent_id']] if a['agent_id'] in tok.index else None
    if t is None: continue
    events.append((a['start'], a['end'], 'dispatch', a['agent_type'], models.get(a['agent_id'], ''), R(t), W(t), (a['description'] or '')[:60]))
for w in WF:
    ags = [AG[x['agentId']] for x in w['agents'] if x['agentId'] in AG]
    ags.sort(key=lambda a: a['start'] or 0)
    blocks = []
    for a in ags:
        ph = a['workflowPhase'] or 'Build'
        if not blocks or blocks[-1]['ph'] != ph:
            blocks.append({'ph': ph, 'a': []})
        blocks[-1]['a'].append(a)
    for b in blocks:
        c = collections.Counter(a['agent_type'] for a in b['a'])
        r = sum(R(tok.loc[a['agent_id']]) for a in b['a'] if a['agent_id'] in tok.index)
        ww = sum(W(tok.loc[a['agent_id']]) for a in b['a'] if a['agent_id'] in tok.index)
        ms = '/'.join(sorted(set(m for a in b['a'] for m in models.get(a['agent_id'], '').split('/') if m)))
        clerk_wait = sum(sum((x['dur'] or 0) for x in a['bash']) for a in b['a'] if a['agent_type'] == 'cycle-clerk')
        events.append((min(a['start'] for a in b['a']), max(a['end'] for a in b['a']), 'wf ' + w['runId'][-9:], b['ph'] + ': ' + ', '.join(f'{k} x{v}' for k, v in c.most_common()), ms, r, ww, f'clerk bash {clerk_wait/60:.1f} min'))
    events.append((w['startTime'] / 1000, w['startTime'] / 1000 + (w['durationMs'] or 0) / 1000, 'WF RUN', f"{w['runId']} end stage {w['result_stage']}", '', 0, 0, f"printed totalTokens {w['totalTokens']/1e6:.2f}M, {len(w['agents'])} agents"))
events.sort(key=lambda e: e[0] or 0)
# Queen segments between event starts
rows = []
bounds = [e[0] for e in events if e[2] != 'WF RUN'] + [cm.ts.max() + 1]
prev = cm.ts.min() - 1
qsum = lambda df: (R(df[['in', 'cw5', 'cw1h', 'cr', 'out']].sum()), W(df[['in', 'cw5', 'cw1h', 'cr', 'out']].sum()), len(df), df.model.iloc[-1].replace('claude-', '') if len(df) else '', (df['in'] + df.cw5 + df.cw1h + df.cr).max() if len(df) else 0)
i = 0
for e in events:
    if e[2] != 'WF RUN':
        q = cm[(cm.ts > prev) & (cm.ts <= e[0])]
        if len(q):
            r, ww, n, m, mx = qsum(q)
            rows.append((hm(q.ts.min()), round((q.ts.max() - q.ts.min()) / 60), 'QUEEN', f'{n} calls, peak ctx {mx/1000:.0f}k', m, r, ww, ''))
        prev = e[0]
    rows.append((hm(e[0]), round(((e[1] or e[0]) - e[0]) / 60), e[2], e[3], e[4], e[5], e[6], e[7]))
q = cm[cm.ts > prev]
if len(q):
    r, ww, n, m, mx = qsum(q); rows.append((hm(q.ts.min()), round((q.ts.max() - q.ts.min()) / 60), 'QUEEN', f'{n} calls, peak ctx {mx/1000:.0f}k', m, r, ww, ''))
df = pd.DataFrame(rows, columns=['start', 'min', 'who', 'what', 'model', 'raw', 'w', 'note'])
df['raw_M'] = (df.raw / 1e6).round(1); df['w_M'] = (df.w / 1e6).round(2)
print(df[['start', 'min', 'who', 'what', 'model', 'raw_M', 'w_M', 'note']].to_markdown(index=False))
print('TOTAL raw M', round(df.raw.sum() / 1e6, 1), 'w M', round(df.w.sum() / 1e6, 1), '| Queen raw M', round(df[df.who == 'QUEEN'].raw.sum() / 1e6, 1))
df.to_csv(f'item7_timeline_{proj}_{sess[0][:8]}.csv', index=False)
