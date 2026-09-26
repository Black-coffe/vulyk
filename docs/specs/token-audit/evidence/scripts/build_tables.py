"""build_tables.py - derive session_table.csv (one row per main session, Queen + all its subagents)
and agent_table.csv (one row per subagent) from parse_all.py outputs. Classifies sessions VULYK / non-VULYK.
Weighted tokens (brief's approximation): in + 1.25*cw5m + 2*cw1h + 0.1*cr + out.
"""
import json, csv, re, collections, datetime

VULYK_AGENTS = {'worker-code', 'worker-test', 'council-sonnet', 'council-opus', 'council-haiku',
                'lead-review', 'lead-architect', 'cycle-clerk', 'drone-scout', 'drone-coverage',
                'drone-docs', 'queen-planner', 'librarian'}
STRONG = ('vulyk_agent', 'vulyk_agent_file', 'vulyk_workflow', 'vulyk_skill', 'vulyk_cmd', 'vulyk_cycle_sh', 'vulyk_clerk')
RECENT = datetime.datetime(2026, 9, 13, tzinfo=datetime.timezone.utc).timestamp()


def nm(m):
    return re.sub(r'\[.*\]$', '', m or '?')


def z():
    return collections.Counter()


def wsum(t):
    return t.get('in', 0) + 1.25 * t.get('cw5', 0) + 2 * t.get('cw1h', 0) + 0.1 * t.get('cr', 0) + t.get('out', 0)


def raw(t):
    return t.get('in', 0) + t.get('cw', 0) + t.get('cr', 0) + t.get('out', 0)


def load():
    S = {}
    for l in open('sessions.jsonl', encoding='utf-8'):
        d = json.loads(l)
        S[(d['project'], d['session'])] = d
    AG = collections.defaultdict(list)
    for l in open('agents.jsonl', encoding='utf-8'):
        d = json.loads(l)
        AG[(d['project'], d['session'])].append(d)
    WF = collections.defaultdict(list)
    for l in open('workflows.jsonl', encoding='utf-8'):
        d = json.loads(l)
        WF[(d['project'], d['session'])].append(d)
    return S, AG, WF


def flat(totals):
    c = z()
    for m, t in totals.items():
        for k in ('in', 'cw5', 'cw1h', 'cw', 'cr', 'out', 'n'):
            c[k] += t.get(k, 0)
    return c


def by_model(totals, into):
    for m, t in totals.items():
        for k in ('in', 'cw5', 'cw1h', 'cw', 'cr', 'out', 'n'):
            into[nm(m)][k] += t.get(k, 0)


def main():
    S, AG, WF = load()
    rows = []
    arows = []
    for k, d in S.items():
        if not d['start']:
            continue
        m = d['markers']
        ags = AG.get(k, [])
        strong = any(m.get(x) for x in STRONG) or any(a['agent_type'] in VULYK_AGENTS for a in ags)
        q = flat(d['main_totals'])
        a_all = z()
        per_type = collections.defaultdict(z)
        bm = collections.defaultdict(z)
        by_model(d['main_totals'], bm)
        n_edits = d['main_edits']
        files = set(d['main_edit_files'])
        la, lr = d['main_lines_add'], d['main_lines_rem']
        for a in ags:
            t = flat(a['totals'])
            a_all.update(t)
            per_type[a['agent_type']].update(t)
            per_type[a['agent_type']]['dispatches'] += 1
            by_model(a['totals'], bm)
            n_edits += a['n_edits']
            files.update(a['edit_files'])
            la += a['lines_add']; lr += a['lines_rem']
            fc = a['first_call'] or {}
            arows.append({'project': a['project'], 'session': a['session'], 'agent_id': a['agent_id'], 'agent_type': a['agent_type'],
                          'wf': a['wf'] or '', 'slug': a['slug'] or '', 'start': a['start'], 'end': a['end'],
                          'dur_s': (a['end'] - a['start']) if a['start'] and a['end'] else '',
                          'n_calls': a['n_calls'], 'n_tool_uses': a['n_tool_uses'], 'n_edits': a['n_edits'], 'n_bash': a['n_bash'],
                          'models': '|'.join(sorted(nm(x) for x in a['totals'])),
                          'in': t['in'], 'cw5': t['cw5'], 'cw1h': t['cw1h'], 'cr': t['cr'], 'out': t['out'],
                          'raw': raw(t), 'weighted': round(wsum(t)),
                          'fc_ctx': (fc.get('in', 0) + fc.get('cw', 0) + fc.get('cr', 0)) if fc else '',
                          'fc_cw': fc.get('cw', '') if fc else '', 'fc_cr': fc.get('cr', '') if fc else '',
                          'max_ctx': a['max_ctx'], 'prompt_chars': a['prompt_chars'], 'instr_chars': a['instr_chars'] or '',
                          'recent': int((a['start'] or 0) >= RECENT)})
        tot = z(); tot.update(q); tot.update(a_all)
        cs = d.get('cost_state') or {}
        wfs = WF.get(k, [])
        row = {'project': d['project'], 'session': d['session'], 'start': d['start'], 'end': d['end'],
               'date': datetime.datetime.utcfromtimestamp(d['start']).strftime('%Y-%m-%d'),
               'recent': int(d['start'] >= RECENT), 'vulyk': int(strong),
               'instr_vulyk': {True: 1, False: 0, None: ''}[d['instr_has_vulyk']],
               'n_prompts': d['n_prompts'], 'elapsed_min': round((d['end'] - d['start']) / 60, 1),
               'active_min': round(d['active_s'] / 60, 1),
               'main_calls': d['main_calls'], 'n_sub': len(ags),
               'n_wf': len(wfs), 'wf_agents': sum(len(w['agents']) for w in wfs),
               'q_in': q['in'], 'q_cw5': q['cw5'], 'q_cw1h': q['cw1h'], 'q_cr': q['cr'], 'q_out': q['out'],
               'a_in': a_all['in'], 'a_cw5': a_all['cw5'], 'a_cw1h': a_all['cw1h'], 'a_cr': a_all['cr'], 'a_out': a_all['out'],
               'raw': raw(tot), 'weighted': round(wsum(tot)), 'q_raw': raw(q), 'a_raw': raw(a_all),
               'q_weighted': round(wsum(q)), 'a_weighted': round(wsum(a_all)),
               'cost_usd': round(cs.get('totalCostUSD') or 0, 2) if cs else '',
               'lines_add_h': cs.get('totalLinesAdded', '') if cs else '', 'lines_rem_h': cs.get('totalLinesRemoved', '') if cs else '',
               'n_edits': n_edits, 'n_files': len(files), 'lines_add': la, 'lines_rem': lr,
               'models': json.dumps({mm: raw(v) for mm, v in bm.items()}),
               'per_type': json.dumps({t: {'n': v['dispatches'], 'raw': raw(v), 'w': round(wsum(v))} for t, v in per_type.items()}),
               'markers': json.dumps(m), 'skills': ' '.join(sorted(set(s[1] for s in d['skills'])))[:200],
               'first_prompt': (d['first_prompt'] or '').replace('\n', ' ')[:160]}
        rows.append(row)
    with open('session_table.csv', 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader(); w.writerows(rows)
    with open('agent_table.csv', 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=list(arows[0].keys()))
        w.writeheader(); w.writerows(arows)
    print(len(rows), 'sessions', len(arows), 'agents')


if __name__ == '__main__':
    main()
