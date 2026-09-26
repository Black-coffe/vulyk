#!/usr/bin/env python3
"""token-report.py - what a project really spent, per spec (ADR-013 D8).

  python scripts/token-report.py <project-dir> [--spec <slug>] [--since YYYY-MM-DD] [--json]
                                 [--projects-root <dir>]

Reads the Claude Code transcripts of <project-dir> under ~/.claude/projects/<encoded path>/
(every character of the absolute path that is not a letter or digit becomes '-', so
E:\\Projects\\vulyk -> E--Projects-vulyk): main sessions <id>.jsonl, their subagents
<id>/subagents/**/agent-*.jsonl (workflow agents included) and the Workflow run records
<id>/workflows/*.json; plus the project's council ledger memory/stats/council.jsonl.
Streams every file line by line, skips malformed lines, standard library only.

Counting - the method of docs/specs/token-audit/evidence/forensics.md section 0:
  * one API response is written as several lines sharing message.id: kept once, max of each field;
  * raw      = input + cache write + cache read + output;
  * weighted = input + 1.25 x write(5m) + 2 x write(1h) + 0.1 x read + output; a cache write
               without the 5m/1h split counts as 5m, and the report says so;
  * the Workflow's totalTokens is never used: it is the sum of each agent's final context size.
Attribution to a spec slug:
  * a workflow agent -> the run's args.spec;
  * another subagent -> the first docs/specs/<slug> in its first prompt, else the slug its main
                        session held when it started;
  * a main session   -> the slug it named last (Skill/command args, Workflow args, Agent prompts,
                        edited paths, shell commands); calls before its first mention go to its
                        first slug; a session that names none is reported as (none).
Dispatches: one per subagent transcript, by agent type. Council rounds: unique (spec, round) in
the ledger. Active minutes: merged event timestamps, gaps over 15 minutes not counted. Dates UTC.
"""
import argparse
import bisect
import json
import os
import re
import sys
from collections import Counter
from datetime import datetime, timezone

SLUG_RE = re.compile(r'docs[/\\]+specs[/\\]+([A-Za-z0-9][A-Za-z0-9._-]*)')
SLUG_TOKEN = re.compile(r'^[A-Za-z0-9][A-Za-z0-9._-]*$')
CMD_RE = re.compile(r'<command-name>/?([\w:.-]+)</command-name>')
ARGS_RE = re.compile(r'<command-args>([^<]*)</command-args>')
SLUG_COMMANDS = {'vulyk-build', 'vulyk-ship', 'vulyk-review', 'vulyk-resume'}
AGENT_TOOLS = {'Agent', 'Task'}
EDIT_TOOLS = {'Edit', 'Write', 'MultiEdit', 'NotebookEdit'}
SHELL_TOOLS = {'Bash', 'PowerShell'}
GAP_S = 15 * 60
NONE = '(none)'
# A call is [ts, input, cache write, write 5m, write 1h, cache read, output, no-split flag, sidechain].
IN, CW, CW5, CW1H, CR, OUT, NOSPLIT, SIDE = range(1, 9)
NOTE = ("weighted ≈ cost at API cache prices: input + 1.25×write(5m) + 2×write(1h) + 0.1×read + output.",
        "The Workflow's printed totalTokens is not spend: it adds up each agent's final context, "
        "not the tokens processed.")


def num(x):
    return x if isinstance(x, (int, float)) and not isinstance(x, bool) else 0


def parse_ts(s):
    if not isinstance(s, str):
        return None
    try:
        t = datetime.fromisoformat(s.replace('Z', '+00:00'))
    except ValueError:
        return None
    if t.tzinfo is None:
        t = t.replace(tzinfo=timezone.utc)
    return t.timestamp()


def slugs_in(text):
    out = []
    if isinstance(text, str):
        for m in SLUG_RE.finditer(text):
            s = m.group(1).rstrip('.')
            if s and not s.endswith(('.md', '.json', '.jsonl')) and s not in out:
                out.append(s)
    return out


def slug_of(spec):
    """'docs/specs/x', 'docs/specs/x/' or 'x' -> 'x'."""
    if not isinstance(spec, str):
        return None
    found = slugs_in(spec)
    if found:
        return found[0]
    parts = [p for p in re.split(r'[/\\]+', spec.strip()) if p]
    return parts[-1] if parts and SLUG_TOKEN.match(parts[-1]) else None


