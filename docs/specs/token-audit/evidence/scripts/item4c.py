"""item4c.py - gaps before the Queen's full cache rewrites (recent VULYK sessions), and model changes at those calls."""
import pandas as pd
st = pd.read_csv('session_table.csv')
vk = set(zip(st[(st.vulyk == 1) & (st.recent == 1)].project, st[(st.vulyk == 1) & (st.recent == 1)].session))
cm = pd.read_csv('calls_main.csv', keep_default_na=False)
cm = cm[[(p, s) in vk for p, s in zip(cm.project, cm.session)]].copy()
cm['ctx'] = cm['in'] + cm.cw5 + cm.cw1h + cm.cr; cm['cw'] = cm.cw5 + cm.cw1h
cm['ts'] = pd.to_numeric(cm.ts, errors='coerce'); cm = cm.sort_values(['project', 'session', 'i'])
cm['gap'] = cm.groupby(['project', 'session']).ts.diff()
cm['prev_model'] = cm.groupby(['project', 'session']).model.shift()
cm['prev_ctx'] = cm.groupby(['project', 'session']).ctx.shift()
rw = cm[(cm.cw > 0.5 * cm.ctx) & (cm.ctx > 50000)]
print('rewrites', len(rw))
print('gap bins (min):', pd.cut(rw.gap / 60, [0, 5, 60, 10000]).value_counts().to_dict())
print('model changed at rewrite:', int((rw.model != rw.prev_model).sum()))
print('context dropped >30% vs previous call (compaction):', int((rw.ctx < 0.7 * rw.prev_ctx).sum()))
first = rw.prev_model.isna()
print('first call of session:', int(first.sum()), '| after gap > 60 min:', int((rw.gap > 3600).sum()), '| model switch mid-session:', int(((rw.model != rw.prev_model) & ~first).sum()), '| other:', int((~first & ~(rw.gap > 3600) & (rw.model == rw.prev_model)).sum()))
w = lambda d: (1.25 * d.cw5 + 2 * d.cw1h).sum() / 1e6
print('weighted M: first', round(w(rw[first]), 1), 'gap>60', round(w(rw[rw.gap > 3600]), 1), 'switch', round(w(rw[(rw.model != rw.prev_model) & ~first]), 1))
