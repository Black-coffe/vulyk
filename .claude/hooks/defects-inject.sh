#!/usr/bin/env bash
# PreToolUse hook (matcher Edit|Write|MultiEdit|NotebookEdit|Bash): before a tool touches a place a
# `text` defect card names in `paths:`, put that card's "Never" lines in front of the agent.
# Contract: docs/specs/self-learning/contract.md §1 (card format, effective status) and §3.
#
#   defects-inject.sh          PreToolUse: match file_path / notebook_path / the Bash command line
#   defects-inject.sh reset    SessionStart: source compact|clear forgets what this session was shown
#
# Block cards are not injected (their check: speaks), revoked cards never are. Each card is shown once
# per session_id + agent_id; state: .claude/state/defects/inject-<session>.txt under the repo root
# ($CLAUDE_PROJECT_DIR, else the input's cwd).
#
# Never blocks: no python, no docs/defects/, bad JSON or any error -> silent exit 0.
# The Python half lives below the `exit 0`, inside a no-op heredoc; bash never runs it, python reads
# it back out of this file (one interpreter start, stdin passes straight through).
# stdin is read once so a non-working interpreter (the Windows Store `python3` alias exits 9009
# without running anything) falls through to the next one; 0 or 1 means python itself ran.
IN="$(cat)"
for PY in python3 python; do
  command -v "$PY" >/dev/null 2>&1 || continue
  printf '%s' "$IN" | "$PY" -S -c 'import sys;sys.argv=sys.argv[1:];p=sys.argv[0];s=open(p,encoding="utf-8").read();exec(compile(s.split("\n#<py>\n",1)[1].split("\nPYTHON\n",1)[0],p,"exec"))' \
    "${BASH_SOURCE[0]}" "$@" 2>/dev/null
  case $? in 0|1) exit 0 ;; esac
done
exit 0

: <<'PYTHON'
#<py>
import json, os, re, sys

BUDGET = 4000


# --- card parsing: kept identical to .claude/hooks/defect-intake.sh ---------------------------
def fixpath(p):
    # A Git Bash path (/e/Projects/x) handed to a native Windows python.
    if os.name == 'nt':
        m = re.match(r'^/([A-Za-z])(/.*)?$', p)
        if m:
            p = m.group(1) + ':' + (m.group(2) or '/')
    return p


def fm_scalar(v):
    v = re.sub(r'\s+#(\s.*)?$', '', v or '').strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in '"\'':
        v = v[1:-1]
    return v


def fm_list(v):
    # `[a, b, "c, d", 'e']` -> list; a bare scalar -> one item. In double quotes \\ and \" unescape.
    v = (v or '').strip()
    if not v.startswith('['):
        v = fm_scalar(v)
        return [v] if v else []
    items, i, n, cur = [], 1, len(v), ''
    while i < n:
        c = v[i]
        if c in '"\'' and not cur.strip():
            q, i, s = c, i + 1, ''
            while i < n and v[i] != q:
                if q == '"' and v[i] == '\\' and i + 1 < n and v[i + 1] in '\\"':
                    s += v[i + 1]
                    i += 2
                    continue
                s += v[i]
                i += 1
            items.append(s)
            i += 1
            while i < n and v[i] not in ',]':
                i += 1
            if i >= n or v[i] == ']':
                break
            i += 1
            cur = ''
            continue
        if c in ',]':
            items.append(cur.strip())
            cur = ''
            if c == ']':
                break
        else:
            cur += c
        i += 1
    items.append(cur.strip())
    return [x for x in items if x]


def load_cards(d):
    cards = []
    for name in sorted(os.listdir(d)):
        if not name.endswith('.md') or name.lower() == 'readme.md':
            continue
        try:
            with open(os.path.join(d, name), encoding='utf-8', errors='replace') as f:
                src = f.read()
        except OSError:
            continue
        src = src.lstrip('﻿').replace('\r\n', '\n').replace('\r', '\n')
        m = re.match(r'---[ \t]*\n(.*?)\n---[ \t]*(?:\n|$)', src, re.S)
        if not m:
            continue
        fm = {}
        for line in m.group(1).split('\n'):
            if not line.strip() or line[:1].isspace() or line.startswith('#'):
                continue
            k, sep, v = line.partition(':')
            if sep:
                fm[k.strip().lower()] = v.strip()
        cards.append((name[:-3], fm, src[m.end():]))
    return cards
# --- end of shared card parsing ---------------------------------------------------------------


def effective(fm, root):
    # §1: block only with a check: and >= 2 fixtures that exist; anything else not revoked is text.
    st = fm_scalar(fm.get('status', '')).lower()
    if st == 'revoked':
        return 'revoked'
    if st == 'block' and fm_scalar(fm.get('check', '')):
        fx = [f for f in fm_list(fm.get('fixtures', '')) if os.path.isfile(os.path.join(root, f))]
        if len(fx) >= 2:
            return 'block'
    return 'text'


def glob_rx(g):
    # fnmatch semantics (`*` crosses `/`), plus `**/` = any number of directories, zero included.
    out, i, n = '', 0, len(g)
    while i < n:
        if g.startswith('**/', i):
            out, i = out + '(?:.*/)?', i + 3
        elif g[i] == '*':
            while i < n and g[i] == '*':
                i += 1
            out += '.*'
        elif g[i] == '?':
            out, i = out + '.', i + 1
        elif g[i] == '[':
            j = g.find(']', i + 2)
            if j < 0:
                out, i = out + '\\[', i + 1
            else:
                body = g[i + 1:j]
                if body.startswith('!'):
                    body = '^' + body[1:]
                out, i = out + '[' + body.replace('\\', '\\\\') + ']', j + 1
        else:
            out, i = out + re.escape(g[i]), i + 1
    return re.compile(out + r'\Z', re.I if os.name == 'nt' else 0)


