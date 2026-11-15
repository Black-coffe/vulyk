#!/usr/bin/env bash
# PreToolUse hook (matcher Bash|PowerShell|Edit|Write|MultiEdit): only the owner's own words record his
# acceptance, a plan's approval or a straight-through `--go` (plan.md `## Contracts` O1 of audit-fixes-1113,
# card docs/defects/owner-words-by-builder.md).
#
# Guarded calls:
#   - a command running `human-check.sh <spec> ACCEPTED|REJECTED [note] [--commit]` (release acceptance; the
#     `--commit` word is no part of the spec or the note);
#   - a command running `cycle.sh briefed <spec> ... --go`;
#   - an Edit, MultiEdit, Write or shell command that adds or changes a `**Approved:**` or `**Checked:**` line
#     of a `docs/specs/<slug>/plan.md` (a line still holding the template placeholder `<...>` is no record),
#     and one that adds an ACCEPTED or REJECTED row to `memory/stats/human.jsonl`: any shell command naming
#     `human.jsonl` beside the word ACCEPTED or REJECTED counts as one, a `git add` / `git commit` of the record
#     included, so `human-check.sh ... --commit` commits its own plan.md line and row. Left open on purpose: a
#     record name the command never spells (built from quotes, globs, braces or variables, a script file that
#     writes it) and a verdict word it never spells; the hook reads the text it is given. An Edit or MultiEdit is
#     judged on the file as it stands after it, so one that replaces only the text after the marker counts;
#   - a shell command that may rewrite a plan.md holding such a line without spelling the marker (a redirect
#     into it; tee, cp, mv, a script interpreter; sed or awk -i) and that names it by its `docs/specs/<slug>/plan.md`
#     path, also inside a word that holds a whole command (`bash -c`, a heredoc, a pipe or a here-string with the
#     path spelled): the hook cannot read the line it leaves, so it is denied to everyone, with the Edit tool named
#     as the way.
# A subagent (the input carries agent_id) is denied every guarded call. The main session passes only under the
# quote rule, read from the session transcript (`transcript_path`); whitespace runs are collapsed on both sides
# and a quote is a whole owner message, a whole line of it, or a whole AskUserQuestion answer, never a piece
# cut out of a line:
#   - `**Approved:**`: the line quotes the owner's latest message (a prompt or an answer), written after the
#     spec's `vulyk(<slug>): plan` commit, at any length;
#   - ACCEPTED / REJECTED and `**Checked:**`: the note quotes the answer to a one-question AskUserQuestion
#     whose question names the slug, or the owner's next prompt after that question, written after the spec's
#     latest verdict (memory/stats council.jsonl and human.jsonl), with 8+ letters or digits unless the
#     answer is a picked option;
#   - `briefed --go`: an owner prompt of this session carries `--go`.
# An owner prompt is a transcript entry of type `user` with origin.kind `human`, not isMeta, not a sidechain,
# not a compaction summary, holding text and no tool_result; a slash command counts by its <command-args>.
# Cut from it before matching: <task-notification>, <system-reminder>, <cross-session-message> and
# <pasted_content> blocks, and a side-agent note with its `>` lines. An AskUserQuestion answer is the
# `toolUseResult.answers` value of the tool_result for an AskUserQuestion tool_use of the main thread.
# Not judged, on purpose: whether the words mean yes (no word list), and who wrote the transcript file itself
# (the session can write that file); an owner who types or dictates text an agent wrote counts as the owner.
# Left open by the plan.md rewrite check, on purpose (it reads the path as the command spells it and does not follow
# the shell): a plan named without its `docs/specs/<slug>/` path (a bare `plan.md` after a `cd`, or from a cwd inside
# the spec folder), a glob (`docs/specs/*/plan.md`), a variable or a substitution; a writer outside its list (ed, ex,
# patch, rsync, ln, a git verb that writes the tree); command text a shell reads from a file (a script, `cat cmds |
# bash`) or code an interpreter runs from one; and, with no Python, every shell rewrite (the fallback denies only a
# command that spells a marker beside plan.md, and every Edit, MultiEdit or Write of a plan.md).
# No Python, or a transcript the hook cannot read: a guarded call is denied with a message naming the cause;
# without Python every Edit, MultiEdit or Write of a plan.md counts as one.
# The owner can always run the command in his own terminal.
# `--check <file>` (the card's check): reads hook input from <file>; a `transcript` field (a list of entries)
# stands in for the file. Exit 1 on a deny (the reason on stdout), 0 otherwise, also for a file that is no
# hook input.
# The Python half lives below the `exit`, inside a no-op heredoc, as in git-guard.sh.
if [ "${1:-}" = "--check" ]; then
  [ -f "${2:-}" ] || exit 0
  IFS= read -r -d '' IN < "$2"