def slug_arg(args):
    """The slug a /vulyk-build-style argument string names: a docs/specs path or a bare first word."""
    if not isinstance(args, str):
        return None
    found = slugs_in(args)
    if found:
        return found[0]
    words = args.split()
    return words[0] if words and SLUG_TOKEN.match(words[0]) else None


def slug_named_by(name, inp):
    if not isinstance(inp, dict):
        return None
    if name == 'Workflow':
        a = inp.get('args')
        if isinstance(a, str):
            try:
                a = json.loads(a)
            except ValueError:
                a = None
        return slug_of(a.get('spec')) if isinstance(a, dict) else None
    if name == 'Skill':
        return slug_arg(inp.get('args')) if str(inp.get('skill') or '').split(':')[-1] in SLUG_COMMANDS else None
    if name in AGENT_TOOLS:
        found = slugs_in(inp.get('prompt'))
    elif name in EDIT_TOOLS:
        found = slugs_in(inp.get('file_path') or inp.get('notebook_path'))
    elif name in SHELL_TOOLS:
        found = slugs_in(inp.get('command'))
    else:
        return None
    return found[0] if found else None


def slug_from_command(text):
    m = CMD_RE.search(text)
    if not m or m.group(1).split(':')[-1] not in SLUG_COMMANDS:
        return None
    a = ARGS_RE.search(text)
    return slug_arg(a.group(1)) if a else None


def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return '\n'.join(b['text'] for b in content
                         if isinstance(b, dict) and b.get('type') == 'text' and isinstance(b.get('text'), str))
    return ''


def usage_of(u):
    cw = num(u.get('cache_creation_input_tokens'))
    cc = u.get('cache_creation')
    split = isinstance(cc, dict) and ('ephemeral_5m_input_tokens' in cc or 'ephemeral_1h_input_tokens' in cc)
    if split:
        c1h = num(cc.get('ephemeral_1h_input_tokens'))
        c5 = cc.get('ephemeral_5m_input_tokens')
        c5 = num(c5) if c5 is not None else max(cw - c1h, 0)
    else:
        c5, c1h = cw, 0
    return [num(u.get('input_tokens')), cw, c5, c1h, num(u.get('cache_read_input_tokens')),
            num(u.get('output_tokens')), 0 if (split or not cw) else 1]


def read_transcript(path, want_events):
    """Stream one transcript. Returns (calls by message id, line timestamps, slug events, first prompt,
    attributionAgent). Slug events are collected only for a main session."""
    calls, tss, events = {}, [], []
    first_prompt, agent = None, None
    try:
        f = open(path, encoding='utf-8', errors='replace')
    except OSError:
        return calls, tss, events, first_prompt, agent
    with f:
        for n, line in enumerate(f):
            try:
                d = json.loads(line)
            except ValueError:
                continue
            if not isinstance(d, dict):
                continue
            t = d.get('type')
            ts = parse_ts(d.get('timestamp'))
            if ts is not None:
                tss.append(ts)
            m = d.get('message')
            if not isinstance(m, dict):
                continue
            if t == 'assistant':
                if agent is None and isinstance(d.get('attributionAgent'), str):
                    agent = d['attributionAgent']
                u = m.get('usage')
                if isinstance(u, dict) and m.get('model') != '<synthetic>':
                    mid = m.get('id') or d.get('requestId') or d.get('uuid') or '%s:%d' % (path, n)
                    v = usage_of(u)
                    c = calls.get(mid)
                    if c is None:
                        calls[mid] = [ts] + v + [bool(d.get('isSidechain'))]
                    else:
                        for i, x in enumerate(v, 1):
                            if x > c[i]:
                                c[i] = x
                        if c[0] is None:
                            c[0] = ts
                if want_events and ts is not None and isinstance(m.get('content'), list):
                    for b in m['content']:
                        if isinstance(b, dict) and b.get('type') == 'tool_use':
                            s = slug_named_by(b.get('name'), b.get('input'))
                            if s:
                                events.append((ts, s))
            elif t == 'user':
                txt = text_of(m.get('content'))
                if first_prompt is None and txt and not d.get('isMeta'):
                    first_prompt = txt
                if want_events and ts is not None and '<command-name>' in txt:
                    s = slug_from_command(txt)
                    if s:
                        events.append((ts, s))
    return calls, tss, events, first_prompt, agent


