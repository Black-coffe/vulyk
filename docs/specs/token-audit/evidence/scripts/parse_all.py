"""parse_all.py - streaming parser over ~/.claude/projects transcripts.

Outputs (in OUT dir):
  sessions.jsonl   one record per main session (Queen) with aggregates
  agents.jsonl     one record per subagent transcript (incl. workflow agents)
  calls_main.csv   one row per deduped API call of a main session
  calls_agent.csv  one row per deduped API call of a subagent
  workflows.jsonl  one record per workflow run json
  dispatches.jsonl one record per Agent/Task tool_use in a main session
Dedup: an API response written as several lines shares message.id -> keep max of each usage field.
"""
import json, os, re, sys, glob, csv, time, bisect
from datetime import datetime
from collections import defaultdict, Counter

ROOT = os.path.expanduser(r'C:\Users\Andrei\.claude\projects')
OUT = os.path.dirname(os.path.abspath(__file__))
SLUG_RE = re.compile(r'docs[/\\]+specs[/\\]+([A-Za-z0-9][A-Za-z0-9._-]*)')
VULYK_AGENTS = {'worker-code', 'worker-test', 'council-sonnet', 'council-opus', 'council-haiku',
                'lead-review', 'lead-architect', 'cycle-clerk', 'drone-scout', 'drone-coverage',
                'drone-docs', 'queen-planner', 'librarian'}
EDIT_TOOLS = {'Edit', 'Write', 'MultiEdit', 'NotebookEdit'}


def ts(s):
    try:
        return datetime.fromisoformat(s.replace('Z', '+00:00')).timestamp()
    except Exception:
        return None


def nlines(s):
    if not s:
        return 0
    return s.count('\n') + 1


def usage_fields(u):
    cc = u.get('cache_creation') or {}
    cw = u.get('cache_creation_input_tokens') or 0
    c1h = cc.get('ephemeral_1h_input_tokens') or 0
    c5 = cc.get('ephemeral_5m_input_tokens')
    if c5 is None:
        c5 = cw - c1h
    return {'in': u.get('input_tokens') or 0, 'cw5': c5 or 0, 'cw1h': c1h, 'cw': cw,
            'cr': u.get('cache_read_input_tokens') or 0, 'out': u.get('output_tokens') or 0}


def slugs_in(text):
    if not text:
        return []
    out = []
    for m in SLUG_RE.finditer(text):
        s = m.group(1).rstrip('.')
        for ext in ('.md', '.json', '.jsonl'):
            if s.endswith(ext):
                s = None
                break
        if s and s not in out:
            out.append(s)
    return out