else
  IFS= read -r -d '' IN   # a builtin: an unrelated call starts no process
fi
case "$IN" in *human-check*|*briefed*|*Approved:*|*Checked:*|*human.jsonl*|*plan.md*) ;; *) exit 0 ;; esac
case "$IN" in *'"tool_name"'*) ;; *) exit 0 ;; esac
for PY in ${VULYK_PY:+"$VULYK_PY"} python3 python py; do   # lib.sh's order (vulyk_python)
  command -v "$PY" >/dev/null 2>&1 || continue
  # only exit 0 means the Python half ran; the trailing `.` keeps its output whole through $( )
  OUT="$(printf '%s' "$IN" | "$PY" -S -c 'import sys;sys.argv=sys.argv[1:];p=sys.argv[0];s=open(p,encoding="utf-8").read();exec(compile(s.split("\n#<py>\n",1)[1].split("\nPYTHON\n",1)[0],p,"exec"))' \
    "${BASH_SOURCE[0]}" "$@" 2>/dev/null && printf .)" || continue
  OUT="${OUT%.}"
  [ -n "$OUT" ] || exit 0
  printf '%s' "$OUT"
  [ "${1:-}" = "--check" ] && exit 1
  exit 0
done
# No Python answered: deny what may be a guarded call, let the rest through. Only a JSON object is hook input.
LEAD="${IN%%[![:space:]]*}"
case "${IN#"$LEAD"}" in '{'*) ;; *) exit 0 ;; esac
GUARDED=''
case "$IN" in *human-check*ACCEPTED*|*human-check*REJECTED*|*briefed*--go*|*human.jsonl*) GUARDED=1 ;; esac
case "$IN" in *Approved:*plan.md*|*Checked:*plan.md*|*plan.md*Approved:*|*plan.md*Checked:*) GUARDED=1 ;; esac
# an Edit, MultiEdit or Write of a plan.md may change a record line without spelling its marker
RE='"file_path"[[:space:]]*:[[:space:]]*"[^"]*plan\.md"'
[[ $IN =~ $RE ]] && GUARDED=1
[ -n "$GUARDED" ] || exit 0
printf '%s\n' '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "VULYK owner guard: no Python 3 answered ($VULYK_PY, python3, python, py), so this hook cannot read the transcript to see whether the owner said these words. A call that may record his acceptance, a plan approval or --go is refused. Install Python 3 or set VULYK_PY, or the owner runs the command in his own terminal."}}'
[ "${1:-}" = "--check" ] && exit 1
exit 0

: <<'PYTHON'
#<py>
import calendar, json, os, re, shlex, subprocess, sys

CHECK = len(sys.argv) > 1 and sys.argv[1] == '--check'
SEP = {';', '&&', '||', '|', '&', '\n', '(', ')', '{', '}'}
GUARDED = False

SUBAGENT = ('VULYK owner guard: a subagent cannot record an acceptance. `human-check.sh ACCEPTED|REJECTED`, '
            '`cycle.sh briefed --go` and the **Approved:** / **Checked:** lines of a plan.md record the owner\'s '
            'own words, and only the main session, quoting him, may write them. Put what you would record under '
            '## Findings and return it.')
OWNER_CAN = (' The owner can also run the command in his own terminal.')