def load_json(path):
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            d = json.load(f)
    except (OSError, ValueError):
        return None
    return d if isinstance(d, dict) else None


def listdir(path):
    try:
        return sorted(os.listdir(path))
    except OSError:
        return []


def mtime(path):
    try:
        return os.path.getmtime(path)
    except OSError:
        return 0


class Acc:
    """Spend of one spec: main-session and subagent buckets of [input, write, write5m, write1h, read,
    output, calls], sessions, dispatches by agent type, event timestamps."""
    __slots__ = ('main', 'sub', 'sessions', 'dispatches', 'ts', 'nosplit')

    def __init__(self):
        self.main, self.sub = [0] * 7, [0] * 7
        self.sessions, self.dispatches, self.ts, self.nosplit = set(), Counter(), [], 0

    def merge(self, o):
        for i in range(7):
            self.main[i] += o.main[i]
            self.sub[i] += o.sub[i]
        self.sessions |= o.sessions
        self.dispatches.update(o.dispatches)
        self.ts.extend(o.ts)
        self.nosplit += o.nosplit


def collect(tdir, since_ts):
    accs, seen = {}, set()
    scanned = [0, 0]  # main sessions, subagent transcripts

    def acc(slug):
        a = accs.get(slug)
        if a is None:
            a = accs[slug] = Acc()
        return a

    def keep(ts):
        return since_ts is None or (ts is not None and ts >= since_ts)

    def add_calls(calls, slug_for, sid, is_sub):
        for mid, c in calls.items():
            if mid in seen:  # the same response copied into another file (resume, fork)
                continue
            seen.add(mid)
            if not keep(c[0]):
                continue
            a = acc(slug_for(c[0]))
            bucket = a.sub if (is_sub or c[SIDE]) else a.main
            for i, k in enumerate((IN, CW, CW5, CW1H, CR, OUT)):
                bucket[i] += c[k]
            bucket[6] += 1
            a.nosplit += c[NOSPLIT]
            a.sessions.add(sid)

    def add_events(tss, slug_for):
        for ts in tss:
            if keep(ts):
                acc(slug_for(ts)).ts.append(ts)

    names = listdir(tdir)
    sids = {n[:-6] for n in names if n.endswith('.jsonl') and os.path.isfile(os.path.join(tdir, n))}
    sids |= {n for n in names if os.path.isdir(os.path.join(tdir, n, 'subagents'))}
    for sid in sorted(sids):
        main_path = os.path.join(tdir, sid + '.jsonl')
        sdir = os.path.join(tdir, sid)
        sub_files = []
        for root, dirs, files in os.walk(os.path.join(sdir, 'subagents')):
            dirs.sort()
            sub_files.extend(os.path.join(root, fn) for fn in sorted(files)
                             if fn.startswith('agent-') and fn.endswith('.jsonl'))
        run_files = [os.path.join(sdir, 'workflows', fn) for fn in listdir(os.path.join(sdir, 'workflows'))
                     if fn.endswith('.json')]
        if since_ts is not None and max(mtime(p) for p in [main_path] + sub_files + run_files) < since_ts:
            continue  # nothing in this session was written after --since
        calls, tss, events, _, _ = read_transcript(main_path, True)
        scanned[0] += 1
        events.sort(key=lambda e: e[0])
        ev_ts = [e[0] for e in events]

        def slug_at(ts, events=events, ev_ts=ev_ts):
            if not events:
                return NONE
            if ts is None:
                return events[0][1]
            return events[max(bisect.bisect_right(ev_ts, ts) - 1, 0)][1]

        add_calls(calls, slug_at, sid, False)
        add_events(tss, slug_at)
        run_slug = {}
        for rf in run_files:
            w = load_json(rf)
            if w is None:
                continue
            a = w.get('args')
            if isinstance(a, str):
                try:
                    a = json.loads(a)
                except ValueError:
                    a = None
            s = slug_of(a.get('spec')) if isinstance(a, dict) else None
            if s:
                run_slug[str(w.get('runId') or os.path.basename(rf)[:-5])] = s
        for af in sub_files:
            a_calls, a_tss, _, prompt, attrib = read_transcript(af, False)
            scanned[1] += 1
            meta = load_json(af[:-6] + '.meta.json') or {}
            atype = meta.get('customAgentType') or meta.get('agentType') or attrib or 'unknown'
            rel = os.path.relpath(af, os.path.join(sdir, 'subagents')).replace('\\', '/').split('/')
            run = rel[1] if len(rel) > 2 and rel[0] == 'workflows' else None
            start = min(a_tss) if a_tss else None
            in_prompt = slugs_in(prompt)
            slug = run_slug.get(run) or (in_prompt[0] if in_prompt else None) or slug_at(start)
            add_calls(a_calls, lambda ts, s=slug: s, sid, True)
            add_events(a_tss, lambda ts, s=slug: s)
            if keep(start):
                a = acc(slug)
                a.dispatches[atype] += 1
                a.sessions.add(sid)
    return accs, scanned


