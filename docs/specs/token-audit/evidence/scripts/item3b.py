"""item3b.py - what is inside a subagent's first request: CLAUDE.md bundle per project (files, chars),
and a regression of clerk first-request tokens on instruction chars (tokens per char)."""
import json, glob, os, pandas as pd, numpy as np
ag = pd.read_csv('agent_table.csv', keep_default_na=False)
cl = ag[(ag.agent_type == 'cycle-clerk') & (ag.recent == 1) & (ag.fc_ctx != '')].copy()
cl['fc_ctx'] = cl.fc_ctx.astype(float); cl['instr_chars'] = pd.to_numeric(cl.instr_chars, errors='coerce')
cl = cl.dropna(subset=['instr_chars'])
g = cl.groupby('project').agg(n=('fc_ctx', 'size'), fc=('fc_ctx', 'median'), instr=('instr_chars', 'median'))
print(g.to_string())
x = g.instr.values; y = g.fc.values
b, a0 = np.polyfit(x, y, 1)
print('clerk first-request tokens ~= %.0f + %.3f * instr_chars (per-project medians, n=%d)' % (a0, b, len(g)))
# instruction files of one recent clerk per project
ROOT = os.path.expanduser(r'C:\Users\Andrei\.claude\projects')
seen = set()
for r in cl.sort_values('start', ascending=False).itertuples():
    if r.project in seen: continue
    seen.add(r.project)
    fs = glob.glob(os.path.join(ROOT, r.project, r.session, 'subagents', '**', 'agent-' + r.agent_id + '.jsonl'), recursive=True)
    if not fs: continue
    for l in open(fs[0], encoding='utf-8'):
        d = json.loads(l)
        if d.get('type') == 'attachment' and d['attachment'].get('type') == 'instructions':
            print(r.project, [(os.path.basename(f['path']), len(f['content'])) for f in d['attachment']['files']])
            break
        if d.get('type') == 'attachment' and d['attachment'].get('type') == 'prompt_snapshot' and 'tools' in d['attachment']:
            pass