def rel(p, root):
    # A path as the cards write it: relative to the repo root, forward slashes.
    p = fixpath((p or '').strip())
    if not p:
        return ''
    if os.path.isabs(p):
        a = os.path.abspath(p)
        try:
            r = os.path.relpath(a, os.path.abspath(root))
            p = a if r.startswith('..') else r
        except ValueError:
            p = a
    p = p.replace('\\', '/')
    while p.startswith('./'):
        p = p[2:]
    return p


def glob_hits(g, paths):
    # A glob without `/` also matches the basename: `EDIT_*.json` finds edits/EDIT_3.json.
    rx = glob_rx(g)
    for p in paths:
        if rx.match(p) or ('/' not in g and rx.match(p.rsplit('/', 1)[-1])):
            return True
    return False


def never_lines(body):
    m = re.search(r'^##[ \t]+(?:Never|Нельзя)\b[^\n]*\n(.*?)(?=^##[ \t]|\Z)', body, re.S | re.M)
    out = []
    for line in (m.group(1).split('\n') if m else []):
        b = re.match(r'^[-*][ \t]+(.*\S)', line)
        if b:
            out.append(b.group(1))
        elif out and line[:1].isspace() and line.strip():
            out[-1] += ' ' + line.strip()
    return out


def main():
    data = json.loads(sys.stdin.buffer.read().decode('utf-8', 'replace'))
    if not isinstance(data, dict):
        return
    root = fixpath(os.environ.get('CLAUDE_PROJECT_DIR') or data.get('cwd') or os.getcwd())
    sid = re.sub(r'[^A-Za-z0-9_.-]', '_', str(data.get('session_id') or 'nosession'))[:120]
    state = os.path.join(root, '.claude', 'state', 'defects', 'inject-' + sid + '.txt')
    if sys.argv[1:2] == ['reset']:
        if data.get('source') in ('compact', 'clear'):
            try:
                os.remove(state)
            except OSError:
                pass
        elif data.get('source') == 'startup':
            # One state file per session would pile up forever; a new session prunes week-old ones.
            try:
                import time
                sd = os.path.dirname(state)
                for f in os.listdir(sd):
                    fp = os.path.join(sd, f)
                    if f.startswith('inject-') and time.time() - os.path.getmtime(fp) > 7 * 86400:
                        os.remove(fp)
            except OSError:
                pass
        return
    d = os.path.join(root, 'docs', 'defects')
    if not os.path.isdir(d):
        return
    ti = data.get('tool_input') or {}
    if not isinstance(ti, dict):
        return
    cmd, paths = '', []
    if data.get('tool_name') == 'Bash':
        cmd = ti.get('command') or ''
        if not isinstance(cmd, str):
            return
        for t in re.split(r'[\s;|&<>()]+', cmd):
            t = t.strip('\'"`')
            for part in {t, t.rsplit('=', 1)[-1]}:
                part = rel(part.strip('\'"`'), root)
                if part:
                    paths.append(part)
    else:
        fp = ti.get('file_path') or ti.get('notebook_path') or ''
        if isinstance(fp, str) and fp:
            paths.append(rel(fp, root))
    if not paths and not cmd:
        return

    agent = str(data.get('agent_id') or '')
    try:
        with open(state, encoding='utf-8') as f:
            seen = set(f.read().split('\n'))
    except OSError:
        seen = set()

    hits = []
    for cid, fm, body in load_cards(d):
        if agent + '\t' + cid in seen or effective(fm, root) != 'text':
            continue
        for g in fm_list(fm.get('paths', '')):
            if g.startswith('cmd:'):
                try:
                    ok = bool(cmd) and re.search(g[4:], cmd) is not None
                except re.error:
                    ok = False
            else:
                ok = glob_hits(g, paths)
            if ok:
                hits.append((cid, fm_scalar(fm.get('title', '')), never_lines(body)))
                break
    if not hits:
        return

    text = 'Defect classes for this target (docs/defects/, text cards - no check guards them):'
    rest = []
    for cid, title, nev in hits:
        block = '\n' + cid + ' — ' + (title or cid)
        if nev:
            block += ''.join('\n✗ ' + x for x in nev)
        else:
            block += '\n(no Never lines - read docs/defects/' + cid + '.md)'
        if rest or len(text) + len(block) > BUDGET:
            rest.append('docs/defects/' + cid + '.md')
        else:
            text += block
    if rest:
        text += '\nAlso matched, not shown (budget) - read before editing: ' + ', '.join(rest)
    # Listed-only cards count as shown too: the agent has the path, repeating it every call is noise.
    try:
        os.makedirs(os.path.dirname(state), exist_ok=True)
        with open(state, 'a', encoding='utf-8') as f:
            f.write(''.join(agent + '\t' + h[0] + '\n' for h in hits))
    except OSError:
        pass
    sys.stdout.write(json.dumps({'hookSpecificOutput': {
        'hookEventName': 'PreToolUse', 'additionalContext': text}}))


try:
    main()
except Exception:
    pass
sys.exit(0)
PYTHON