# Injected text inside an owner prompt: model or tool text, never his words (as defect-intake.sh cuts it).
CUTS = [re.compile(p, re.S | re.I) for p in (
    r'<task-notification\b[^>]*>.*?(?:</task-notification\s*>|\Z)',
    r'<system-reminder\b[^>]*>.*?(?:</system-reminder\s*>|\Z)',
    r'<cross-session-message\b[^>]*>.*?(?:</cross-session-message\s*>|\Z)',
    r'<pasted_content\b[^>]*?(?:/>|>.*?(?:</pasted_content\s*>|\Z))',
)]
SIDE_NOTE = re.compile(r'(?:^|(?<=>))[ \t]*here is a note offered by a side agent\b.*?(?=\n[ \t]*\n|</|\Z)'
                       r'(?:\n[ \t]*(?:>[^\n]*)?(?=\n|\Z))*', re.S | re.I | re.M)
COMMAND_ARGS = re.compile(r'<command-args>(.*?)</command-args>', re.S)
MARKER = re.compile(r'^\s*\*\*(Approved|Checked):\*\*(.*)$')
PLAN = re.compile(r'(?:^|[/\\])docs[/\\]specs[/\\]([^/\\]+)[/\\]plan\.md$')


def deny(reason):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                             "permissionDecision": "deny",
                                             "permissionDecisionReason": reason}}))
    sys.exit(0)


def norm(s):
    return re.sub(r'\s+', ' ', s or '').strip()


def alnum(s):
    return sum(1 for ch in s if ch.isalnum())


def quotes(unit, note):
    """True when the whole unit stands in the note, not glued to a letter or digit on either side."""
    u, n = norm(unit), norm(note)
    if not u:
        return False
    i = n.find(u)
    while i >= 0:
        before = n[i - 1] if i > 0 else ''
        after = n[i + len(u)] if i + len(u) < len(n) else ''
        if not ((u[0].isalnum() and before.isalnum()) or (u[-1].isalnum() and after.isalnum())):
            return True
        i = n.find(u, i + 1)
    return False


def epoch(ts):
    """Seconds since the epoch for an ISO-8601 UTC stamp (2026-11-13T10:00:00.123Z), else None."""
    m = re.match(r'^(\d{4})-(\d\d)-(\d\d)[T ](\d\d):(\d\d):(\d\d)(?:[.,](\d+))?(Z|[+-]\d\d:?\d\d)?$', str(ts or '').strip())
    if not m:
        return None
    y, mo, d, h, mi, s = (int(m.group(k)) for k in range(1, 7))
    t = calendar.timegm((y, mo, d, h, mi, s, 0, 0, 0)) + (float('0.' + m.group(7)) if m.group(7) else 0.0)
    z = m.group(8)
    if z and z != 'Z':
        sign = -1 if z[0] == '+' else 1
        z = z[1:].replace(':', '')
        t += sign * (int(z[:2]) * 3600 + int(z[2:]) * 60)
    return t


# --- the transcript --------------------------------------------------------------------------------

def load_transcript(data):
    """A list of entries, or a reason string when it cannot be read."""
    if CHECK and isinstance(data.get('transcript'), list):
        return [e for e in data['transcript'] if isinstance(e, dict)]
    path = data.get('transcript_path')
    if not isinstance(path, str) or not path:
        return 'the hook input names no transcript_path'
    try:
        with open(os.path.expanduser(path), 'rb') as f:
            raw = f.read().decode('utf-8', 'replace')
    except OSError as e:
        return 'the transcript %s cannot be read (%s)' % (path, e.__class__.__name__)
    out = []
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            e = json.loads(line)
        except ValueError:
            continue
        if isinstance(e, dict):
            out.append(e)
    return out


def owner_text(entry):
    """The owner's own words in a prompt entry, else None (not an owner prompt)."""
    if entry.get('type') != 'user' or entry.get('isMeta') or entry.get('isSidechain') \
            or entry.get('isCompactSummary') or entry.get('isVisibleInTranscriptOnly'):
        return None
    origin = entry.get('origin')
    if not isinstance(origin, dict) or origin.get('kind') != 'human':
        return None
    msg = entry.get('message')
    content = msg.get('content') if isinstance(msg, dict) else None
    if isinstance(content, str):
        text = content
    elif isinstance(content, list):
        if any(isinstance(x, dict) and x.get('type') == 'tool_result' for x in content):
            return None
        text = '\n'.join(x.get('text', '') for x in content if isinstance(x, dict) and x.get('type') == 'text')
    else:
        return None
    if '<command-name>' in text or '<command-message>' in text:
        text = '\n'.join(COMMAND_ARGS.findall(text))
    for c in CUTS:
        text = c.sub('\n', text)
    text = SIDE_NOTE.sub('\n', text)
    return text