def council_rounds(project, since_ts):
    rounds = {}
    try:
        f = open(os.path.join(project, 'memory', 'stats', 'council.jsonl'), encoding='utf-8', errors='replace')
    except OSError:
        return {}
    with f:
        for line in f:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            if not isinstance(d, dict) or d.get('round') is None:
                continue
            slug = slug_of(d.get('spec'))
            if not slug:
                continue
            if since_ts is not None:
                ts = parse_ts(d.get('ts'))
                if ts is None or ts < since_ts:
                    continue
            rounds.setdefault(slug, set()).add(str(d['round']))
    return {k: len(v) for k, v in rounds.items()}


def weighted(b):
    return b[0] + 1.25 * b[2] + 2 * b[3] + 0.1 * b[4] + b[5]


def raw(b):
    return b[0] + b[1] + b[4] + b[5]


def active_minutes(tss):
    tss = sorted(tss)
    return sum(g for g in (b - a for a, b in zip(tss, tss[1:])) if g <= GAP_S) / 60


def day(ts):
    return datetime.fromtimestamp(ts, timezone.utc).strftime('%Y-%m-%d') if ts is not None else None


def row(name, a, rounds):
    t = [a.main[i] + a.sub[i] for i in range(7)]
    r = raw(t)
    d = dict(sorted(a.dispatches.items(), key=lambda kv: (-kv[1], kv[0])))
    out = {'spec': name, 'sessions': len(a.sessions), 'api_calls': t[6], 'raw': r, 'weighted': round(weighted(t)),
           'input': t[0], 'cache_write': t[1], 'cache_write_5m': t[2], 'cache_write_1h': t[3], 'cache_read': t[4],
           'cache_read_share': round(t[4] / r, 4) if r else 0.0, 'output': t[5],
           'main': {'raw': raw(a.main), 'weighted': round(weighted(a.main)), 'api_calls': a.main[6]},
           'subagents': {'raw': raw(a.sub), 'weighted': round(weighted(a.sub)), 'api_calls': a.sub[6]},
           'dispatches': d, 'dispatch_count': sum(d.values()), 'rounds': rounds,
           'active_min': round(active_minutes(a.ts), 1),
           'first': day(min(a.ts)) if a.ts else None, 'last': day(max(a.ts)) if a.ts else None,
           'writes_without_split': a.nosplit}
    if name is None:
        del out['spec']
    return out


def report(project, tdir, since, since_ts, spec):
    accs, scanned = collect(tdir, since_ts)
    rounds = council_rounds(project, since_ts)
    rows, total = [], Acc()
    for slug in set(accs) | set(rounds):
        if spec is not None and slug != spec:
            continue
        a = accs.get(slug) or Acc()
        if not (a.main[6] or a.sub[6] or a.dispatches or rounds.get(slug)):
            continue  # a slug that was only named, with nothing spent on it
        rows.append(row(slug, a, rounds.get(slug, 0)))
        total.merge(a)
    rows.sort(key=lambda r: (-r['weighted'], -r['raw'], r['spec']))
    return {'project': project, 'since': since, 'transcripts': tdir,
            'scanned': {'sessions': scanned[0], 'subagent_transcripts': scanned[1]},
            'specs': rows, 'total': row(None, total, sum(r['rounds'] for r in rows)),
            'note': ' '.join(NOTE)}


def tok(n):
    n = float(n)
    if n >= 99.95e6:
        return '%.0fM' % (n / 1e6)
    if n >= 1e6:
        return '%.1fM' % (n / 1e6)
    if n >= 1e3:
        return '%.0fk' % (n / 1e3)
    return '%d' % n


def pct(a, b):
    return '%d%%' % round(100.0 * a / b) if b else '-'


