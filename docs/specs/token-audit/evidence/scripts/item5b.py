"""item5b.py - token cost of one council round and of the extra circles, from workflow agents (phases) and Queen calls.
Round = one `cycle.sh judge` clerk. Direct round cost = Round+Judge phase agents / judges.
Extra-circle window per spec = (end of first judge, end of last judge]: every slug-attributed Queen call and subagent started in it."""
import json, re, collections, pandas as pd
wfspec = {}
for l in open('workflows.jsonl', encoding='utf-8'):
    w = json.loads(l); a = w['args'] if isinstance(w['args'], dict) else {}
    wfspec[(w['session'], w['runId'])] = (a.get('spec') or '').rstrip('/').split('/')[-1]
AG = []
for l in open('agents.jsonl', encoding='utf-8'):
    d = json.loads(l)
    sl = wfspec.get((d['session'], d['wf'])) if d['wf'] else None
    sl = sl or d['slug'] or '-'
    t = collections.Counter()
    for m, x in d['totals'].items(): t.update(x)
    raw = t['in'] + t['cw'] + t['cr'] + t['out']; w = t['in'] + 1.25 * t['cw5'] + 2 * t['cw1h'] + 0.1 * t['cr'] + t['out']
    verb = ''
    if d['bash']:
        m = re.search(r'cycle\.sh\s+([a-z-]+)', d['bash'][0]['cmd'] or '')
        verb = m.group(1) if m else ''
    AG.append(dict(project=d['project'], session=d['session'], slug=sl, type=d['agent_type'], phase=d['workflowPhase'] or '', wf=d['wf'] or '', start=d['start'], end=d['end'], raw=raw, w=w, verb=verb))
A = pd.DataFrame(AG)
A = A[A.start.notna()]
wa = A[A.wf != '']
judges = wa[(wa.type == 'cycle-clerk') & (wa.verb == 'judge')]
nj = judges.groupby(['project', 'slug']).size()
rj = wa[wa.phase.isin(['Round', 'Judge'])].groupby(['project', 'slug']).agg(raw=('raw', 'sum'), w=('w', 'sum'))
per = rj.join(nj.rename('judges'), how='inner')
per = per[per.judges > 0]
per['raw_per_round'] = per.raw / per.judges; per['w_per_round'] = per.w / per.judges
print('specs with workflow rounds', len(per), 'judges', per.judges.sum())
print('DIRECT cost of one round (seats+lead-review+clerks+judge): raw median %.1fM p75 %.1fM max %.1fM | weighted median %.2fM p75 %.2fM' % (
    per.raw_per_round.median() / 1e6, per.raw_per_round.quantile(.75) / 1e6, per.raw_per_round.max() / 1e6, per.w_per_round.median() / 1e6, per.w_per_round.quantile(.75) / 1e6))
# composition of the round phase
rp = wa[wa.phase.isin(['Round', 'Judge'])].groupby('type').agg(n=('raw', 'size'), raw=('raw', 'sum'), w=('w', 'sum'))
rp['w_share%'] = (rp.w / rp.w.sum() * 100).round(1); rp['n_per_round'] = (rp.n / per.judges.sum()).round(2)
print(rp.sort_values('w', ascending=False).to_markdown())
rep = wa[wa.phase == 'Repair'].groupby('type').agg(n=('raw', 'size'), raw=('raw', 'sum'), w=('w', 'sum'))
print('repair phase', rep.to_dict())
# extra-circle windows
cm = pd.read_csv('calls_main.csv', keep_default_na=False)
cm['ts'] = pd.to_numeric(cm.ts, errors='coerce')
cm['raw'] = cm['in'] + cm.cw5 + cm.cw1h + cm.cr + cm.out
cm['w'] = cm['in'] + 1.25 * cm.cw5 + 2 * cm.cw1h + 0.1 * cm.cr + cm.out
out = []
for (p, s), g in judges.groupby(['project', 'slug']):
    if len(g) < 2: continue
    t0, t1 = g.end.min(), g.end.max()
    a = A[(A.project == p) & (A.slug == s) & (A.start > t0) & (A.start <= t1)]
    q = cm[(cm.project == p) & (cm.slug == s) & (cm.ts > t0) & (cm.ts <= t1)]
    tot_a = A[(A.project == p) & (A.slug == s)]; tot_q = cm[(cm.project == p) & (cm.slug == s)]
    out.append(dict(project=p, slug=s, judges=len(g), extra_rounds=len(g) - 1, window_h=round((t1 - t0) / 3600, 1),
                    extra_raw_M=round((a.raw.sum() + q.raw.sum()) / 1e6, 1), extra_w_M=round((a.w.sum() + q.w.sum()) / 1e6, 1),
                    extra_queen_w_M=round(q.w.sum() / 1e6, 1), extra_workers=int(a.type.isin(['worker-code', 'worker-test']).sum()), extra_clerks=int((a.type == 'cycle-clerk').sum()),
                    task_raw_M=round((tot_a.raw.sum() + tot_q.raw.sum()) / 1e6, 1), task_w_M=round((tot_a.w.sum() + tot_q.w.sum()) / 1e6, 1)))
E = pd.DataFrame(out).sort_values('extra_w_M', ascending=False)
E['extra_share_w%'] = (E.extra_w_M / E.task_w_M * 100).round(0)
E['w_per_extra_round_M'] = (E.extra_w_M / E.extra_rounds).round(2)
print(E.to_markdown(index=False))
print('specs with >=1 extra round:', len(E), '| extra rounds', E.extra_rounds.sum(), '| extra-circle weighted', round(E.extra_w_M.sum(), 1), 'M of those tasks', round(E.task_w_M.sum(), 1), 'M =', round(E.extra_w_M.sum() / E.task_w_M.sum() * 100, 1), '%',
      '| median weighted per extra round', E.w_per_extra_round_M.median(), '| median extra window h', E.window_h.median())
E.to_csv('item5_extra_circles.csv', index=False); per.to_csv('item5_round_cost.csv')