def units(text):
    """The whole message and each of its lines, collapsed; empty ones dropped."""
    out = [norm(text)] + [norm(l) for l in text.split('\n')]
    seen, res = set(), []
    for u in out:
        if u and u not in seen:
            seen.add(u)
            res.append(u)
    return res


def events(entries):
    """The session's owner events in file order: ('prompt', ts, text) and ('answer', ts, answer, question,
    picked, nquestions), plus ('ask', ts, question, nquestions) where an AskUserQuestion was put."""
    asks, out = {}, []
    for e in entries:
        if e.get('isSidechain'):
            continue
        ts = epoch(e.get('timestamp'))
        msg = e.get('message') if isinstance(e.get('message'), dict) else {}
        content = msg.get('content')
        if e.get('type') == 'assistant' and isinstance(content, list):
            for x in content:
                if isinstance(x, dict) and x.get('type') == 'tool_use' and x.get('name') == 'AskUserQuestion':
                    qs = (x.get('input') or {}).get('questions') or []
                    qs = [q for q in qs if isinstance(q, dict)]
                    asks[x.get('id')] = qs
                    out.append(('ask', ts, ' '.join(str(q.get('question') or '') for q in qs), len(qs)))
            continue
        if e.get('type') == 'user' and isinstance(content, list) and \
                any(isinstance(x, dict) and x.get('type') == 'tool_result' for x in content):
            for x in content:
                if not (isinstance(x, dict) and x.get('type') == 'tool_result' and x.get('tool_use_id') in asks):
                    continue
                qs = asks[x.get('tool_use_id')]
                res = e.get('toolUseResult')
                answers = res.get('answers') if isinstance(res, dict) else None
                if not isinstance(answers, dict):
                    continue
                for q, a in answers.items():
                    labels = set()
                    for qq in qs:
                        if qq.get('question') == q:
                            labels = {norm(str(o.get('label') or '')) for o in (qq.get('options') or [])
                                      if isinstance(o, dict)}
                    a = str(a)
                    # one picked label, or several joined by ", " (multiSelect); free text is no pick
                    picked = norm(a) in labels or (bool(labels) and all(norm(p) in labels for p in a.split(', ')))
                    out.append(('answer', ts, a, str(q), picked, len(qs)))
            continue
        text = owner_text(e)
        if text is not None and norm(text):
            out.append(('prompt', ts, text))
    return out


# --- git and the stats files ---------------------------------------------------------------------

def git(root, *args):
    try:
        r = subprocess.run(['git', '-C', root] + list(args), capture_output=True, timeout=8)
    except Exception:
        return None
    if r.returncode != 0:
        return None
    return r.stdout.decode('utf-8', 'replace')


def repo_root(spec_dir, cwd):
    d = spec_dir
    while d and not os.path.isdir(d):
        up = os.path.dirname(d)
        if up == d:
            break
        d = up
    top = git(d, 'rev-parse', '--show-toplevel') if d and os.path.isdir(d) else None
    if top and top.strip():
        return top.strip()
    return os.environ.get('CLAUDE_PROJECT_DIR') or cwd


def plan_commit(root, slug):
    """Commit time of the spec's newest `vulyk(<slug>): plan` commit, else None."""
    out = git(root, 'log', '--format=%ct%x09%s', '-F', '--grep=): plan')
    if out is None:
        return None
    want = ('vulyk(%s): plan' % slug, 'chore(vulyk-%s): plan' % slug)
    for line in out.splitlines():
        t, _, subj = line.partition('\t')
        if subj.strip() in want and t.strip().isdigit():
            return int(t)
    return None