def dates(r):
    if not r['first']:
        return '-'
    a, b = r['first'][5:], r['last'][5:]
    return a if a == b else a + '..' + b


def top_types(d, k=4):
    items = list(d.items())
    s = ', '.join('%s %d' % kv for kv in items[:k])
    return s + (', +%d types' % (len(items) - k) if len(items) > k else '')


def print_human(rep):
    head = ['spec', 'sess', 'raw', 'weighted', 'read%', 'output', 'main%', 'disp', 'rounds', 'act.min', 'dates',
            'top dispatches']
    lines = []
    for r in rep['specs'] + [dict(rep['total'], spec='TOTAL')]:
        lines.append([r['spec'], str(r['sessions']), tok(r['raw']), tok(r['weighted']),
                      pct(r['cache_read'], r['raw']), tok(r['output']),
                      pct(r['main']['weighted'], r['weighted']), str(r['dispatch_count']), str(r['rounds']),
                      '%.0f' % r['active_min'], dates(r), top_types(r['dispatches'])])
    w = [max(len(x[i]) for x in [head] + lines) for i in range(len(head))]

    def fmt(cells):
        out = [cells[0].ljust(w[0])] + [c.rjust(w[i]) for i, c in enumerate(cells[1:-2], 1)]
        out += [cells[-2].ljust(w[-2]), cells[-1]]
        return '  '.join(out).rstrip()

    since = ' since %s' % rep['since'] if rep['since'] else ''
    print('token-report: %s%s - %d sessions, %d subagent transcripts read' % (
        rep['project'], since, rep['scanned']['sessions'], rep['scanned']['subagent_transcripts']))
    print(fmt(head))
    for x in lines:
        print(fmt(x))
    for n in NOTE:
        print(n)
    ns = rep['total']['writes_without_split']
    if ns:
        print('cache writes without the 5m/1h split on %d API call(s): counted as 5m.' % ns)


def native_path(p):
    if os.name == 'nt':  # a Git Bash path such as /e/Projects/vulyk
        m = re.match(r'^/([A-Za-z])(/.*)?$', p)
        if m:
            p = m.group(1).upper() + ':' + (m.group(2) or '/')
    return os.path.abspath(os.path.expanduser(p))


def encode(path):
    return re.sub(r'[^A-Za-z0-9]', '-', path)


def find_transcripts(project, root):
    enc = encode(project)
    cand = os.path.join(root, enc)
    if os.path.isdir(cand):
        return cand
    for n in listdir(root):  # drive-letter or other case drift on a case-sensitive file system
        if n.lower() == enc.lower() and os.path.isdir(os.path.join(root, n)):
            return os.path.join(root, n)
    return None


def since_date(s):
    try:
        return datetime.strptime(s, '%Y-%m-%d').replace(tzinfo=timezone.utc)
    except ValueError:
        raise argparse.ArgumentTypeError('expected YYYY-MM-DD, got %r' % s)


def main(argv=None):
    ap = argparse.ArgumentParser(description='Tokens a project really spent, per spec (ADR-013 D8).')
    ap.add_argument('project', help='the project directory (the cwd its Claude Code sessions ran in)')
    ap.add_argument('--spec', help='report one spec slug (docs/specs/<slug> also accepted)')
    ap.add_argument('--since', type=since_date, help='count only what happened on or after this UTC date')
    ap.add_argument('--json', action='store_true', help='print one JSON object instead of the table')
    ap.add_argument('--projects-root', help='where the transcripts live (default ~/.claude/projects)')
    a = ap.parse_args(argv)
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except (AttributeError, ValueError):
        pass
    project = native_path(a.project)
    root = os.path.abspath(os.path.expanduser(a.projects_root or os.path.join('~', '.claude', 'projects')))
    tdir = find_transcripts(project, root)
    if tdir is None:
        print('token-report: no transcripts for %s - expected %s' % (project, os.path.join(root, encode(project))),
              file=sys.stderr)
        return 1
    spec = slug_of(a.spec) if a.spec else None
    if a.spec and not spec:
        print('token-report: not a spec slug: %r' % a.spec, file=sys.stderr)
        return 2
    rep = report(project, tdir, a.since.strftime('%Y-%m-%d') if a.since else None,
                 a.since.timestamp() if a.since else None, spec)
    if a.json:
        print(json.dumps(rep, indent=2))
    else:
        print_human(rep)
    return 0


if __name__ == '__main__':
    sys.exit(main())
