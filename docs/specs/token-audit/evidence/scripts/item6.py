"""item6.py - VULYK vs non-VULYK work of similar size.
Unit A: recent VULYK cycle task (sum over its sessions; code files = files edited by its subagents + Queen edits in its sessions' slug).
Unit B: recent VULYK session (Queen + all subagents) that dispatched >= 1 worker.
Unit C: recent non-VULYK work session (no VULYK marker, no VULYK constitution loaded, >= 3 edits).
Unit D: recent session in a VULYK-installed project (constitution loaded) that used none of the machinery, >= 3 edits.
Size proxy: distinct CODE files edited (excludes docs/specs, memory/, .claude/, .vulyk/, docs/adr, *.md)."""
import json, re, collections, pandas as pd, numpy as np
PAPER = re.compile(r'(docs/specs/|/memory/|/\.claude/|/\.vulyk/|docs/adr/|docs/wiki/|\.md$|/tmp/|appdata/local/temp)')
def code(files): return {f for f in files if not PAPER.search(f)}
st = pd.read_csv('session_table.csv')
S = {}
for l in open('sessions.jsonl', encoding='utf-8'):
    d = json.loads(l); S[(d['project'], d['session'])] = d
AG = collections.defaultdict(list)
for l in open('agents.jsonl', encoding='utf-8'):
    d = json.loads(l); AG[(d['project'], d['session'])].append(d)
def sess_row(k):
    d = S[k]; files = set(d['main_edit_files']); la, lr = d['main_lines_add'], d['main_lines_rem']; ne = d['main_edits']
    for a in AG.get(k, []):
        files |= set(a['edit_files']); la += a['lines_add']; lr += a['lines_rem']; ne += a['n_edits']
    return dict(code_files=len(code(files)), all_files=len(files), lines=la + lr, edits=ne)
r = st[st.recent == 1].copy()
extra = [sess_row((p, s)) for p, s in zip(r.project, r.session)]
for k in ('code_files', 'all_files', 'lines', 'edits'): r[k] = [e[k] for e in extra]
r['workers'] = r.per_type.apply(lambda s: sum(v['n'] for t, v in json.loads(s).items() if t.startswith('worker')))
B = r[(r.vulyk == 1) & (r.workers >= 1)].assign(group='B VULYK session w/ build')
C = r[(r.vulyk == 0) & (r.instr_vulyk != 1) & (r.edits >= 3)].assign(group='C non-VULYK work session')
D = r[(r.vulyk == 0) & (r.instr_vulyk == 1) & (r.edits >= 3)].assign(group='D VULYK project, no machinery')
# task level (A)
tasks = pd.read_csv('item1_recent_tasks.csv', keep_default_na=False)
wfspec = {}
for l in open('workflows.jsonl', encoding='utf-8'):
    w = json.loads(l); a = w['args'] if isinstance(w['args'], dict) else {}
    wfspec[(w['session'], w['runId'])] = (a.get('spec') or '').rstrip('/').split('/')[-1]
tf = collections.defaultdict(set); tl = collections.Counter()
for k, lst in AG.items():
    for a in lst:
        sl = (wfspec.get((a['session'], a['wf'])) if a['wf'] else None) or a['slug'] or '-'
        tf[(a['project'], sl)] |= set(a['edit_files']); tl[(a['project'], sl)] += a['lines_add'] + a['lines_rem']
A = tasks.copy()
A['code_files'] = [len(code(tf[(p, s)])) for p, s in zip(A.project, A.slug)]
A['lines'] = [tl[(p, s)] for p, s in zip(A.project, A.slug)]
A['subagents'] = A.dispatches; A['group'] = 'A VULYK cycle task'
A['active_min'] = A.active_min
def summ(df, unit):
    return dict(unit=unit, n=len(df), med_code_files=df.code_files.median(), med_lines=df.lines.median(),
                med_raw_M=round(df.raw.median() / 1e6, 1), med_w_M=round(df.weighted.median() / 1e6, 2),
                w_per_code_file_M=round((df.weighted / df.code_files.clip(lower=1)).median() / 1e6, 2),
                w_per_100_lines_M=round((df.weighted / (df.lines.clip(lower=1) / 100)).median() / 1e6, 2),
                med_active_min=round(df.active_min.median()), active_min_per_code_file=round((df.active_min / df.code_files.clip(lower=1)).median(), 1),
                med_subagents=(df.subagents.median() if 'subagents' in df else df.n_sub.median()))
rows = [summ(A, 'A VULYK cycle task (44)'), summ(B, 'B VULYK session with >=1 worker'), summ(C, 'C non-VULYK work session'), summ(D, 'D VULYK project, no machinery')]
print(pd.DataFrame(rows).to_markdown(index=False))
# size-matched buckets
bins = [0, 3, 10, 25, 1000]; lab = ['1-3', '4-10', '11-25', '26+']
out = []
for name, df in (('A task', A), ('C non-VULYK', C), ('D VULYK proj no machinery', D)):
    df = df[df.code_files >= 1].copy(); df['bucket'] = pd.cut(df.code_files, bins, labels=lab)
    g = df.groupby('bucket', observed=True).agg(n=('raw', 'size'), med_w_M=('weighted', lambda x: round(x.median() / 1e6, 2)), med_raw_M=('raw', lambda x: round(x.median() / 1e6, 1)), med_active_min=('active_min', 'median'), med_lines=('lines', 'median'))
    g['group'] = name; out.append(g.reset_index())
Bk = pd.concat(out)
print(Bk.pivot(index='bucket', columns='group', values=['n', 'med_w_M', 'med_active_min']).to_markdown())
print(Bk.to_markdown(index=False))
# projects in C and D
print('C projects:', C.project.value_counts().head(12).to_dict())
print('D projects:', D.project.value_counts().head(12).to_dict())
pd.concat([A.assign(unit='A'), C.assign(unit='C'), D.assign(unit='D')], ignore_index=True)[['unit', 'project', 'slug', 'session', 'raw', 'weighted', 'code_files', 'lines', 'active_min']].to_csv('item6_units.csv', index=False)