def parse_file(path, is_main):
    """Return dict with calls (deduped, ordered), events ts list, tool uses, attachments etc."""
    calls = {}  # id -> dict
    order = []
    tss = []
    tool_uses = []  # (ts, name, input)
    tool_results = {}  # tool_use_id -> ts
    atts = []  # (ts, type, hookEvent, size, extra)
    user_prompts = []  # (ts, text)
    first_user = None
    cost_state = None
    cwd = None
    attribution = None
    instr_has_vulyk = None
    instr_chars = None
    n_lines = 0
    with open(path, encoding='utf-8', errors='replace') as f:
        for line in f:
            n_lines += 1
            try:
                d = json.loads(line)
            except Exception:
                continue
            t = d.get('type')
            tv = ts(d['timestamp']) if d.get('timestamp') else None
            if tv:
                tss.append(tv)
            if cwd is None and d.get('cwd'):
                cwd = d['cwd']
            if t == 'cost-state':
                cost_state = d
                continue
            if t == 'assistant':
                m = d.get('message') or {}
                if attribution is None and d.get('attributionAgent'):
                    attribution = d.get('attributionAgent')
                mid = m.get('id') or d.get('requestId') or d.get('uuid')
                u = m.get('usage')
                if u and m.get('model') != '<synthetic>':
                    uf = usage_fields(u)
                    if mid not in calls:
                        calls[mid] = {'ts': tv, 'model': m.get('model'), **uf}
                        order.append(mid)
                    else:
                        c = calls[mid]
                        for k in uf:
                            c[k] = max(c[k], uf[k])
                for c in m.get('content') or []:
                    if isinstance(c, dict) and c.get('type') == 'tool_use':
                        tool_uses.append((tv, c.get('name'), c.get('input') or {}, c.get('id'), mid))
            elif t == 'user':
                m = d.get('message') or {}
                cont = m.get('content')
                if isinstance(cont, list):
                    for c in cont:
                        if isinstance(c, dict) and c.get('type') == 'tool_result':
                            tool_results[c.get('tool_use_id')] = tv
                    texts = [c.get('text', '') for c in cont if isinstance(c, dict) and c.get('type') == 'text']
                    txt = '\n'.join(texts) if texts else None
                else:
                    txt = cont
                if txt and not d.get('isMeta') and not (isinstance(cont, list) and any(isinstance(c, dict) and c.get('type') == 'tool_result' for c in cont)):
                    if first_user is None:
                        first_user = txt
                    user_prompts.append((tv, txt[:3000]))
            elif t == 'attachment':
                a = d.get('attachment') or {}
                at = a.get('type')
                size = len(json.dumps(a, ensure_ascii=False))
                extra = None
                if at == 'instructions':
                    body = ''.join(fi.get('content', '') for fi in a.get('files', []))
                    instr_has_vulyk = ('VULYK' in body)
                    instr_chars = len(body)
                    extra = [(fi.get('path'), len(fi.get('content', ''))) for fi in a.get('files', [])]
                if at in ('hook_additional_context', 'hook_system_message', 'instructions', 'skill_listing',
                          'agent_listing_delta', 'mcp_instructions_delta', 'deferred_tools_delta',
                          'prompt_snapshot', 'queued_command', 'nested_memory', 'todo_reminder',
                          'total_tokens_reminder', 'silent_turn_reminder', 'plan_mode', 'critical_system_reminder'):
                    atts.append((tv, at, a.get('hookEvent') or a.get('hookName'), size, extra))
                elif at:
                    atts.append((tv, at, None, size, None))
    call_list = [dict(id=k, **calls[k]) for k in order]
    return dict(calls=call_list, tss=tss, tool_uses=tool_uses, tool_results=tool_results, atts=atts,
                user_prompts=user_prompts, first_user=first_user, cost_state=cost_state, cwd=cwd,
                attribution=attribution, instr_has_vulyk=instr_has_vulyk, instr_chars=instr_chars,
                n_lines=n_lines)


def tot(calls):
    agg = defaultdict(lambda: Counter())
    for c in calls:
        m = c['model'] or '?'
        for k in ('in', 'cw5', 'cw1h', 'cw', 'cr', 'out'):
            agg[m][k] += c[k]
        agg[m]['n'] += 1
    return {m: dict(v) for m, v in agg.items()}


def edits_of(tool_uses):
    files = set()
    n = 0
    add = rem = 0
    for (tv, name, inp, tid, mid) in tool_uses:
        if name in EDIT_TOOLS:
            n += 1
            fp = inp.get('file_path') or inp.get('notebook_path')
            if fp:
                files.add(fp.replace('\\', '/').lower())
            if name == 'Edit':
                add += nlines(inp.get('new_string')); rem += nlines(inp.get('old_string'))
            elif name == 'Write':
                add += nlines(inp.get('content'))
            elif name == 'MultiEdit':
                for e in inp.get('edits') or []:
                    add += nlines(e.get('new_string')); rem += nlines(e.get('old_string'))
    return n, sorted(files), add, rem


