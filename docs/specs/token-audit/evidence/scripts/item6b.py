"""item6b.py - code-only changed lines (Edit/MultiEdit old+new lines, Write content lines; paperwork paths excluded)
per unit of item6 (A tasks via slug of the editing agent / Queen; C and D sessions), then size-matched comparison by code lines."""
import json, os, re, glob, collections, pandas as pd
ROOT = os.path.expanduser(r'C:\Users\Andrei\.claude\projects')
PAPER = re.compile(r'(docs/specs/|/memory/|/\.claude/|/\.vulyk/|docs/adr/|docs/wiki/|\.md$|/tmp/|appdata/local/temp)')
def nl(s): return (s.count('\n') + 1) if s else 0
def code_lines(path):
    tot = 0
    with open(path, encoding='utf-8', errors='replace') as f:
        for l in f:
            if '"tool_use"' not in l: continue
            d = json.loads(l)
            if d.get('type') != 'assistant': continue
            for c in d['message'].get('content') or []:
                if not isinstance(c, dict) or c.get('type') != 'tool_use' or c.get('name') not in ('Edit', 'Write', 'MultiEdit'): continue
                i = c.get('input') or {}
                fp = (i.get('file_path') or '').replace(chr(92), '/').lower()
                if not fp or PAPER.search(fp): continue
                if c['name'] == 'Edit': tot += nl(i.get('new_string')) + nl(i.get('old_string'))
                elif c['name'] == 'Write': tot += nl(i.get('content'))
                else: tot += sum(nl(e.get('new_string')) + nl(e.get('old_string')) for e in i.get('edits') or [])
    return tot
U = pd.read_csv('item6_units.csv', keep_default_na=False)
wfspec = {}
for l in open('workflows.jsonl', encoding='utf-8'):
    w = json.loads(l); a = w['args'] if isinstance(w['args'], dict) else {}
    wfspec[(w['session'], w['runId'])] = (a.get('spec') or '').rstrip('/').split('/')[-1]
ag = pd.read_csv('agent_table.csv', keep_default_na=False)
ag['tslug'] = [(wfspec.get((s, w)) if w else '') or sl or '-' for s, w, sl in zip(ag.session, ag.wf, ag.slug)]
cl = {}
# A: sum over agents with that slug (editing agents only)
A = U[U.unit == 'A']
for r in A.itertuples():
    sub = ag[(ag.project == r.project) & (ag.tslug == r.slug) & (pd.to_numeric(ag.n_edits) > 0)]
    tot = 0
    for a in sub.itertuples():
        fs = glob.glob(os.path.join(ROOT, a.project, a.session, 'subagents', '**', 'agent-' + a.agent_id + '.jsonl'), recursive=True)
        if fs: tot += code_lines(fs[0])
    cl[('A', r.project, r.slug)] = tot
for r in U[U.unit != 'A'].itertuples():
    tot = code_lines(os.path.join(ROOT, r.project, r.session + '.jsonl'))
    for a in ag[(ag.project == r.project) & (ag.session == r.session) & (pd.to_numeric(ag.n_edits) > 0)].itertuples():
        fs = glob.glob(os.path.join(ROOT, a.project, a.session, 'subagents', '**', 'agent-' + a.agent_id + '.jsonl'), recursive=True)
        if fs: tot += code_lines(fs[0])
    cl[(r.unit, r.project, r.session)] = tot
U['code_lines'] = [cl.get((u, p, s if u == 'A' else se), 0) for u, p, s, se in zip(U.unit, U.project, U.slug, U.session)]
U.to_csv('item6_units.csv', index=False)
bins = [0, 100, 500, 2000, 1e9]; lab = ['1-100', '101-500', '501-2000', '2000+']
V = U[U.code_lines > 0].copy(); V['bucket'] = pd.cut(V.code_lines, bins, labels=lab)
g = V.groupby(['bucket', 'unit'], observed=True).agg(n=('raw', 'size'), med_code_lines=('code_lines', 'median'), med_w_M=('weighted', lambda x: round(x.median() / 1e6, 2)),
                                                    med_raw_M=('raw', lambda x: round(x.median() / 1e6, 1)), med_active_min=('active_min', 'median'))
print(g.to_markdown())
V['w_per_100'] = V.weighted / (V.code_lines / 100)
print(V.groupby('unit').agg(n=('raw', 'size'), med_code_lines=('code_lines', 'median'), w_per_100_code_lines_M=('w_per_100', lambda x: round(x.median() / 1e6, 2)),
                            min_per_100=('active_min', lambda x: None)).to_markdown())
for u in ('A', 'C', 'D'):
    s = V[V.unit == u]
    print(u, 'median weighted per 100 code lines M', round((s.weighted / (s.code_lines / 100)).median() / 1e6, 2), '| active min per 100 code lines', round((s.active_min / (s.code_lines / 100)).median(), 1), '| n', len(s), '| zero-code units', int((U[U.unit == u].code_lines == 0).sum()))
