"""item7b.py - sum item7 timeline rows into the windows used in forensics.md section 7 (all rows incl. Queen segments, by start time)."""
import pandas as pd, sys
def win(csv, cuts):
    t = pd.read_csv(csv); t = t[t.who != 'WF RUN']
    t['k'] = pd.to_datetime('2026-' + t.start, format='%Y-%m-%d %H:%M')
    edges = [pd.Timestamp('2026-' + c) for c in cuts] + [pd.Timestamp('2027-01-01')]
    for i in range(len(edges) - 1):
        s = t[(t.k >= edges[i]) & (t.k < edges[i + 1])]
        print(cuts[i], '| raw', round(s.raw.sum() / 1e6, 1), '| w', round(s.w.sum() / 1e6, 1), '| queen raw', round(s[s.who == 'QUEEN'].raw.sum() / 1e6, 1))
    print('TOTAL', round(t.raw.sum() / 1e6, 1), round(t.w.sum() / 1e6, 1))
print('== mmorpg')
win('item7_timeline_C--laragon-www-mmorpg_bfc65f95.csv', ['09-24 14:52', '09-24 18:05', '09-24 19:04', '09-24 19:50', '09-24 20:17', '09-24 20:30', '09-24 20:51', '09-24 22:10', '09-24 22:38', '09-24 23:11', '09-25 00:04', '09-25 00:30', '09-25 10:50', '09-25 11:48'])
print('== katan')
win('item7_timeline_E--Projects-katan_f7aff30d.csv', ['09-25 13:34', '09-25 15:37', '09-25 15:46', '09-25 16:42', '09-25 16:51', '09-25 19:11', '09-25 20:44'])
t = pd.read_csv('item7_timeline_C--laragon-www-mmorpg_bfc65f95.csv'); r = t[t.what.str.startswith('Round', na=False)]
print('mmorpg rounds raw', round(r.raw.sum() / 1e6, 1), 'w', round(r.w.sum() / 1e6, 1), 'of', round(t.raw.sum() / 1e6, 1), round(t.w.sum() / 1e6, 1))
t = pd.read_csv('item7_timeline_E--Projects-katan_f7aff30d.csv'); r = t[t.what.str.startswith(('Round', 'Judge', 'Repair'), na=False)]
b = t[t.what.str.startswith('Build', na=False) | ((t.who == 'dispatch') & (t.what == 'worker-code'))]
print('katan round+judge+repair raw', round(r.raw.sum() / 1e6, 1), 'w', round(r.w.sum() / 1e6, 1), '| build raw', round(b.raw.sum() / 1e6, 1), 'w', round(b.w.sum() / 1e6, 1))
rr = t[t.what.str.startswith('Round', na=False)]
print('katan rounds only raw', round(rr.raw.sum() / 1e6, 1), 'w', round(rr.w.sum() / 1e6, 1))
