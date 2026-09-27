#!/usr/bin/env bash
# UserPromptSubmit hook: an owner remark that looks like a correction (a timecode, a "again / I said"
# word, or a defect card's `keys:`) gets one reminder to file the verbatim quote in docs/defects/.
# Contract: docs/specs/self-learning/contract.md §1 (card format) and §3 (this hook).
#
# Only the human text is read: <task-notification>, <system-reminder>, <cross-session-message>,
# <pasted_content> blocks and ``` / ~~~ fences are cut out first, so a timecode inside a pasted log
# or a harness notice is not an owner correction.
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


# --- card parsing: kept identical to .claude/hooks/defects-inject.sh ----------------------------
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


BLOCKS = [
    r'<task-notification\b[^>]*>.*?(?:</task-notification\s*>|\Z)',
    r'<system-reminder\b[^>]*>.*?(?:</system-reminder\s*>|\Z)',
    r'<cross-session-message\b[^>]*/>',
    r'<cross-session-message\b[^>]*>.*?(?:</cross-session-message\b[^>]*>|\Z)',
    r'<pasted_content\b[^>]*/>',
    r'<pasted_content\b[^>]*>.*?(?:</pasted_content\b[^>]*>|\Z)',
    r'```.*?(?:```|\Z)',
    r'~~~.*?(?:~~~|\Z)',
]
# Stems match at a word start ("переделай" also takes "переделайте"); whole phrases need both edges.
STEMS = ['опять', 'снова', 'я же говорил', 'я же казав', 'знову', 'переделай', 'переделать', 'обрезал']
WORDS = ['не так', 'again', 'i said', 'i told you', 'why did you', 'not what i asked']
LEXICON = re.compile(r'(?<!\w)(?:' + '|'.join(map(re.escape, STEMS)) + r')'
                     r'|(?<!\w)(?:' + '|'.join(map(re.escape, WORDS)) + r')(?!\w)')
TIMECODE = re.compile(r'\b\d{1,2}:\d{2}\b')


def main():
    raw = sys.stdin.buffer.read().decode('utf-8', 'replace')
    data = json.loads(raw)
    if not isinstance(data, dict):
        return
    prompt = data.get('prompt')
    if not isinstance(prompt, str) or not prompt.strip():
        return
    root = fixpath(os.environ.get('CLAUDE_PROJECT_DIR') or data.get('cwd') or os.getcwd())
    d = os.path.join(root, 'docs', 'defects')
    if not os.path.isdir(d):
        return
    text = prompt
    for pat in BLOCKS:
        text = re.sub(pat, ' ', text, flags=re.S | re.I)
    low = text.lower()

    why = []
    tc = TIMECODE.search(text)
    if tc:
        why.append('timecode ' + tc.group(0))
    lx = LEXICON.search(low)
    if lx:
        why.append('word "' + lx.group(0) + '"')
    ids = []
    for cid, fm, _ in load_cards(d):
        if fm_scalar(fm.get('status', '')).lower() == 'revoked':
            continue
        for k in fm_list(fm.get('keys', '')):
            k = k.strip().lower()
            if k and k in low:
                ids.append(cid)
                break
    if ids:
        why.append('card keys')
    if not why:
        return
    msg = ('Looks like an owner correction (' + ', '.join(why) + '). Matched classes: '
           + (', '.join(ids) if ids else 'none') + '. Add the verbatim quote (date · material · place'
           ' — «words») to the matching card in docs/defects/, or open a new card. If code can check'
           ' the class, give it a failing `check:` with the original case and a neighbour-form fixture'
           ' in this same work (a Tier 3-4 story that names the file → the next repair story).')
    sys.stdout.write(json.dumps({'hookSpecificOutput': {
        'hookEventName': 'UserPromptSubmit', 'additionalContext': msg}}))


try:
    main()
except Exception:
    pass
sys.exit(0)
PYTHON
