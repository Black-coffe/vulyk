"""item6c.py - within-project contrast: sessions WITHOUT VULYK machinery in the projects that later/also run VULYK
(any date, >= 3 edits), size-matched by code lines against the VULYK cycle tasks (unit A of item6)."""
import os, pandas as pd, importlib.util
spec = importlib.util.spec_from_file_location('b', 'item6b.py')
src = open('item6b.py', encoding='utf-8').read().split('U = pd.read_csv')[0]
ns = {}; exec(src, ns)
ROOT = ns['ROOT']; code_lines = ns['code_lines']
st = pd.read_csv('session_table.csv')
ag = pd.read_csv('agent_table.csv', keep_default_na=False)
PROJ = ['C--laragon-www-mmorpg', 'E--Projects-fibi-next', 'E--Projects-Recall', 'D--YouTube-AI', 'E--Projects-katan', 'E--Projects-AI', 'E--Projects-our-home', 'E--Projects-litopys']
E = st[st.project.isin(PROJ) & (st.vulyk == 0) & (st.n_edits >= 3)].copy()
cl = []
for r in E.itertuples():
    tot = code_lines(os.path.join(ROOT, r.project, r.session + '.jsonl'))
    import glob
    for a in ag[(ag.project == r.project) & (ag.session == r.session) & (pd.to_numeric(ag.n_edits) > 0)].itertuples():
        fs = glob.glob(os.path.join(ROOT, a.project, a.session, 'subagents', '**', 'agent-' + a.agent_id + '.jsonl'), recursive=True)
        if fs: tot += code_lines(fs[0])
    cl.append(tot)
E['code_lines'] = cl
E = E[E.code_lines > 0]
U = pd.read_csv('item6_units.csv', keep_default_na=False); A = U[(U.unit == 'A') & (U.code_lines > 0)]
bins = [0, 100, 500, 2000, 1e9]; lab = ['1-100', '101-500', '501-2000', '2000+']
rows = []
for name, df in (('A VULYK task', A), ('E same projects, no machinery', E)):
    df = df.copy(); df['bucket'] = pd.cut(df.code_lines, bins, labels=lab)
    g = df.groupby('bucket', observed=True).agg(n=('raw', 'size'), med_code_lines=('code_lines', 'median'), med_w_M=('weighted', lambda x: round(x.median() / 1e6, 2)), med_raw_M=('raw', lambda x: round(x.median() / 1e6, 1)), med_active_min=('active_min', 'median'))
    g['group'] = name; rows.append(g.reset_index())
print(pd.concat(rows).sort_values(['bucket', 'group']).to_markdown(index=False))
print('E: n', len(E), 'by project', E.project.value_counts().to_dict(), 'dates', E.date.min(), E.date.max(), 'recent share', round(E.recent.mean(), 2))
print('E weighted per 100 code lines median M', round((E.weighted / (E.code_lines / 100)).median() / 1e6, 2), '| active min per 100', round((E.active_min / (E.code_lines / 100)).median(), 1))
E[['project', 'session', 'date', 'raw', 'weighted', 'code_lines', 'active_min', 'n_sub']].to_csv('item6_same_project_nomachinery.csv', index=False)