def main():
    only = sys.argv[1:]  # optional list of project dir names
    fs = open(os.path.join(OUT, 'sessions.jsonl'), 'w', encoding='utf-8')
    fa = open(os.path.join(OUT, 'agents.jsonl'), 'w', encoding='utf-8')
    fw = open(os.path.join(OUT, 'workflows.jsonl'), 'w', encoding='utf-8')
    fd = open(os.path.join(OUT, 'dispatches.jsonl'), 'w', encoding='utf-8')
    cm = csv.writer(open(os.path.join(OUT, 'calls_main.csv'), 'w', newline='', encoding='utf-8'))
    ca = csv.writer(open(os.path.join(OUT, 'calls_agent.csv'), 'w', newline='', encoding='utf-8'))
    cm.writerow(['project', 'session', 'i', 'ts', 'model', 'in', 'cw5', 'cw1h', 'cr', 'out', 'slug'])
    ca.writerow(['project', 'session', 'agent_id', 'agent_type', 'i', 'ts', 'model', 'in', 'cw5', 'cw1h', 'cr', 'out'])
    t0 = time.time()
    projs = sorted(os.listdir(ROOT))
    for p in projs:
        pdir = os.path.join(ROOT, p)
        if not os.path.isdir(pdir):
            continue
        if only and p not in only:
            continue
        for sf in glob.glob(os.path.join(pdir, '*.jsonl')):
            sid = os.path.basename(sf)[:-6]
            try:
                r = parse_file(sf, True)
            except Exception as e:
                print('ERR', sf, e, file=sys.stderr)
                continue
            # --- slug timeline for the Queen
            events = []  # (ts, slug)
            markers = Counter()
            dispatch_types = Counter()
            workflows_launched = []
            skills = []
            for (tv, name, inp, tid, mid) in r['tool_uses']:
                sl = []
                if name in ('Agent', 'Task'):
                    st = inp.get('subagent_type') or 'general-purpose'
                    dispatch_types[st] += 1
                    if st in VULYK_AGENTS:
                        markers['vulyk_agent'] += 1
                    sl = slugs_in(inp.get('prompt', ''))
                    fd.write(json.dumps({'project': p, 'session': sid, 'ts': tv, 'subagent_type': st,
                                         'model': inp.get('model'), 'description': inp.get('description'),
                                         'slugs': sl[:3], 'prompt_chars': len(inp.get('prompt', '')),
                                         'tool_use_id': tid,
                                         'result_ts': r['tool_results'].get(tid),
                                         'bg': inp.get('run_in_background')}) + '\n')
                elif name == 'Workflow':
                    a = inp.get('args') or {}
                    sp = inp.get('scriptPath') or inp.get('name') or ''
                    workflows_launched.append({'ts': tv, 'script': sp, 'args': a})
                    if 'vulyk' in sp:
                        markers['vulyk_workflow'] += 1
                    if isinstance(a, dict) and a.get('spec'):
                        sl = slugs_in(a['spec']) or [a['spec'].split('/')[-1]]
                elif name == 'Skill':
                    sk = inp.get('skill') or ''
                    skills.append((tv, sk, (inp.get('args') or '')[:200]))
                    if sk.startswith('vulyk'):
                        markers['vulyk_skill'] += 1
                        a = (inp.get('args') or '').strip().split()
                        if a and sk in ('vulyk-build', 'vulyk-ship', 'vulyk-review', 'vulyk-resume') and re.match(r'^[A-Za-z0-9][A-Za-z0-9._-]*$', a[0]) and not a[0].startswith('--'):
                            sl = [a[0]]
                elif name in EDIT_TOOLS:
                    sl = slugs_in(inp.get('file_path', ''))
                elif name == 'Bash':
                    cmd = inp.get('command', '') or ''
                    if 'scripts/cycle.sh' in cmd or 'scripts/journal.sh' in cmd:
                        markers['vulyk_cycle_sh'] += 1
                    elif 'vulyk' in cmd.lower():
                        markers['vulyk_bash_weak'] += 1
                    sl = slugs_in(cmd)[:1]
                for s in sl[:1]:
                    events.append((tv, s))
            for (tv, txt) in r['user_prompts']:
                m = re.search(r'<command-name>/(vulyk-[a-z-]+)</command-name>', txt)
                if m:
                    markers['vulyk_cmd'] += 1
                    skills.append((tv, m.group(1), ''))
                    am = re.search(r'<command-args>([^<]*)</command-args>', txt)
                    if am and m.group(1) in ('vulyk-build', 'vulyk-ship', 'vulyk-review', 'vulyk-resume'):
                        a = am.group(1).strip().split()
                        if a and not a[0].startswith('--'):
                            events.append((tv, a[0]))
            events = [e for e in events if e[0] is not None]
            events.sort(key=lambda x: x[0])

            ev_ts = [e[0] for e in events]

            def slug_at(tv):
                if not events:
                    return None
                if tv is None:
                    return events[0][1]
                i = bisect.bisect_right(ev_ts, tv) - 1
                return events[max(i, 0)][1]
            # Queen calls
            for i, c in enumerate(r['calls']):
                c['slug'] = slug_at(c['ts'])
                cm.writerow([p, sid, i, c['ts'], c['model'], c['in'], c['cw5'], c['cw1h'], c['cr'], c['out'], c['slug']])
            # --- subagents
            agents_summary = []
            all_ts = [(x, 'main') for x in r['tss']]
            sub_files = glob.glob(os.path.join(pdir, sid, 'subagents', '**', 'agent-*.jsonl'), recursive=True)
            for af in sub_files:
                aid = os.path.basename(af)[6:-6]
                meta = {}
                mf = af[:-6] + '.meta.json'
                if os.path.exists(mf):
                    try:
                        meta = json.load(open(mf, encoding='utf-8'))
                    except Exception:
                        meta = {}
                wf = None
                mwf = re.search(r'workflows[/\\](wf_[^/\\]+)', af)
                if mwf:
                    wf = mwf.group(1)
                try:
                    ar = parse_file(af, False)
                except Exception as e:
                    print('ERR', af, e, file=sys.stderr)
                    continue
                atype = meta.get('customAgentType') or meta.get('agentType') or ar['attribution'] or '?'
                if atype in VULYK_AGENTS:
                    markers['vulyk_agent_file'] += 1
                if ar['attribution'] == 'cycle-clerk' or atype == 'cycle-clerk':
                    markers['vulyk_clerk'] += 1
                aslugs = slugs_in(ar['first_user'] or '')
                tstart = min(ar['tss']) if ar['tss'] else None
                tend = max(ar['tss']) if ar['tss'] else None
                aslug = aslugs[0] if aslugs else slug_at(tstart)
                ne, efiles, add, rem = edits_of(ar['tool_uses'])
                bash_cmds = []
                for (tv, name, inp, tid, mid) in ar['tool_uses']:
                    if name == 'Bash':
                        rt = ar['tool_results'].get(tid)
                        bash_cmds.append({'cmd': (inp.get('command') or '')[:160], 'dur': (rt - tv) if (rt and tv) else None})
                fc = ar['calls'][0] if ar['calls'] else None
                maxctx = max((c['in'] + c['cw'] + c['cr'] for c in ar['calls']), default=0)
                rec = {'project': p, 'session': sid, 'agent_id': aid, 'agent_type': atype,
                       'meta_agentType': meta.get('agentType'), 'wf': wf, 'workflowPhase': meta.get('workflowPhase'),
                       'description': meta.get('description'), 'meta_model': meta.get('model'),
                       'slug': aslug, 'prompt_slugs': aslugs[:3], 'start': tstart, 'end': tend,
                       'n_calls': len(ar['calls']), 'totals': tot(ar['calls']),
                       'first_call': fc, 'max_ctx': maxctx,
                       'n_tool_uses': len(ar['tool_uses']), 'tools': dict(Counter(x[1] for x in ar['tool_uses'])),
                       'n_edits': ne, 'edit_files': efiles, 'lines_add': add, 'lines_rem': rem,
                       'bash': bash_cmds[:40], 'n_bash': len(bash_cmds),
                       'prompt_chars': len(ar['first_user'] or ''),
                       'prompt_head': (ar['first_user'] or '')[:300],
                       'instr_chars': ar['instr_chars'],
                       'att_sizes': dict(Counter({a[1]: 0 for a in ar['atts']}) + Counter()),
                       }
                asz = Counter()
                for a in ar['atts']:
                    asz[a[1]] += a[3]
                rec['att_sizes'] = dict(asz)
                fa.write(json.dumps(rec) + '\n')
                for i, c in enumerate(ar['calls']):
                    ca.writerow([p, sid, aid, atype, i, c['ts'], c['model'], c['in'], c['cw5'], c['cw1h'], c['cr'], c['out']])
                agents_summary.append((atype, rec['totals'], aslug))
                all_ts.extend((x, aslug) for x in ar['tss'])
            # --- workflow run jsons
            for wj in glob.glob(os.path.join(pdir, sid, 'workflows', 'wf_*.json')):
                try:
                    w = json.load(open(wj, encoding='utf-8'))
                except Exception:
                    continue
                ag = []
                for x in w.get('workflowProgress') or []:
                    if x.get('type') == 'workflow_agent':
                        ag.append({k: x.get(k) for k in ('agentId', 'agentType', 'model', 'tokens', 'durationMs', 'toolCalls', 'startedAt', 'state', 'label', 'attempt')})
                res = w.get('result')
                fw.write(json.dumps({'project': p, 'session': sid, 'runId': w.get('runId'), 'workflowName': w.get('workflowName'),
                                     'scriptPath': w.get('scriptPath'), 'args': w.get('args'), 'status': w.get('status'),
                                     'totalTokens': w.get('totalTokens'), 'durationMs': w.get('durationMs'),
                                     'agentCount': w.get('agentCount'), 'totalToolCalls': w.get('totalToolCalls'),
                                     'startTime': w.get('startTime'), 'timestamp': w.get('timestamp'),
                                     'result_stage': res.get('stage') if isinstance(res, dict) else None,
                                     'result': json.dumps(res)[:1500] if res is not None else None,
                                     'logs': (w.get('logs') or [])[-60:], 'agents': ag,
                                     'script_len': len(w.get('script') or ''), 'defaultModel': w.get('defaultModel')}) + '\n')
            # --- session record
            ne, efiles, add, rem = edits_of(r['tool_uses'])
            hooks = Counter(); hookn = Counter()
            for a in r['atts']:
                key = a[1] + (':' + a[2] if a[2] else '')
                hooks[key] += a[3]; hookn[key] += 1
            cs = r['cost_state']
            rec = {'project': p, 'session': sid, 'cwd': r['cwd'], 'start': min(r['tss']) if r['tss'] else None,
                   'end': max(r['tss']) if r['tss'] else None, 'n_lines': r['n_lines'],
                   'n_prompts': len(r['user_prompts']), 'first_prompt': (r['first_user'] or '')[:300],
                   'main_calls': len(r['calls']), 'main_totals': tot(r['calls']),
                   'dispatch_types': dict(dispatch_types), 'workflows': workflows_launched, 'skills': skills,
                   'markers': dict(markers), 'instr_has_vulyk': r['instr_has_vulyk'], 'instr_chars': r['instr_chars'],
                   'main_tools': dict(Counter(x[1] for x in r['tool_uses'])),
                   'main_edits': ne, 'main_edit_files': efiles, 'main_lines_add': add, 'main_lines_rem': rem,
                   'att_chars': dict(hooks), 'att_counts': dict(hookn),
                   'slug_events': [(e[0], e[1]) for e in events][:400],
                   'cost_state': {k: cs.get(k) for k in ('totalCostUSD', 'totalLinesAdded', 'totalLinesRemoved', 'totalDuration', 'totalAPIDuration', 'totalToolDuration', 'modelUsage')} if cs else None,
                   'n_subagents': len(agents_summary)}
            # active time: merged ts, gaps capped at 15 min, gap attributed to later event's slug
            all_ts = [x for x in all_ts if x[0] is not None]
            all_ts.sort(key=lambda x: x[0])
            act = 0.0; act_slug = Counter()
            for i in range(1, len(all_ts)):
                g = all_ts[i][0] - all_ts[i - 1][0]
                if 0 < g <= 900:
                    act += g
                    s = all_ts[i][1]
                    if s == 'main':
                        s = slug_at(all_ts[i][0])
                    act_slug[s or '-'] += g
            rec['active_s'] = act
            rec['active_by_slug'] = dict(act_slug)
            # queen tokens by slug
            qs = defaultdict(Counter)
            for c in r['calls']:
                for k in ('in', 'cw5', 'cw1h', 'cr', 'out'):
                    qs[c['slug'] or '-'][k] += c[k]
            rec['queen_by_slug'] = {k: dict(v) for k, v in qs.items()}
            fs.write(json.dumps(rec) + '\n')
        fs.flush(); fa.flush()
        print(f'{p} done {time.time()-t0:.0f}s', flush=True)


if __name__ == '__main__':
    main()