def latest_verdict(root, slug):
    """The newest council or human-check row's time for the spec, 0 when it has none."""
    best = 0
    for name in ('council.jsonl', 'human.jsonl'):
        try:
            with open(os.path.join(root, 'memory', 'stats', name), encoding='utf-8', errors='replace') as f:
                for line in f:
                    try:
                        row = json.loads(line)
                    except ValueError:
                        continue
                    if isinstance(row, dict) and row.get('spec') == slug:
                        t = epoch(row.get('ts'))
                        if t and t > best:
                            best = t
        except OSError:
            continue
    return best


# --- what the call records -------------------------------------------------------------------------

def split_segments(cmd, powershell):
    """Shell words cut into simple commands; None when the quotes do not close."""
    cmd = cmd.replace('\r', '').replace('`\n' if powershell else '\\\n', '')
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=';&|()')
    lex.whitespace = ' \t'
    lex.whitespace_split = True
    lex.escape = '`' if powershell else '\\'
    segs, cur = [], []
    try:
        for tok in lex:
            if tok in SEP or set(tok) <= set(';&|()\n'):
                if cur:
                    segs.append(cur)
                cur = []
            elif '\n' in tok:
                parts = tok.split('\n')
                for i, p in enumerate(parts):
                    if p:
                        cur.append(p)
                    if i < len(parts) - 1 and cur:
                        segs.append(cur)
                        cur = []
            else:
                cur.append(tok)
    except ValueError:
        return None
    if cur:
        segs.append(cur)
    return segs


def base(w):
    return os.path.basename(w.replace('\\', '/'))


def spec_of(path, cwd):
    p = os.path.join(cwd, path.strip('\'"')) if path else cwd
    return os.path.normpath(p.rstrip('/\\') or p)


def command_actions(cmd, powershell, cwd):
    acts = []
    segs = split_segments(cmd, powershell)
    for seg in segs or []:
        for k, w in enumerate(seg):
            rest = [x for x in seg[k + 1:] if x != '--commit']   # the flag is no part of the spec or the note
            if base(w) == 'human-check.sh' and len(rest) > 1 and rest[1].upper() in ('ACCEPTED', 'REJECTED'):
                acts.append(('release', spec_of(rest[0], cwd), ' '.join(rest[2:]), 'human-check.sh %s' % rest[1].upper()))
            if base(w) == 'cycle.sh' and len(seg) > k + 1 and seg[k + 1] == 'briefed' and '--go' in seg[k + 2:]:
                acts.append(('go', None, '', 'cycle.sh briefed --go'))
    # A form the words above missed (`bash -c "..."`, an unreadable command), read from the raw text: the
    # script path must not follow a backtick or a word character (prose names it in backticks) and the spec
    # must not be a `<spec>` placeholder.
    lead = r'(?<![\w`./\\~:-])(?:[\w.~:-]*[/\\])?'
    if not any(a[0] == 'release' for a in acts):
        m = re.search(lead + r'human-check(?:\.sh)?[\'"]?\s+[\'"]?([^\s\'"<`][^\s\'"`]*)[\'"]?\s+[\'"]?(ACCEPTED|REJECTED)\b[\'"]?(.*)',
                      re.sub(r'(?<!\S)[\'"]?--commit[\'"]?(?!\S)', ' ', cmd), re.S | re.I)
        if m:
            acts.append(('release', spec_of(m.group(1), cwd), m.group(3).strip(' \'"'), 'human-check.sh %s' % m.group(2).upper()))
    if not any(a[0] == 'go' for a in acts) and \
            re.search(lead + r'cycle\.sh[\'"]?\s+[\'"]?briefed\b[^\n`]*?(?<![\w-])--go(?![\w-])', cmd):
        acts.append(('go', None, '', 'cycle.sh briefed --go'))
    if 'plan.md' in cmd:
        flat = cmd.replace('\\*', '*')
        m = re.search(r'docs[/\\]specs[/\\]([^/\\\s\'"]+)[/\\]', cmd)
        spec = spec_of(m.group(0).rstrip('/\\'), cwd) if m else None
        # a marker written as data: at a line start or right after a quote, a `/` (sed) or a `>`; prose
        # (`**Approved:**` in backticks, mid-sentence) is no record
        for mm in re.finditer(r'(?:^[ \t]*|(?<=[\'"/>]))\*\*(Approved|Checked):\*\*[ \t]*([^\'"\n`]*)', flat, re.M):
            text = mm.group(2).split('\\n')[0].strip()
            if not text or text.startswith('<'):
                continue
            kind = 'plan' if mm.group(1) == 'Approved' else 'release'
            acts.append((kind, spec, text, 'a **%s:** line written by a command' % mm.group(1)))
        # a command that rewrites a plan.md holding a record line without spelling the marker: the hook cannot
        # read that line as it will stand, so it is judged as a record (`sed -i 's/<placeholder>/yes/' plan.md`)
        target = None if re.search(r'\*\*(Approved|Checked):\*\*', flat) else rewrites_plan(cmd, powershell)
        if target:
            full = os.path.normpath(os.path.join(cwd, target.strip('\'"')))
            try:
                with open(full, encoding='utf-8', errors='replace') as f:
                    held = any(MARKER.match(line) for line in f)
            except OSError:
                held = False
            if held:
                acts.append(('rewrite', os.path.dirname(full), '', 'a command that rewrites %s' % target))
    # strict on purpose (owner-guard-commit-fp): reading shell text for "does it write the file" never converged,
    # so a command naming the record beside a verdict word is a row write, a git add / commit included;
    # `human-check.sh ... --commit` records and commits the row, and no other command needs to say both
    if 'human.jsonl' in cmd and re.search(r'ACCEPTED|REJECTED', cmd) and not any(a[0] == 'release' for a in acts):
        m = re.search(r'"spec\\?"\s*:\s*\\?"([^"\\]+)', cmd)
        acts.append(('release', spec_of('docs/specs/' + m.group(1), cwd) if m else None, cmd,
                     'a command naming human.jsonl beside ACCEPTED or REJECTED (record and commit a check only '
                     'with `human-check.sh <spec> <verdict> "<note>" --commit`)'))
    return acts


