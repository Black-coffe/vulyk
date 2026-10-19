#!/usr/bin/env bash
# PreToolUse hook: before a tool touches a place a `text` defect card names in `paths:`, put that
# card's Never (✗), How-to (→) and Allowed (✓) lines in front of the agent. Cards are read by
# defects_lib.py beside this file. Contract: docs/specs/rules-tree/plan.md ## Contracts, Delivery.
#
#   defects-inject.sh          PreToolUse: globs match file_path / notebook_path (Edit family) or the Bash
#                              line's path tokens, `cmd:` the Bash line, `tool:` tool_name (any tool)
#   defects-inject.sh reset    SessionStart: source compact|clear forgets what this session was shown
#
# At most $DEFECTS_INJECT_LINES (12) lines after the header, narrowest scope first, then the freshest
# dated line; the rest fold into one `+N cards: <ref>, ...` line. An Allowed-only card whose
# `exception:` does not name a Never card matched here gets one `✓ withheld:` line instead; beside an
# unlinked How-to card its lines are shown marked `(the How-to of <ref> comes first)`.
# Cards declaring block with a check: are not injected (the gate runs it, fixtures or not), revoked cards never are. Each card is shown once
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

sys.path.insert(0, os.path.dirname(os.path.abspath(sys.argv[0])))
from defects_lib import fixpath, fm_scalar, load_cards, parse_scope, scope_matches, specificity, allowed_date

EDIT_FAMILY = ('Edit', 'Write', 'MultiEdit', 'NotebookEdit')


def injected_as(card):
    # A card that DECLARES block with a check: is not injected, fixtures or not - the gate
    # (defects-check.sh <arg>) runs that check (0.19.1). Fixtures decide debt, not this.
    # Anything else not revoked - text, block without a check, an unknown status - is text.
    if card.status == 'revoked':
        return 'revoked'
    if card.status == 'block' and card.check:
        return 'block'
    return 'text'


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


def overlaps(a, b):
    # The gate's CONFLICT overlap: an identical entry, or one card's glob matches the other's glob as a path.
    for x in a.paths:
        for y in b.paths:
            if x == y or (parse_scope(x)[0] == parse_scope(y)[0] == 'glob'
                          and (scope_matches(x, '', y, '') or scope_matches(y, '', x, ''))):
                return True
    return False


def budget():
    try:
        return max(1, int(os.environ.get('DEFECTS_INJECT_LINES') or 12))
    except ValueError:
        return 12


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
    tool = data.get('tool_name') or ''
    if not isinstance(tool, str):
        return
    cmd, paths = '', []
    if tool == 'Bash':
        cmd = ti.get('command') or ''
        if not isinstance(cmd, str):
            return
        for t in re.split(r'[\s;|&<>()]+', cmd):
            t = t.strip('\'"`')
            for part in {t, t.rsplit('=', 1)[-1]}:
                part = rel(part.strip('\'"`'), root)
                if part:
                    paths.append(part)
    elif tool in EDIT_FAMILY:
        fp = ti.get('file_path') or ti.get('notebook_path') or ''
        if isinstance(fp, str) and fp:
            paths.append(rel(fp, root))
    # Any other tool has no path and no command line: only its `tool:` entries can match.
    if not paths and not cmd and not tool:
        return

    agent = str(data.get('agent_id') or '')
    try:
        with open(state, encoding='utf-8') as f:
            seen = set(f.read().split('\n'))
    except OSError:
        seen = set()

    hits, nevers, howtos = [], [], []
    for card in load_cards(d):
        kind = injected_as(card)
        if kind == 'revoked':
            continue
        spec = [specificity(g) for g in card.paths if scope_matches(g, tool, paths, cmd)]
        if not spec:
            continue
        if card.never:
            # Every live Never card on this target counts against an unlinked Allowed card (a How-to prohibits nothing),
            # also one already shown or one the gate runs: the prohibition wins when unlinked.
            nevers.append(card)
        elif card.howto:
            howtos.append(card)
        if kind == 'text' and agent + '\t' + card.ref not in seen:
            dates = [x for x in map(allowed_date, card.quotes + card.allowed) if x]
            hits.append((max(spec), max(dates) if dates else '', card))
    if not hits:
        return
    # Narrowest scope first, then the freshest dated line, then ref.
    hits.sort(key=lambda h: h[2].ref)
    hits.sort(key=lambda h: (h[0], h[1]), reverse=True)

    text = 'Defect classes for this target (docs/defects/, text cards - no check guards them):'
    room, shown, rest = budget(), [], []
    for _, _, card in hits:
        lines = [card.ref + ' — ' + (fm_scalar(card.fm.get('title', '')) or card.ref)]
        lines += ['✗ ' + x for x in card.never] + ['→ ' + x for x in card.howto]
        if card.allowed:
            clash = [n.ref for n in nevers if n.ref not in (card.ref, card.exception) and overlaps(card, n)]
            if clash and not (card.never or card.howto):
                lines.append('✓ withheld: ' + card.ref + ' conflicts with ' + clash[0] + ' (no exception:)')
            else:
                first = [h.ref for h in howtos if h.ref not in (card.ref, card.exception) and overlaps(card, h)]
                exc = ' (exception: ' + card.exception + ')' if card.exception else ''
                if first and not (card.never or card.howto):
                    exc += ' (the How-to of ' + first[0] + ' comes first)'
                lines += ['✓ ' + x + exc for x in card.allowed]
        if len(lines) == 1:
            lines.append('read docs/defects/' + card.path)
        if rest or len(lines) > room:
            if not shown and not rest:
                lines = lines[:room]  # the narrowest card is never folded away whole
            else:
                rest.append(card.ref)
                continue
        text += ''.join('\n' + x for x in lines)
        room -= len(lines)
        shown.append(card.ref)
    if rest:
        text += '\n+%d cards: %s' % (len(rest), ', '.join(rest))
    shown += rest
    # Folded cards count as shown too: the agent has the refs, repeating them every call is noise.
    try:
        os.makedirs(os.path.dirname(state), exist_ok=True)
        with open(state, 'a', encoding='utf-8') as f:
            f.write(''.join(agent + '\t' + r + '\n' for r in shown))
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
