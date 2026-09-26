"""task_table.py - allocate every token of every VULYK session to a spec slug -> task_table.csv, task_agent_types.csv.

Delimitation of a task = (project, spec slug):
  * Workflow agents -> the run's args.spec.
  * Other subagents -> first docs/specs/<slug> in their prompt; else the Queen's current slug at their start.
  * Queen API calls -> the Queen's current slug: the last slug named in a Skill/command arg, Workflow arg, Agent prompt,
    Edit/Write path or Bash command at or before that call (calls before the first mention go to the first slug).
  * Active wall-clock: merged event timestamps of Queen + subagents, gaps <= 15 min summed, gap credited to the later event's slug.
Only sessions with a strong VULYK marker are included.
"""
import json, csv, re, collections, datetime
import pandas as pd

RECENT = datetime.datetime(2026, 9, 13, tzinfo=datetime.timezone.utc).timestamp()


def W(r):
    return r['in'] + 1.25 * r['cw5'] + 2 * r['cw1h'] + 0.1 * r['cr'] + r['out']


def main():
    st = pd.read_csv('session_table.csv')
    vs = st[st.vulyk == 1]
    vkeys = set(zip(vs.project, vs.session))
    S = {}
    for l in open('sessions.jsonl', encoding='utf-8'):
        d = json.loads(l)
        if (d['project'], d['session']) in vkeys:
            S[(d['project'], d['session'])] = d
    ag = pd.read_csv('agent_table.csv', keep_default_na=False)
    ag = ag[[(p, s) in vkeys for p, s in zip(ag.project, ag.session)]]
    wfspec = {}
    wfinfo = collections.defaultdict(list)
    for l in open('workflows.jsonl', encoding='utf-8'):
        w = json.loads(l)
        a = w['args'] if isinstance(w['args'], dict) else {}
        sp = (a.get('spec') or '').rstrip('/').split('/')[-1]
        wfspec[(w['session'], w['runId'])] = sp
        if sp:
            wfinfo[(w['project'], sp)].append(w)
    T = collections.defaultdict(lambda: collections.Counter())
    types = collections.defaultdict(lambda: collections.Counter())
    meta = collections.defaultdict(lambda: {'sessions': set(), 'start': None, 'end': None, 'models': collections.Counter()})

    def touch(key, t0, t1, sess):
        m = meta[key]
        m['sessions'].add(sess)
        if t0 and (m['start'] is None or t0 < m['start']):
            m['start'] = t0
        if t1 and (m['end'] is None or t1 > m['end']):
            m['end'] = t1
    # Queen
    cm = pd.read_csv('calls_main.csv', keep_default_na=False)
    cm = cm[[(p, s) in vkeys for p, s in zip(cm.project, cm.session)]]
    for r in cm.to_dict('records'):
        key = (r['project'], r['slug'] or '-')
        for k in ('in', 'cw5', 'cw1h', 'cr', 'out'):
            T[key]['q_' + k] += r[k]
        T[key]['q_calls'] += 1
        touch(key, float(r['ts']) if r['ts'] else None, float(r['ts']) if r['ts'] else None, r['session'])
    for r in ag.to_dict('records'):
        sl = wfspec.get((r['session'], r['wf'])) if r['wf'] else None
        sl = sl or r['slug'] or '-'
        key = (r['project'], sl)
        for k in ('in', 'cw5', 'cw1h', 'cr', 'out'):
            T[key]['a_' + k] += r[k]
        types[key][r['agent_type']] += 1
        types[key]['@raw:' + r['agent_type']] += r['raw']
        types[key]['@w:' + r['agent_type']] += r['weighted']
        types[key]['@calls:' + r['agent_type']] += r['n_calls']
        touch(key, float(r['start']) if r['start'] != '' else None, float(r['end']) if r['end'] != '' else None, r['session'])
    # active time
    act = collections.Counter()
    for k, d in S.items():
        for sl, sec in d['active_by_slug'].items():
            act[(k[0], sl)] += sec
    # council ledger (deduped globally)
    led = collections.defaultdict(list)
    seen = set()
    for l in open('council_all.jsonl', encoding='utf-8'):
        d = json.loads(l)
        kk = (d['spec'], d['ts'], d['head'])
        if kk in seen:
            continue
        seen.add(kk)
        led[d['spec']].append(d)
    rows = []
    for key, t in T.items():
        p, sl = key
        q = {k: t['q_' + k] for k in ('in', 'cw5', 'cw1h', 'cr', 'out')}
        a = {k: t['a_' + k] for k in ('in', 'cw5', 'cw1h', 'cr', 'out')}
        tot = {k: q[k] + a[k] for k in q}
        raw = sum(tot.values())
        m = meta[key]
        wfs = wfinfo.get(key, [])
        lr = led.get(sl, [])
        ty = types[key]
        rows.append({'project': p, 'slug': sl, 'first': datetime.datetime.utcfromtimestamp(m['start']).strftime('%Y-%m-%d %H:%M') if m['start'] else '',
                     'recent': int((m['start'] or 0) >= RECENT), 'n_sessions': len(m['sessions']),
                     'raw': raw, 'weighted': round(W(tot)), 'in': tot['in'], 'cw5': tot['cw5'], 'cw1h': tot['cw1h'], 'cr': tot['cr'], 'out': tot['out'],
                     'queen_raw': sum(q.values()), 'queen_w': round(W(q)), 'agents_raw': sum(a.values()), 'agents_w': round(W(a)),
                     'queen_calls': t['q_calls'], 'dispatches': sum(v for kk, v in ty.items() if not kk.startswith('@')),
                     'clerks': ty.get('cycle-clerk', 0), 'workers': ty.get('worker-code', 0) + ty.get('worker-test', 0),
                     'seats': ty.get('council-sonnet', 0) + ty.get('council-opus', 0) + ty.get('council-haiku', 0),
                     'lead_review': ty.get('lead-review', 0),
                     'wf_runs': len(wfs), 'wf_totalTokens': sum((w['totalTokens'] or 0) for w in wfs),
                     'wf_minutes': round(sum((w['durationMs'] or 0) for w in wfs) / 60000),
                     'active_min': round(act.get(key, 0) / 60), 'elapsed_h': round(((m['end'] or 0) - (m['start'] or 0)) / 3600, 1),
                     'ledger_rounds': len(lr), 'ledger_red': sum(1 for x in lr if x['verdict'] != 'GREEN'),
                     'ledger_final': lr[-1]['verdict'] if lr else '',
                     'types': json.dumps({kk: v for kk, v in ty.items() if not kk.startswith('@')})})
        for kk, v in ty.items():
            if not kk.startswith('@'):
                pass
    df = pd.DataFrame(rows).sort_values('raw', ascending=False)
    df.to_csv('task_table.csv', index=False)
    # agent-type table per task
    trows = []
    for key, ty in types.items():
        for kk, v in ty.items():
            if kk.startswith('@'):
                continue
            trows.append({'project': key[0], 'slug': key[1], 'agent_type': kk, 'n': v, 'raw': ty['@raw:' + kk], 'w': ty['@w:' + kk], 'calls': ty['@calls:' + kk]})
    pd.DataFrame(trows).to_csv('task_agent_types.csv', index=False)
    print(len(df), 'tasks')


if __name__ == '__main__':
    main()