def after_edit(tool, ti, path):
    """[(file before, file after)] for an Edit or MultiEdit whose old_strings all apply to the file as it is,
    else None: a marker line is judged as it stands after the edit, also when the edit leaves the marker
    itself out of its strings and replaces only the text after it."""
    if tool not in ('Edit', 'MultiEdit'):
        return None
    try:
        with open(path, encoding='utf-8', errors='replace', newline='') as f:
            text = f.read()
    except OSError:
        return None
    edits = [ti] if tool == 'Edit' else [e for e in (ti.get('edits') or []) if isinstance(e, dict)]
    before = text
    for e in edits:
        old, new = str(e.get('old_string') or ''), str(e.get('new_string') or '')
        if not old or old not in text:
            return None
        text = text.replace(old, new) if e.get('replace_all') else text.replace(old, new, 1)
    return [(before, text)]


# Programs that may write a file they name without spelling what they write (sed and awk count with -i only).
WRITERS = ('tee', 'cp', 'mv', 'install', 'dd', 'truncate', 'set-content', 'add-content', 'out-file', 'copy-item',
           'move-item', 'python', 'python3', 'py', 'node', 'perl', 'ruby')


def rewrites_plan(cmd, powershell, depth=0):
    """The first docs/specs/<slug>/plan.md path a command may rewrite, else None: a redirect into it; a simple
    command naming it run by one of WRITERS (cp, mv, install, Copy-Item, Move-Item only as the last word), or by
    sed or awk with an in-place flag; a word holding a whole command (`bash -c "..."`) is read the same way."""
    m = re.search(r'(?<![0-9&])>{1,2}\s*[\'"]?([^\s\'";&|<>]*docs[/\\]specs[/\\][^/\\\s\'"]+[/\\]plan\.md)\b', cmd)
    if m:
        return m.group(1)
    for seg in split_segments(cmd, powershell) or []:
        hits = [w for w in seg if re.search(r'docs[/\\]specs[/\\][^/\\\s\'"]+[/\\]plan\.md', w)]
        if not hits:
            continue
        lead = base(seg[0]).lower()
        lead = lead[:-4] if lead.endswith('.exe') else lead
        if lead in ('cp', 'mv', 'install', 'copy-item', 'move-item'):
            hits = hits if seg[-1] in hits else []
        if (hits and lead in WRITERS) or (lead in ('sed', 'gsed', 'awk', 'gawk') and any(
                re.match(r'^(-[a-zA-Z]*i\S*|--in-place\S*)$', w) for w in seg[1:])):
            m = re.search(r'[^\s\'"]*docs[/\\]specs[/\\][^/\\\s\'"]+[/\\]plan\.md', hits[0])
            return m.group(0)
        if depth < 2:
            for w in hits:
                if re.search(r'\s', w):
                    found = rewrites_plan(w, powershell, depth + 1)
                    if found:
                        return found
    return None


