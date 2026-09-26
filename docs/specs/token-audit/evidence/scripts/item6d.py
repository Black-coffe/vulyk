"""item6d.py - elapsed (first->last event) vs active wall-clock, VULYK cycle tasks vs non-VULYK work sessions (code lines > 0)."""
import pandas as pd
U = pd.read_csv('item6_units.csv', keep_default_na=False)
t = pd.read_csv('item1_recent_tasks.csv', keep_default_na=False)
st = pd.read_csv('session_table.csv')
A = U[(U.unit == 'A')].merge(t[['project', 'slug', 'elapsed_h']], on=['project', 'slug'])
C = U[(U.unit == 'C')].merge(st[['project', 'session', 'elapsed_min', 'n_sub']], on=['project', 'session'])
for name, df, col, k in (('A VULYK task', A, 'elapsed_h', 60), ('C non-VULYK session', C, 'elapsed_min', 1)):
    d = df[df.code_lines > 0]
    print(name, 'n', len(d), 'elapsed min median', round((d[col] * k).median()), 'p75', round((d[col] * k).quantile(.75)), '| active median', d.active_min.median(), '| code lines median', d.code_lines.median())
print('C subagents median', C.n_sub.median(), 'share with any subagent', round((C.n_sub > 0).mean(), 2))
