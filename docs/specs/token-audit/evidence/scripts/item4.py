"""item4.py - Queen context growth in recent VULYK sessions vs recent non-VULYK work sessions:
per-call context, cache reads per turn, full cache rewrites after idle gaps (TTL expiry), compaction."""
import pandas as pd, numpy as np
st = pd.read_csv('session_table.csv')
cm = pd.read_csv('calls_main.csv', keep_default_na=False)
cm['ctx'] = cm['in'] + cm.cw5 + cm.cw1h + cm.cr
cm['cw'] = cm.cw5 + cm.cw1h
cm['w'] = cm['in'] + 1.25 * cm.cw5 + 2 * cm.cw1h + 0.1 * cm.cr + cm.out
cm['ts'] = pd.to_numeric(cm.ts, errors='coerce')
cm = cm.sort_values(['project', 'session', 'i'])
cm['gap'] = cm.groupby(['project', 'session']).ts.diff()
cm['rewrite'] = (cm.cw > 0.5 * cm.ctx) & (cm.ctx > 50000)
def sess_stats(keys, label):
    c = cm[[(p, s) in keys for p, s in zip(cm.project, cm.session)]]
    g = c.groupby(['project', 'session']).agg(n=('ctx', 'size'), ctx_first=('ctx', 'first'), ctx_med=('ctx', 'median'), ctx_max=('ctx', 'max'),
                                              cr=('cr', 'sum'), cw=('cw', 'sum'), w=('w', 'sum'), rewrites=('rewrite', 'sum'))
    rw = c[c.rewrite]
    print(f'== {label}: sessions {len(g)}, calls {len(c)}')
    print('  calls/session median', g.n.median(), 'p75', g.n.quantile(.75), 'max', g.n.max())
    print('  context per call: median', round(c.ctx.median()), 'p75', round(c.ctx.quantile(.75)), 'p90', round(c.ctx.quantile(.9)), 'max', c.ctx.max())
    print('  per-session peak context median', round(g.ctx_max.median()), 'p75', round(g.ctx_max.quantile(.75)), 'max', g.ctx_max.max())
    print('  first-call context median', round(g.ctx_first.median()))
    print('  cache read per call median', round(c.cr.median()), '; cache read share of Queen raw', round(c.cr.sum() / (c.ctx.sum() + c.out.sum()), 3))
    print('  full rewrites (cw>50% of ctx, ctx>50k):', int(g.rewrites.sum()), 'weighted cost', round((1.25 * rw.cw5 + 2 * rw.cw1h).sum() / 1e6, 1), 'M =', round((1.25 * rw.cw5 + 2 * rw.cw1h).sum() / c.w.sum() * 100, 1), '% of Queen weighted')
    print('  rewrites preceded by a gap > 5 min:', int((rw.gap > 300).sum()), 'of', len(rw), '; 1h-TTL share of Queen cache writes', round(c.cw1h.sum() / max(c.cw.sum(), 1), 3))
    print('  Queen weighted total', round(c.w.sum() / 1e6, 1), 'M; cache-write share of Queen weighted', round((1.25 * c.cw5 + 2 * c.cw1h).sum() / c.w.sum(), 3), '; cache-read share', round((0.1 * c.cr).sum() / c.w.sum(), 3))
    # growth bins by call index
    c = c.copy(); c['bin'] = pd.cut(c.i, [-1, 25, 50, 100, 200, 400, 800, 5000])
    print(c.groupby('bin', observed=True).agg(calls=('ctx', 'size'), ctx_med=('ctx', 'median'), cr_med=('cr', 'median'), cw_med=('cw', 'median')).to_string())
    return g
vk = set(zip(st[(st.vulyk == 1) & (st.recent == 1)].project, st[(st.vulyk == 1) & (st.recent == 1)].session))
gv = sess_stats(vk, 'recent VULYK sessions')
gv.to_csv('item4_queen_sessions.csv')
nv = st[(st.vulyk == 0) & (st.recent == 1) & (st.n_edits >= 3) & (st.instr_vulyk != 1)]
gn = sess_stats(set(zip(nv.project, nv.session)), 'recent non-VULYK work sessions (>=3 edits, no VULYK constitution)')
# the largest Queen sessions
top = gv.sort_values('cr', ascending=False).head(8).copy()
for c in ('cr', 'cw', 'w'): top[c] = (top[c] / 1e6).round(1)
print(top.to_string())