def edit_pairs(tool, ti, path):
    if tool == 'Edit':
        return [(str(ti.get('old_string') or ''), str(ti.get('new_string') or ''))]
    if tool == 'MultiEdit':
        return [(str(e.get('old_string') or ''), str(e.get('new_string') or ''))
                for e in (ti.get('edits') or []) if isinstance(e, dict)]
    if tool == 'Write':
        try:
            with open(path, encoding='utf-8', errors='replace') as f:
                old = f.read()
        except OSError:
            old = ''
        return [(old, str(ti.get('content') or ''))]
    return []


def file_actions(tool, ti, cwd):
    path = ti.get('file_path')
    if not isinstance(path, str) or not path:
        return []
    full = os.path.normpath(os.path.join(cwd, path))
    norm_path = full.replace('\\', '/')
    acts = []
    m = PLAN.search(norm_path)
    if m:
        for old, new in after_edit(tool, ti, full) or edit_pairs(tool, ti, full):
            had = {l.strip() for l in old.splitlines()}
            for line in new.splitlines():
                mm = MARKER.match(line)
                if not mm or line.strip() in had:
                    continue
                text = mm.group(2).strip()
                if not text or text.startswith('<'):
                    continue
                kind = 'plan' if mm.group(1) == 'Approved' else 'release'
                acts.append((kind, os.path.dirname(full), text, 'a **%s:** line in %s' % (mm.group(1), path)))
    elif norm_path.endswith('memory/stats/human.jsonl'):
        root = os.path.dirname(os.path.dirname(os.path.dirname(full)))
        for old, new in edit_pairs(tool, ti, full):
            had = {l.strip() for l in old.splitlines()}
            for line in new.splitlines():
                if line.strip() in had or not re.search(r'ACCEPTED|REJECTED', line):
                    continue
                try:
                    row = json.loads(line)
                except ValueError:
                    row = {}
                slug = row.get('spec') if isinstance(row, dict) else None
                note = row.get('note') if isinstance(row, dict) else None
                acts.append(('release', os.path.join(root, 'docs', 'specs', slug) if isinstance(slug, str) else None,
                             note if isinstance(note, str) else line, 'a human.jsonl row'))
    return acts


# --- the quote rule --------------------------------------------------------------------------------

def judge_go(evs):
    for ev in evs:
        if ev[0] == 'prompt' and re.search(r'(?<![\w-])--go(?![\w-])', ev[2]):
            return None
    return ('VULYK owner guard: `cycle.sh briefed ... --go` runs a plan without the approval stop, and no owner '
            'prompt of this session carries `--go`. Stop for his approval instead.' + OWNER_CAN)


def judge_plan(evs, root, slug, note):
    if not slug:
        return 'VULYK owner guard: an **Approved:** line whose spec the hook cannot name.' + OWNER_CAN
    t0 = plan_commit(root, slug)
    if t0 is None:
        return ('VULYK owner guard: an **Approved:** line for %s, and the spec has no `vulyk(%s): plan` commit: '
                'commit the plan, show it to the owner, then write his answer.' % (slug, slug)) + OWNER_CAN
    last = None
    for ev in evs:
        if ev[0] in ('prompt', 'answer'):
            last = ev
    if last is None:
        return 'VULYK owner guard: an **Approved:** line, and this session holds no owner message.' + OWNER_CAN
    if last[1] is None or last[1] <= t0:
        return ('VULYK owner guard: an **Approved:** line for %s, but the owner\'s latest message is older than '
                'the plan commit. Show him the committed plan and quote his answer.' % slug) + OWNER_CAN
    found = units(last[2]) if last[0] == 'prompt' else [norm(last[2])]
    if any(quotes(u, note) for u in found):
        return None
    return ('VULYK owner guard: the **Approved:** line for %s does not quote the owner\'s latest message whole '
            '(one message, one whole line of it, or one whole answer). Quote his words verbatim.' % slug) + OWNER_CAN


