"""item5c.py - lead-review re-dispatch loops: per vulyk-cycle run, lead-review dispatches vs rounds opened,
'NO VERDICT' / non-JSON record-seat log lines, and the tokens of the surplus reviews. Also empty-seat (turn cap) events."""
import json, re, collections, pandas as pd
ag = {}
for l in open('agents.jsonl', encoding='utf-8'):
    d = json.loads(l)
    if d['wf']:
        t = collections.Counter()
        for m, x in d['totals'].items(): t.update(x)
        ag[d['agent_id']] = dict(raw=t['in'] + t['cw'] + t['cr'] + t['out'], w=t['in'] + 1.25 * t['cw5'] + 2 * t['cw1h'] + 0.1 * t['cr'] + t['out'], start=d['start'] or 0,
                                 verb=(re.search(r'cycle\.sh\s+([a-z-]+)', d['bash'][0]['cmd']).group(1) if d['bash'] and re.search(r'cycle\.sh\s+([a-z-]+)', d['bash'][0]['cmd'] or '') else ''))
rows = []
for l in open('workflows.jsonl', encoding='utf-8'):
    w = json.loads(l)
    if w['workflowName'] != 'vulyk-cycle': continue
    try: res = json.loads(w['result']) if w['result'] else {}
    except Exception: res = {}
    tier = res.get('tier') if isinstance(res, dict) else None
    A = w['agents']
    opens = sum(1 for a in A if a['agentType'] == 'cycle-clerk' and ag.get(a['agentId'], {}).get('verb') == 'open-round')
    lr = sorted([a for a in A if a['agentType'] == 'lead-review'], key=lambda a: a['startedAt'] or 0)
    per = 2 if tier == 4 else 1
    exp = opens * per
    surplus = lr[exp:] if len(lr) > exp else []
    nov = sum(1 for x in w['logs'] if 'non-JSON last line from "record-seat' in x and ' review ' in x)
    empty = sum(1 for x in w['logs'] if 'returned empty' in x or 'returned no report' in x)
    rows.append(dict(project=w['project'][:22], run=w['runId'], spec=(w['args'] or {}).get('spec', '').split('/')[-1], ts=(w['timestamp'] or '')[:16], tier=tier,
                     opens=opens, lead_reviews=len(lr), expected=exp, surplus=len(surplus), review_nonjson_logs=nov, empty_seat_logs=empty,
                     surplus_raw_M=round(sum(ag.get(a['agentId'], {}).get('raw', 0) for a in surplus) / 1e6, 1),
                     surplus_w_M=round(sum(ag.get(a['agentId'], {}).get('w', 0) for a in surplus) / 1e6, 2),
                     surplus_min=round(sum((a['durationMs'] or 0) for a in surplus) / 60000)))
R = pd.DataFrame(rows)
S = R[(R.surplus > 0) | (R.review_nonjson_logs > 0)].sort_values('surplus_w_M', ascending=False)
print(S.to_markdown(index=False))
print('runs', len(R), 'runs with surplus reviews', int((R.surplus > 0).sum()), 'surplus reviews', int(R.surplus.sum()), 'surplus raw M', round(R.surplus_raw_M.sum(), 1), 'weighted M', round(R.surplus_w_M.sum(), 1), 'agent-minutes', int(R.surplus_min.sum()))
print('empty/no-report seat log lines total', int(R.empty_seat_logs.sum()), 'in', int((R.empty_seat_logs > 0).sum()), 'runs')
R.to_csv('item5_review_loops.csv', index=False)