def judge_release(evs, root, slug, note, what):
    if not slug:
        return 'VULYK owner guard: %s for a spec the hook cannot name.' % what + OWNER_CAN
    since = latest_verdict(root, slug)
    cands, asked = [], False
    i = 0
    while i < len(evs):
        ev = evs[i]
        if ev[0] == 'ask' and ev[3] == 1 and slug in ev[2]:
            asked = True
            for nxt in evs[i + 1:]:
                if nxt[0] == 'answer' and nxt[5] == 1 and slug in nxt[3]:
                    if nxt[1] is not None and nxt[1] > since and (nxt[4] or alnum(nxt[2]) >= 8):
                        cands.append(norm(nxt[2]))
                elif nxt[0] == 'prompt':
                    if nxt[1] is not None and nxt[1] > since:
                        cands.extend(u for u in units(nxt[2]) if alnum(u) >= 8)
                    break
                elif nxt[0] == 'ask':
                    break
        i += 1
    if any(quotes(u, note) for u in cands):
        return None
    if not asked:
        return ('VULYK owner guard: %s needs the owner\'s answer to the release question for %s asked alone '
                '(one AskUserQuestion naming the spec), quoted whole in the note; this session asked none.'
                % (what, slug)) + OWNER_CAN
    return ('VULYK owner guard: the note of %s does not quote, whole, the owner\'s answer to the release question '
            'for %s or his next message after it, written after the spec\'s latest verdict (8+ letters or digits '
            'unless he picked an option).' % (what, slug)) + OWNER_CAN


def main():
    global GUARDED
    try:
        data = json.loads(sys.stdin.buffer.read().decode('utf-8-sig', 'replace'))
    except Exception:
        sys.exit(0)
    if not isinstance(data, dict):
        sys.exit(0)
    tool = str(data.get('tool_name') or '')
    ti = data.get('tool_input') if isinstance(data.get('tool_input'), dict) else {}
    cwd = str(data.get('cwd') or os.environ.get('CLAUDE_PROJECT_DIR') or os.getcwd())
    if tool in ('Bash', 'PowerShell'):
        cmd = ti.get('command')
        acts = command_actions(cmd, tool == 'PowerShell', cwd) if isinstance(cmd, str) else []
    elif tool in ('Edit', 'Write', 'MultiEdit'):
        acts = file_actions(tool, ti, cwd)
    else:
        acts = []
    if not acts:
        sys.exit(0)
    GUARDED = True
    if data.get('agent_id'):
        deny(SUBAGENT)
    entries = load_transcript(data)
    if isinstance(entries, str):
        deny('VULYK owner guard: %s, so the hook cannot see whether the owner said these words, and the call '
             'that would record them is refused.' % entries + OWNER_CAN)
    evs = events(entries)
    for kind, spec, note, what in acts:
        slug = os.path.basename(spec) if spec else None
        root = repo_root(spec, cwd) if spec else cwd
        if kind == 'go':
            why = judge_go(evs)
        elif kind == 'rewrite':
            why = ('VULYK owner guard: %s, which holds an **Approved:** or **Checked:** line, and the hook cannot '
                   'read that line as it will stand after the command. Change the plan with the Edit tool, which '
                   'it judges line by line.' % what) + OWNER_CAN
        elif kind == 'plan':
            why = judge_plan(evs, root, slug, note)
        else:
            why = judge_release(evs, root, slug, note, what)
        if why:
            deny(why)
    sys.exit(0)


try:
    main()
except SystemExit:
    raise
except Exception as e:
    if GUARDED:
        deny('VULYK owner guard: the hook failed (%s) on a call that may record the owner\'s words, so it is '
             'refused.' % e.__class__.__name__ + OWNER_CAN)
    sys.exit(0)
PYTHON
