#!/usr/bin/env bash
# PreToolUse hook (matcher Bash|PowerShell|Edit|Write|MultiEdit): only the owner's own words record his
# acceptance, a plan's approval or a straight-through `--go` (plan.md `## Contracts` O1 of audit-fixes-1113,
# card docs/defects/owner-words-by-builder.md), and only `scripts/cycle.sh` writes the cycle's run state by a tool
# (`## Contracts` R1, N1 and F1 of guards-1115).
#
# Guarded calls:
#   - a command running `human-check.sh <spec> ACCEPTED|REJECTED [note] [--commit]` (release acceptance; the
#     `--commit` word is no part of the spec or the note);
#   - a command running `cycle.sh briefed <spec> ... --go`;
#   - an Edit, MultiEdit, Write or shell command that adds or changes a `**Approved:**` or `**Checked:**` line
#     of a `docs/specs/<slug>/plan.md` (a line still holding the template placeholder `<...>` is no record),
#     and one that adds an ACCEPTED or REJECTED row to `memory/stats/human.jsonl`: any shell command naming
#     `human.jsonl` beside the word ACCEPTED or REJECTED counts as one, a `git add` / `git commit` of the record
#     included, so `human-check.sh ... --commit` commits its own plan.md line and row. An Edit, MultiEdit or
#     Write is judged by its path resolved (letter case, a trailing dot or space, a `:stream`, links) and an Edit
#     or MultiEdit on the file as it stands after it, so one that replaces only the text after the marker, or
#     moves a row to another spec, counts;
#   - a shell command that may rewrite a plan.md holding such a line without spelling the marker (a redirect
#     into it; tee, cp, mv, a script interpreter; sed or awk -i) and that names it by its `docs/specs/<slug>/plan.md`
#     path, also inside a word that holds a whole command (`bash -c`, a heredoc, a pipe or a here-string with the
#     path spelled): the hook cannot read the line it leaves, so it is denied to everyone, with the Edit tool named
#     as the way.
# A subagent (the input carries agent_id) is denied every guarded call, and the Python half reads each of its
# Bash, PowerShell, Edit, MultiEdit and Write calls, with no text prefilter. It is also denied:
#   - a Write, Edit or MultiEdit whose path, resolved (`..`, links, letter case), lies under `.vulyk/state/`, the
#     run state only `scripts/cycle.sh` writes ("a subagent cannot write a run-state record");
#   - a shell command in which a word that may be a program word runs `human-check.sh` with an argument that
#     may be a verdict, or `cycle.sh` with a verb that may be `briefed` and a later argument that may be `--go`.
#     A program word is the first word after keywords (with their options: `time -p`, `exec -a x`), assignments
#     and wrappers, each wrapper itself (`env -S "<command>"`), and each later word unless the first is a
#     program that reads its words as data (echo, grep, cat, git and the like), so a program the hook does not
#     know (setsid, busybox, `find -exec`, a shell function) is looked through. Words are read after quote
#     removal, a glob is matched against the name, a variable takes each value an assignment or a `for` list of
#     the same command gives it, a value with a space in it is read as a command, a `find -exec` `{}` takes the
#     names find may hand it, and any other expansion reads as a glob; a program word the hook cannot read is
#     judged as each guarded program it may be. Text handed to a shell (`bash -c`, `eval`, `env -S`, a heredoc,
#     a here-string, a command substitution) is read the same way, and a `<<` inside `(( ))` is no heredoc;
#     `human-check.sh --check|--show` and a shell that only checks syntax (`bash -n`, behind `xargs` too) pass;
#   - a shell command, read the same way, that may write a file named `plan.md` or the record `human.jsonl`: a
#     redirect target; the files of tee, truncate, touch, dd `of=`, patch, ed, ex, vi / vim, emacs, nano, sponge,
#     ln, sed / awk / perl / ruby in place and PowerShell's content writers; the value of an option naming the
#     output file (`-o`, `-O`, `--output`) for any program but a few that read with it; the target of cp, mv,
#     install, rsync, scp, Copy-Item or Move-Item (a source too when the target is a folder, and a spec folder
#     filled from a glob); a spec folder an archive is unpacked into; a plan.md named beside an interpreter or in
#     the text fed to one. A word counts by its last part in any case, with a trailing dot or space dropped, by
#     a link to the file, or, as a glob from the folder the command stands in, by what it matches on disk or by
#     spelling some of the name's letters (a lone `*`, `*.md` or an unknown value names any file, not this one);
#     a target the hook cannot read counts when another word of the command may be such a file;
#   - a `git add` or `git commit` whose pathspec covers `memory/stats/human.jsonl` (the record, its folder, `.`,
#     a glob, `-A` / `-u` / `-a`, after a changed directory or `-C`, an alias of an alias followed), and a `git
#     commit` whose message or command text may carry ACCEPTED or REJECTED (a message of unknown value counts);
#   - a shell command whose quotes do not close.
# The main session's shell command that runs `human-check.sh` with a verdict or `cycle.sh briefed --go` spelled
# otherwise than plainly (the script, verdict or flag built from quotes or a pattern, or held in a variable the
# same command sets, also in text handed to a shell) is denied while one of the prefilter's words below stays
# whole, read as above; the quote rule judges only a plainly spelled call. Its text prefilter passes a call holding none of `human`, `brief`, `accept`, `reject` (any
# letter case), a marker or `plan.md`.
# The main session passes only under the
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
# The main session's plan.md rewrite check reads the path as the command spells it (`docs/specs/<slug>/plan.md`).
# No Python, or a transcript the hook cannot read: a guarded call is denied with a message naming the cause;
# without Python every Edit, MultiEdit or Write of a plan.md counts as one, and for a subagent so does a Write,
# Edit or MultiEdit whose path holds `vulyk` and then `state`, and a shell call whose text holds, in any letter
# case, `accept`, `reject`, `human`, `brief`, `plan.md`, `vulyk` then `state`, or `memory` then `stats`, or
# holds `--go` or a marker.
# The owner can always run the command in his own terminal.
# `--check <file>` (the card's check): reads hook input from <file>; a `transcript` field (a list of entries)
# stands in for the file. Exit 1 on a deny (the reason on stdout), 0 otherwise, also for a file that is no
# hook input.
# The Python half lives below the `exit`, inside a no-op heredoc, as in git-guard.sh.
# The guards stop accidents and shortcuts of a cooperative agent, not an adversary.
# Left open on purpose (the card's `## Check` lists the same):
#   - the main session's text prefilter and spelled-form reading: a guarded script run whose text holds none of
#     the prefilter's words (its script, verb or verdict word split by a quote pair, a backslash or a variable the
#     same command sets, so that no prefilter word stays whole), a script, verdict or flag from a value the main
#     session's command does not set (the environment, a substitution), and a marker or record the main session's command or tool path never spells
#     (built from quotes, globs, braces, variables or a changed directory, in another letter case, or a plan.md
#     named without its `docs/specs/<slug>/` path) is not read, and the quote rule judges only what is spelled;
#   - command text a shell reads from a file or a pipe (a script file, a list of commands piped into a shell),
#     and code an interpreter runs, inline or from a file: their content is not read for what it runs;
#   - a plan.md written by a git verb that writes the tree, and, for the main session, by a writer outside the
#     hook's list (a line editor, a patch, sync or link tool);
#   - for a subagent, a write the hook cannot tie to the file: a writer it does not know that takes its file as
#     a plain argument; behind another program word, a program spelled as a pattern, or a plain-argument writer
#     given by an unknown value; a target that comes only from a file, a pipe or the environment while no word
#     of the command may be a plan.md or the record; a hard link to the file made by an earlier call;
#   - a guarded script copied or linked under another name, a commit of what an earlier call staged, and a
#     verdict word in the message of a git verb other than commit or in a message file the hook cannot read;
#   - writes through tools the hook is not wired on (a notebook editor, an MCP file tool), and the run state
#     reached by a shell command, which git-guard.sh judges;
#   - whether the owner's words mean yes (no word list), the transcript file itself (the session can write it),
#     and text an agent wrote that the owner types or sends;
#   - with no Python: for a subagent, what its text filter cannot see (a name or verdict built from pieces that
#     hold none of its fragments, a run-state path reached through a link, a git pathspec that covers the
#     record without naming its folder), and for the main session every shell rewrite of a plan.md that spells
#     no marker;
#   - refused although harmless (a known over-deny, 0.55.0): for a subagent, text that only quotes a guarded call
#     (a heredoc fed to cat, an echo or printf word: a seat's report, a worker's note).
if [ "${1:-}" = "--check" ]; then
  [ -f "${2:-}" ] || exit 0
  IFS= read -r -d '' IN < "$2"
else
  IFS= read -r -d '' IN   # a builtin: an unrelated call starts no process
fi
SUB=''   # a subagent's call: a non-empty top-level agent_id (a key inside a JSON string has its quotes escaped)
RE='"agent_id"[[:space:]]*:[[:space:]]*"[^"]'
[[ $IN =~ $RE ]] && SUB=1
if [ -z "$SUB" ]; then   # the main session's text prefilter
  case "$IN" in *[Hh][Uu][Mm][Aa][Nn]*|*[Bb][Rr][Ii][Ee][Ff]*|*[Aa][Cc][Cc][Ee][Pp][Tt]*|*[Rr][Ee][Jj][Ee][Cc][Tt]*) ;;
    *Approved:*|*Checked:*|*plan.md*) ;; *) exit 0 ;; esac
fi
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
if [ -n "$SUB" ]; then   # a subagent: a wider text filter over the tool input
  TIN="${IN#*\"tool_input\"}"
  RE='"tool_name"[[:space:]]*:[[:space:]]*"(Bash|PowerShell)"'
  if [[ $IN =~ $RE ]]; then
    case "$TIN" in *[Aa][Cc][Cc][Ee][Pp][Tt]*|*[Rr][Ee][Jj][Ee][Cc][Tt]*|*[Hh][Uu][Mm][Aa][Nn]*|*[Bb][Rr][Ii][Ee][Ff]*) GUARDED=1 ;; esac
    case "$TIN" in *--go*|*[Pp][Ll][Aa][Nn].[Mm][Dd]*|*Approved:*|*Checked:*) GUARDED=1 ;; esac
    case "$TIN" in *[Vv][Uu][Ll][Yy][Kk]*[Ss][Tt][Aa][Tt][Ee]*|*[Mm][Ee][Mm][Oo][Rr][Yy]*[Ss][Tt][Aa][Tt][Ss]*) GUARDED=1 ;; esac
  fi
  RE='"file_path"[[:space:]]*:[[:space:]]*"[^"]*[Vv][Uu][Ll][Yy][Kk][^"]*[Ss][Tt][Aa][Tt][Ee]'
  [[ $IN =~ $RE ]] && GUARDED=1
fi
[ -n "$GUARDED" ] || exit 0
printf '%s\n' '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "VULYK owner guard: no Python 3 answered ($VULYK_PY, python3, python, py), so this hook cannot read the transcript to see whether the owner said these words. A call that may record his acceptance, a plan approval or --go, or a subagent call that may write the run state, is refused. Install Python 3 or set VULYK_PY, or the owner runs the command in his own terminal."}}'
[ "${1:-}" = "--check" ] && exit 1
exit 0

: <<'PYTHON'
#<py>
import calendar, fnmatch, glob, json, os, posixpath, re, shlex, subprocess, sys

CHECK = len(sys.argv) > 1 and sys.argv[1] == '--check'
SEP = {';', '&&', '||', '|', '&', '\n', '(', ')', '{', '}'}
GUARDED = False
SCRIPT_ONLY = False   # the main session's spelled-form read: only a guarded script's run counts, by what it spells

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
    # script path must not follow a word character and the spec must not be a `<spec>` placeholder. A backtick
    # before it counts (a command substitution runs it), so prose naming the command in backticks is guarded too.
    lead = r'(?<![\w./\\~:-])(?:[\w.~:-]*[/\\])?'
    if not any(a[0] == 'release' for a in acts):
        m = re.search(lead + r'human-check(?:\.sh)?[\'"]?\s+[\'"]?([^\s\'"<`][^\s\'"`]*)[\'"]?\s+[\'"]?(ACCEPTED|REJECTED)\b[\'"]?(.*)',
                      re.sub(r'(?<!\S)[\'"]?--commit[\'"]?(?!\S)', ' ', cmd), re.S | re.I)
        if m:
            acts.append(('release', spec_of(m.group(1), cwd), m.group(3).strip(' \'"`'), 'human-check.sh %s' % m.group(2).upper()))
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


def resolved(path, cwd):
    """[(the path, its parts)] as typed and with links followed; each part in lower case with a Windows trailing
    dot or space and a `:stream` suffix dropped, so a spelling of the same file reads as that file."""
    full = os.path.join(cwd, os.path.expanduser(path))
    seen = [os.path.normpath(full)]
    try:
        seen.append(os.path.realpath(full))
    except (OSError, ValueError):
        pass
    return [(p, [re.sub(r':.*$', '', x).rstrip('. ').casefold() for x in re.split(r'[/\\]+', p)[1:]]) for p in seen]


def file_actions(tool, ti, cwd):
    path = ti.get('file_path')
    if not isinstance(path, str) or not path:
        return []
    forms = resolved(path, cwd)
    plan = [p for p, parts in forms if len(parts) >= 4 and parts[-4:-2] == ['docs', 'specs'] and parts[-1] == 'plan.md']
    rec = [p for p, parts in forms if parts[-3:] == ['memory', 'stats', 'human.jsonl']]
    acts = []
    if plan:
        full = plan[-1]   # the resolved form when it is the one that matched: its folder names the spec
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
    elif rec:
        full = rec[-1]
        root = os.path.dirname(os.path.dirname(os.path.dirname(full)))
        # judged on the file as it stands after the edit: a row moved to another spec holds no new verdict word
        for old, new in after_edit(tool, ti, full) or edit_pairs(tool, ti, full):
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


# --- a subagent's calls, read under any spelling (guards-1115 R1, N1) ---------------------------------

RUN_STATE = ('VULYK owner guard: a subagent cannot write a run-state record (%s). `.vulyk/state/` holds the claim, '
             'approval and verification records the cycle trusts, and only scripts/cycle.sh writes them. Read it '
             'with the Read tool; put what should change under ## Findings and return it.')
MAIN_SPELL = ('VULYK owner guard: the quote rule judges a guarded call only as it is spelled out, and this '
              'command spells it otherwise.')
SCRIPT_WORD = SUBAGENT + (' This command may run %s that way (%s); a script word, verdict or flag the hook cannot '
                          'read counts as one: spell the script path and its arguments.')
PLAN_WRITE = ('VULYK owner guard: a subagent\'s shell command that may write a plan.md (%s), which holds the '
              'owner\'s **Approved:** and **Checked:** records. Change a plan.md with the Edit tool, which the hook '
              'judges line by line.')
GIT_RECORD = ('VULYK owner guard: a subagent\'s `git %s` that covers memory/stats/human.jsonl, the owner\'s '
              'acceptance record (%s). Name the files you mean; only `human-check.sh <spec> <verdict> "<note>" '
              '--commit`, run by the main session quoting the owner, commits the record.')
ALIAS_CHAIN = ('VULYK owner guard: a subagent\'s git call through the alias chain %s, which the hook cannot follow '
               'to its end (too long, or a cycle), so it cannot tell whether it stages or commits '
               'memory/stats/human.jsonl. Run the git verb by its own name.')
COMMIT_VERDICT = ('VULYK owner guard: a subagent\'s `git commit` whose message may carry a verdict word (%s): such '
                  'a commit records the owner\'s acceptance, which only `human-check.sh <spec> <verdict> "<note>" '
                  '--commit` makes, run by the main session quoting the owner.')
UNSPLIT = ('VULYK owner guard: a subagent\'s shell command whose quotes do not close or that nests too deep, so the '
           'hook cannot read what it runs. Close the quotes or split the command.')
RECORD_WRITE = ('VULYK owner guard: a subagent\'s shell command that may write memory/stats/human.jsonl, the owner\'s '
                'acceptance record (it may write %s). Only `human-check.sh`, run by the main session quoting the owner, '
                'writes it; put what you would record under ## Findings and return it.')
SHELLS = {'bash', 'sh', 'zsh', 'dash', 'ksh', 'mksh', 'ash', 'busybox', 'fish'}
PWSH = {'pwsh', 'powershell'}
INTERPRETERS = {'python', 'py', 'node', 'perl', 'ruby', 'php', 'deno', 'bun', 'lua', 'rscript', 'osascript'}
KEYWORDS = {'!', 'then', 'do', 'else', 'elif', 'if', 'while', 'until', 'time', '{', '}', 'exec', 'command',
            'builtin', 'nohup', 'noglob', 'coproc', 'winpty'}
# Programs that read their words as data: the words after them are not looked at as a program word. Any other
# program may run the words after it (setsid, busybox, find -exec), so each of them is judged as one.
DATA_PROGS = {'echo', 'printf', 'grep', 'egrep', 'fgrep', 'rg', 'ag', 'cat', 'head', 'tail', 'less', 'more', 'wc',
              'ls', 'diff', 'cmp', 'cut', 'tr', 'sort', 'uniq', 'test', '[', '[[', 'basename', 'dirname', 'realpath',
              'readlink', 'stat', 'file', 'jq', 'true', 'false', 'read', 'export', 'local', 'declare', 'readonly',
              'typeset', 'set', 'unset', 'shift', 'return', 'exit', 'printenv', 'which', 'type', 'hash', 'date',
              'sleep', 'mkdir', 'rmdir', 'rm', 'chmod', 'md5sum', 'sha256sum', 'sha1sum', 'base64', 'nl', 'od',
              'tac', 'paste', 'comm', 'seq', 'pwd', 'git', 'write-output', 'write-host', 'get-content', 'select-string'}
ARG_WRITERS = {'tee', 'truncate', 'touch', 'patch', 'ed', 'ex', 'vi', 'vim', 'nvim', 'emacs', 'nano', 'sponge',
               'dos2unix', 'unix2dos', 'ln', 'set-content', 'add-content', 'out-file', 'new-item', 'sc', 'ac', 'ni',
               'tee-object'}
COPIERS = {'cp', 'mv', 'install', 'rsync', 'scp', 'copy-item', 'move-item', 'cpi', 'mi', 'copy', 'move', 'xcopy',
           'robocopy'}
INPLACE = {'sed', 'gsed', 'awk', 'gawk', 'perl', 'ruby'}
EXTRACTORS = {'tar', 'gtar', 'bsdtar', 'unzip', '7z', '7za'}
# The programs a program word the hook cannot read may stand for (a glob, an unset variable, a substitution).
MAY_RUN = {'git', 'eval', 'source', 'xargs', 'env', 'dd', 'invoke-expression', 'iex'}
STOP = '\x01'   # judge_named: the segment runs nothing more (a syntax check, xargs read as a whole)
# An option that names the file a program writes (sort -o, curl -o, wget -O, --output=); these read it otherwise.
OUT_OPT_READERS = {'ls', 'grep', 'egrep', 'fgrep', 'rg', 'ag', 'ssh', 'scp', 'ps', 'set', 'shopt', 'git'}
WRAPPERS = {'sudo': 'ugCDhprtU', 'doas': 'uC', 'env': 'uCS', 'nice': 'n', 'timeout': 'sk', 'gtimeout': 'sk',
            'stdbuf': 'ioe', 'ionice': 'cnp', 'taskset': '', 'chrt': '', 'unbuffer': '', 'caffeinate': 'w'}
GLOB = re.compile(r'[*?\[]')
ASSIGN = re.compile(r'^\$?([A-Za-z_]\w*)\+?=(.*)$', re.S)
EXPANSION = re.compile(r'\$\{([A-Za-z_]\w*)\}|\$([A-Za-z_]\w*)|\$\{[^}]*\}?|\$env:\w+|\$[0-9@*#?$!-]|\$$|`[^`]*`?')
VERDICT_RE = re.compile(r'(?<![a-z])(accepted|rejected)(?![a-z])', re.I)
RECORD = 'memory/stats/human.jsonl'
UNKNOWN = '\x00'   # a part of a word the hook cannot read (an unknown variable, a substitution)


def prog_name(w):
    b = base(w).casefold()
    return b[:-4] if b.endswith('.exe') else b


def globmatch(name, pat):
    """True when the literal name may be what the word stands for (the word read as a glob, any case)."""
    pat = pat.replace(UNKNOWN, '*').casefold()
    return fnmatch.fnmatchcase(name.casefold(), pat) if GLOB.search(pat) else name.casefold() == pat


def braces(w, depth=0):
    m = re.search(r'\{([^{}]*,[^{}]*)\}', w)
    if not m or depth > 4:
        return [re.sub(r'\{[^{}]*\.\.[^{}]*\}', '*', w)]
    out = []
    for alt in m.group(1).split(','):
        out.extend(braces(w[:m.start()] + alt + w[m.end():], depth + 1))
    return out[:64]


def expand(word, vars):
    """What the word may stand for: a known variable gives each value it was set to, any other expansion the
    UNKNOWN mark (read as a glob `*`), braces are expanded; ANSI-C quoting makes the whole word unknown."""
    if '$\\' in word:
        return [UNKNOWN]
    outs, pos = [''], 0
    for m in EXPANSION.finditer(word):
        lit, pos = word[pos:m.start()], m.end()
        name = m.group(1) or m.group(2)
        if name == '__tmp__':
            vals = ['tmp.XXXXXXXXXX']
        else:
            vals = vars.get(name) if name else None
        outs = [o + lit + v for o in outs for v in (vals or [UNKNOWN])][:64]
    outs = [o + word[pos:] for o in outs]
    res = []
    for o in outs:
        res.extend(braces(o))
    return res[:64] or ['']


def may_be(name, cands):
    return any(globmatch(name, base(c)) for c in cands)


STEM = {'plan.md': 'pln', 'human.jsonl': 'hum'}


def spells(b, name):
    """True when a glob's literal letters spell some of the name's own (`plan.*`, `p?an.md`, `hum*.jsonl`): a
    lone `*`, `**`, `*.md` or an unknown value names any file, not this one."""
    lit = re.sub(r'\[[^\]]*\]?|[*?]', '', b.replace(UNKNOWN, '')).casefold()
    return any(ch in lit for ch in STEM[name])


def names_plan(text, vars):
    """True when a text (a word, a heredoc body) names a file plan.md, also by a glob that spells it."""
    if 'plan.md' in text.casefold():
        return True
    for tok in re.split(r'[\s\'"(),;=:<>|&]+', text):
        if tok and any(globmatch('plan.md', base(c)) and spells(base(c), 'plan.md') for c in expand(tok, vars)):
            return True
    return False


def hits(word, vars, d, name):
    """True when the word, read as a file a command writes from the folder d, may be the file `name`: its last
    part in any case, with a trailing dot or space or a `:stream` dropped, is the name or a glob spelling it; it
    is a link to the file; or, read as a glob from d (an unknown part as `*`), it matches the file on disk."""
    for c in expand(word, vars):
        b = re.sub(r':.*$', '', base(c)).rstrip('. ')
        wild = UNKNOWN in c or GLOB.search(c)
        if globmatch(name, b) and (not wild or spells(b, name)):
            return True
        if d is None or c.startswith('~') or re.match(r'^[a-z][a-z0-9+.-]*://', c, re.I):
            continue
        p = os.path.join(d, c.replace(UNKNOWN, '*'))
        try:
            found = glob.glob(p)[:500] if wild else ([os.path.realpath(p)] if os.path.lexists(p) else [])
        except (OSError, ValueError, re.error):
            found = []
        if any(re.sub(r':.*$', '', base(f)).rstrip('. ').casefold() == name for f in found):
            return True
    return False


def unresolved(word, vars):
    return any(UNKNOWN in c for c in expand(word, vars))


def near(where, vars, name):
    """True when some word of the whole command may be the file `name` (a guarded path stands in it)."""
    if name not in where.near:
        toks = [t for t in re.split(r'[\s\'"();&|<>=`]+', where.cmd) if t][:400]
        where.near[name] = (name == 'plan.md' and names_plan(where.cmd, vars)) or \
            any(hits(t, vars, where.start, name) for t in toks)
    return where.near[name]


def target_why(t, vars, where, d):
    """A deny reason when a word a command writes may be a plan.md or the acceptance record: it names one, or it
    is a value the hook cannot read and the command names one elsewhere."""
    for name in ('plan.md', 'human.jsonl'):
        if hits(t, vars, d, name) or (unresolved(t, vars) and near(where, vars, name)):
            return PLAN_WRITE % ('it may write %s' % t) if name == 'plan.md' else RECORD_WRITE % t
    return None


def spec_dir(word, vars, d):
    """True when the word, read as a folder from d, may be a spec folder (docs/specs/<slug>, or one holding a
    plan.md on disk)."""
    for c in expand(word, vars):
        s = c.replace('\\', '/').rstrip('/').casefold()
        if re.search(r'(?:^|/)docs/specs/[^/]+$', s.replace(UNKNOWN, 'x')):
            return True
        if d is None:
            continue
        try:
            dirs = glob.glob(os.path.join(d, c.replace(UNKNOWN, '*'))) if UNKNOWN in c or GLOB.search(c) \
                else [os.path.join(d, c)]
        except (OSError, ValueError, re.error):
            dirs = []
        if any(os.path.isfile(os.path.join(x, 'plan.md')) for x in dirs[:200]):
            return True
    return False


def unwrap(cmd, ps):
    """(the command with each heredoc body cut out and each command substitution replaced by a word, [(kind,
    text)]): kind 'shell' for a substitution and for a heredoc whose line runs a shell, 'interp' for one whose
    line runs an interpreter, else 'data'. Quotes and comments are followed, so a `<<` or `$(` inside single
    quotes opens nothing."""
    out, nested, pend = [], [], []
    i, n, q, line_start = 0, len(cmd), None, 0
    esc = '`' if ps else '\\'
    while i < n:
        ch = cmd[i]
        if q == "'":
            if ch == "'":
                q = None
            out.append(ch)
            i += 1
            continue
        if ch == esc:
            out.append(cmd[i:i + 2])
            i += 2
            continue
        if ch == '$' and cmd.startswith('$(', i) or (ch in '<>' and cmd.startswith('(', i + 1) and q is None):
            depth, j, qq = 0, i + 1, None
            while j < n:
                c = cmd[j]
                if qq:
                    if c == qq:
                        qq = None
                elif c in '\'"':
                    qq = c
                elif c == '(':
                    depth += 1
                elif c == ')':
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            inner = cmd[i + 2:j]
            nested.append(('shell', inner))
            out.append('$__tmp__' if re.match(r'\s*mktemp\b', inner) else '$__sub__')
            i = j + 1
            continue
        if ch == '`' and not ps:
            j = cmd.find('`', i + 1)
            j = n if j < 0 else j
            nested.append(('shell', cmd[i + 1:j]))
            out.append('$__sub__')
            i = j + 1
            continue
        if q == '"':
            if ch == '"':
                q = None
            out.append(ch)
            i += 1
            continue
        if ch in '\'"':
            q = ch
            out.append(ch)
            i += 1
            continue
        if ch == '(' and cmd.startswith('((', i) and not ps:   # arithmetic: a `<<` in it is a shift, no heredoc
            j = cmd.find('))', i + 2)
            j = n if j < 0 else j + 2
            out.append(cmd[i:j])
            i = j
            continue
        if ch == '#' and (i == 0 or cmd[i - 1] in ' \t\n;&|('):
            j = cmd.find('\n', i)
            j = n if j < 0 else j
            out.append(cmd[i:j])
            i = j
            continue
        if ch == '<' and not ps and cmd.startswith('<<', i) and not cmd.startswith('<<<', i):
            m = re.compile(r'<<(-?)[ \t]*(?:\'([^\'\n]*)\'|"([^"\n]*)"|\\?([^\s;&|<>()\'"]+))').match(cmd, i)
            if m:
                word = [g for g in m.group(2, 3, 4) if g is not None][0]
                pend.append((m.group(1) == '-', word))
                out.append(cmd[i:m.end()])
                i = m.end()
                continue
        if ch == '\n':
            out.append(ch)
            line = cmd[line_start:i]
            i += 1
            if pend:
                words = [prog_name(w.strip('\'"')) for w in re.split(r'[\s;&|()<>]+', line) if w]
                kind = 'shell' if any(w in SHELLS or w in PWSH or w in ('eval', 'source', 'xargs') for w in words) \
                    else 'interp' if any(re.sub(r'[\d.]+$', '', w) in INTERPRETERS for w in words) else 'data'
                for strip, word in pend:
                    body = []
                    while i < n:
                        j = cmd.find('\n', i)
                        j = n if j < 0 else j
                        l = cmd[i:j]
                        i = j + 1
                        if (l.lstrip('\t') if strip else l).rstrip('\r') == word:
                            break
                        body.append(l)
                    nested.append((kind, '\n'.join(body)))
                pend = []
            line_start = i
            continue
        out.append(ch)
        i += 1
    return ''.join(out), nested


class Where:
    """The directory a subagent's command stands in (each `cd` followed), None once it cannot be read."""
    def __init__(self, cwd, cmd=''):
        self.cwd, self.abs, self._root = cwd, os.path.normpath(cwd), False
        self.cmd, self.start, self.near = cmd, self.abs, {}   # the whole command, for near()

    def root(self):
        if self._root is False:
            top = git(self.cwd, 'rev-parse', '--show-toplevel')
            self._root = top.strip().replace('\\', '/').rstrip('/').casefold() if top and top.strip() else None
        return self._root

    def join(self, d, word, vars):
        c = expand(word, vars)
        if d is None or len(c) != 1 or UNKNOWN in c[0] or GLOB.search(c[0]) or c[0] in ('', '-') or \
                c[0].startswith('~'):
            return None
        return os.path.normpath(os.path.join(d, c[0]))

    def rel(self, d):
        """The directory as a path under the repository root (posix, any case), None when outside or unknown.
        git names the root with links resolved (/var -> /private/var on macOS), so a directory reached through a
        link is also tried resolved."""
        r = self.root()
        if d is None or r is None:
            return None
        forms = [d]
        try:
            forms.append(os.path.realpath(d))
        except (OSError, ValueError):
            pass
        for q in forms:
            p = q.replace('\\', '/').rstrip('/').casefold()
            if p == r:
                return ''
            if p.startswith(r + '/'):
                return p[len(r) + 1:]
        return None


def strip_wrappers(seg):
    """The index of the program word, after keywords, assignments and wrapper commands."""
    i = 0
    while i < len(seg):
        w = seg[i]
        pn = prog_name(w)
        if w in KEYWORDS or (ASSIGN.match(w) and not w.startswith('$')):
            i += 1
            if w in ('time', 'command', 'exec', 'nohup', 'builtin'):   # their options (`time -p`, `exec -a x`)
                while i < len(seg) and seg[i].startswith('-') and seg[i] != '-':
                    i += 2 if (w == 'exec' and seg[i] == '-a') else 1
                    if seg[i - 1] == '--':
                        break
            continue
        if pn in WRAPPERS:
            i += 1
            while i < len(seg) and seg[i].startswith('-') and seg[i] != '-':
                o = seg[i]
                i += 1
                if o == '--':
                    break
                if not o.startswith('--') and len(o) == 2 and o[1] in WRAPPERS[pn]:
                    i += 1
            if pn in ('timeout', 'gtimeout') and i < len(seg):
                i += 1   # the duration
            continue
        break
    return i


def collect_vars(segs, vars):
    """Each variable an assignment or a `for` list of the command sets, with every value it may take."""
    def add(name, vals):
        vars.setdefault(name, [])
        vars[name] = (vars[name] + [v for v in vals if v not in vars[name]])[:64]
    for seg in segs:
        k = 0
        if seg and seg[0] == 'for' and len(seg) > 2 and seg[2] == 'in':
            vals = []
            for w in seg[3:]:
                vals.extend(expand(w, vars))
            add(seg[1], vals or [UNKNOWN])
            continue
        if len(seg) >= 3 and seg[0].startswith('$') and seg[1] == '=':   # PowerShell: $h = "..."
            add(seg[0][1:], expand(seg[2], vars))
            continue
        if seg and seg[0] in ('export', 'local', 'declare', 'readonly', 'typeset'):
            k = 1
            while k < len(seg) and seg[k].startswith('-'):
                k += 1
        while k < len(seg):
            m = ASSIGN.match(seg[k])
            if not m:
                break
            add(m.group(1), expand(m.group(2), vars))
            k += 1
    return vars


def redirect_targets(words):
    out = []
    for k, w in enumerate(words):
        if re.match(r'^(?:\d*|&|\*)>{1,2}$', w):
            if k + 1 < len(words):
                out.append(words[k + 1])
            continue
        if not re.search(r'\s', w):
            m = re.search(r'>{1,2}([^>&][^>]*)$', w)
            if m:
                out.append(m.group(1))
    return out


def written(pn, rest, vars, where, d):
    """The words program pn, given the words rest, may write as files (a spec folder it writes into reads as
    its plan.md), plus True when it is an interpreter beside a plan.md."""
    args = [w for w in rest if not w.startswith('-') or w == '-']
    out = []
    if pn not in OUT_OPT_READERS and pn not in SHELLS:
        for k, w in enumerate(rest):   # an option naming the output file, for any program
            m = re.match(r'^(?:-o|-O|--output(?:-document|-file)?)(=?)(.*)$', w, re.S)
            if m:
                out.append(m.group(2) if (m.group(1) or m.group(2)) else (rest[k + 1] if k + 1 < len(rest) else ''))
    inplace = any(re.match(r'^(-[a-zA-Z]*i\S*|--in-place\S*)$', w) for w in rest)
    if pn in ARG_WRITERS or (pn in INPLACE and inplace):
        out += args
    elif pn in COPIERS:
        if any(w == '-t' or w.startswith('--target-directory') for w in rest):
            out += args
        elif args:
            last = args[-1]
            out.append(last)
            full = where.join(d, last, vars)
            if last.endswith(('/', '\\', '.')) or full is None or os.path.isdir(full):
                out += [base(a) for a in args[:-1]]
                if spec_dir(last, vars, d) and any(UNKNOWN in c or GLOB.search(base(c)) or c.endswith(('/.', '\\.'))
                                                   for a in args[:-1] for c in expand(a, vars)):
                    out.append(last.rstrip('/\\') + '/plan.md')
    elif pn == 'dd':
        out += [w[3:] for w in rest if w.startswith('of=')]
    elif pn in EXTRACTORS:   # the folder it unpacks into
        for k, w in enumerate(rest):
            m = re.match(r'^(?:-C|-d|--directory|-o)(=?)(.*)$', w, re.S)
            if m:
                v = m.group(2) if (m.group(1) or m.group(2)) else (rest[k + 1] if k + 1 < len(rest) else '')
                if v and spec_dir(v, vars, d):
                    out.append(v.rstrip('/\\') + '/plan.md')
    elif re.sub(r'[\d.]+$', '', pn) in INTERPRETERS and any(
            names_plan(w, vars) if re.search(r'\s', w) else hits(w, vars, d, 'plan.md') for w in rest):
        return out, True
    return out, False


def covers(spec, vars, where, d):
    """The spelling of a pathspec that may cover the acceptance record, else None."""
    rel = where.rel(d)
    for c in expand(spec, vars):
        s = c.replace('\\', '/').replace(UNKNOWN, '*')
        top = False
        if s.startswith(':'):
            m = re.match(r':(\([^)]*\)|[/!^]*)', s)
            magic = m.group(1)
            if '!' in magic or '^' in magic or 'exclude' in magic:
                continue
            top = '/' in magic or 'top' in magic
            s = s[m.end():]
        s = s.casefold()
        r = where.root()
        if s.startswith('/') or re.match(r'^[a-z]:/', s):
            if r and (s.rstrip('/') == r or s.startswith(r + '/')):
                p, recs = s[len(r) + 1:] or '.', [RECORD]
            else:
                p, recs = s, [RECORD]
                if GLOB.search(s) or any(s.rstrip('/').endswith('/' + x) for x in ('memory', 'memory/stats', RECORD)):
                    return spec
                continue
        elif top or rel is not None:
            p, recs = posixpath.normpath(posixpath.join('' if top else rel, s or '.')), [RECORD]
        else:   # the directory cannot be read: the record as seen from any folder on its way
            p, recs = posixpath.normpath(s or '.'), [RECORD, 'stats/human.jsonl', 'human.jsonl']
        for rec in recs:
            pre = [rec[:i] for i in range(len(rec)) if rec[i] == '/'] + [rec]
            if p in ('.', '') or rec.startswith(p.rstrip('/') + '/') or any(fnmatch.fnmatchcase(x, p) for x in pre):
                return spec
    return None


def judge_git(rest, vars, ps, depth, where, d, text):
    aliases, j = {}, 0
    while j < len(rest):
        o = rest[j]
        if o == '-C':
            d = where.join(d, rest[j + 1] if j + 1 < len(rest) else '', vars)
            j += 2
            continue
        if o == '-c':
            m = re.match(r'alias\.([^=]+)=(.*)$', rest[j + 1] if j + 1 < len(rest) else '', re.S | re.I)
            if m:
                aliases[m.group(1).casefold()] = m.group(2)
            j += 2
            continue
        if o in ('--git-dir', '--work-tree', '--namespace', '--super-prefix', '--config-env', '--exec-path',
                 '--attr-source', '--list-cmds'):
            d = None if o in ('--git-dir', '--work-tree') else d
            j += 2
            continue
        if o.startswith(('--git-dir=', '--work-tree=')):
            d = None
        if o.startswith('-'):
            j += 1
            continue
        break
    if j >= len(rest):
        return None
    verb, args = rest[j], rest[j + 1:]
    chain = [verb]
    for _ in range(8):   # an alias of an alias is followed too
        if verb.casefold() not in aliases:
            break
        val = aliases.pop(verb.casefold())
        if val.startswith('!'):
            return shell_judge(val[1:], ps, where, depth + 1, vars)
        words = val.split()
        verb, args = (words[0] if words else ''), words[1:] + args
        chain.append(verb)
    named = {c.casefold() for c in chain[:-1]}
    if verb.casefold() in aliases or (verb.casefold() in named and verb.casefold() != chain[-2].casefold()):
        return ALIAS_CHAIN % ' -> '.join(chain)   # a longer chain, or a cycle: what git runs is not known
    vc = expand(verb, vars)
    if any(globmatch('add', v) or globmatch('stage', v) for v in vc):
        why = git_add(args, vars, where, d)
        if why:
            return GIT_RECORD % ('add', why)
    if any(globmatch('commit', v) for v in vc):
        return git_commit(args, vars, where, d, text)
    return None


def git_add(args, vars, where, d):
    whole, specs, after = False, [], False
    for k, a in enumerate(args):
        if after or not a.startswith('-') or a == '-':
            specs.append(a)
        elif a == '--':
            after = True
        elif a in ('-n', '--dry-run'):
            return None
        elif a in ('-A', '--all', '-u', '--update', '--no-ignore-removal'):
            whole = True
        elif a.startswith('--pathspec-from-file'):
            return 'a pathspec file'
        elif not a.startswith('--'):
            if 'n' in a[1:]:
                return None
            whole = whole or 'A' in a[1:] or 'u' in a[1:]
    for s in specs:
        if covers(s, vars, where, d):
            return 'the pathspec %s' % s
    if whole and not specs:
        return '-A or -u with no pathspec'
    return None


def git_commit(args, vars, where, d, text):
    msgs, files, specs, allf, after, k = [], [], [], False, False, 0
    while k < len(args):
        a = args[k]
        k += 1
        if after or not a.startswith('-') or a == '-':
            specs.append(a)
            continue
        if a == '--':
            after = True
            continue
        if a.startswith('--'):
            name, eq, val = a.partition('=')
            if name == '--all':
                allf = True
            elif name in ('--message', '--file', '--reuse-message', '--reedit-message', '--template', '--author',
                          '--date', '--fixup', '--squash', '--trailer', '--cleanup', '--pathspec-from-file'):
                if not eq:
                    val = args[k] if k < len(args) else ''
                    k += 1
                if name == '--message':
                    msgs.append(val)
                elif name in ('--file', '--template'):
                    files.append(val)
                elif name == '--pathspec-from-file':
                    return GIT_RECORD % ('commit', 'a pathspec file')
            continue
        p = 1
        while p < len(a):
            ch = a[p]
            p += 1
            if ch == 'a':
                allf = True
            elif ch in 'mFCct':
                if p < len(a):
                    val = a[p:]
                else:
                    val = args[k] if k < len(args) else ''
                    k += 1
                p = len(a)
                if ch == 'm':
                    msgs.append(val)
                elif ch in 'Ft':
                    files.append(val)
            elif ch == 'S':
                p = len(a)
    if allf:
        return GIT_RECORD % ('commit', '-a')
    for s in specs:
        if covers(s, vars, where, d):
            return GIT_RECORD % ('commit', 'the pathspec %s' % s)
    for m in msgs:
        for c in expand(m, vars):
            if UNKNOWN in c or VERDICT_RE.search(c):
                return COMMIT_VERDICT % ('the message %s' % m)
    for f in files:
        full = where.join(d, f, vars)
        try:
            with open(full, encoding='utf-8', errors='replace') as fh:
                if VERDICT_RE.search(fh.read()):
                    return COMMIT_VERDICT % ('the message file %s' % f)
        except (OSError, TypeError):
            pass
    if VERDICT_RE.search(re.sub(r'[\'"\\`]', '', text)):
        return COMMIT_VERDICT % 'a verdict word in the command text'
    return None


def judge_script(script, args, vars):
    cands = expand(script, vars)
    argc = [expand(a, vars) for a in args]
    if SCRIPT_ONLY:   # the main session: what the command spells or sets, not a value from outside it
        cands = [c for c in cands if UNKNOWN not in c]
        argc = [[x for x in a if UNKNOWN not in x] for a in argc]
    if may_be('human-check.sh', cands):
        a0 = argc[0] if argc else []
        if not (len(a0) == 1 and a0[0] in ('--check', '--show')):
            for a in argc:
                if any(globmatch(v, x) for x in a for v in ('ACCEPTED', 'REJECTED')):
                    return SCRIPT_WORD % ('human-check.sh with a verdict', ' '.join([script] + args))
    if may_be('cycle.sh', cands) and argc:
        if any(globmatch('briefed', x) for x in argc[0]) and \
                any(globmatch('--go', x) for a in argc[1:] for x in a):
            return SCRIPT_WORD % ('cycle.sh briefed --go', ' '.join([script] + args))
    return None


def find_words(seg, i, vars, where, d):
    """For a `find`, the segment with each `{}` read as `$__find__`, and vars giving that word the names find
    may hand it: its -name / -path patterns, plus plan.md when a folder it searches may hold a spec folder and
    no pattern rules plan.md out."""
    if prog_name(seg[i]) != 'find' or '{}' not in seg:
        return seg, vars
    names, roots, k = [], [], i + 1
    while k < len(seg) and not seg[k].startswith(('-', '(', '!')):
        roots.append(seg[k])
        k += 1
    for j in range(k, len(seg) - 1):
        if seg[j] in ('-name', '-iname', '-path', '-ipath', '-wholename', '-iwholename'):
            names.append(base(seg[j + 1]) or '*')
    hold, r = False, where.root()
    for root in roots or ['.']:
        full = where.join(d, root, vars)
        rel = where.rel(full) if full is not None else None
        if full is None or r is None or (rel is not None and (
                rel in ('', 'docs', 'docs/specs') or rel.startswith('docs/specs/'))):
            hold = True
    if hold and (not names or any(globmatch('plan.md', n) for n in names)):
        names.append('plan.md')
    names = names or ['found-file']
    vars = dict(vars)
    vars['__find__'] = names
    return [('$__find__' if w == '{}' else w) for w in seg], vars


def judge_named(pn, word, rest, vars, ps, depth, where, text):
    """A deny reason for program pn (spelled `word`) run with the words rest, STOP when it runs nothing more."""
    d = where.abs
    targets, interp = written(pn, rest, vars, where, d) if not SCRIPT_ONLY else ([], False)
    if interp:
        return PLAN_WRITE % 'an interpreter beside a plan.md'
    for t in targets:
        why = target_why(t, vars, where, d)
        if why:
            return why
    if pn == 'git':
        return None if SCRIPT_ONLY else judge_git(rest, vars, ps, depth, where, d, text)
    code = None
    if pn in SHELLS:
        j = 0
        while j < len(rest):
            o = rest[j]
            if o.startswith('<<<'):
                code = o[3:] or (rest[j + 1] if j + 1 < len(rest) else '')
                break
            if not o.startswith(('-', '+')) or o in ('-', '--'):
                break
            j += 1
            if o.startswith('--'):
                j += o in ('--rcfile', '--init-file')
                continue
            if o[0] == '-' and 'n' in o[1:]:
                return STOP   # a syntax check runs nothing
            if 'o' in o[1:] or 'O' in o[1:]:
                j += 1
            if 'c' in o[1:]:
                code = rest[j] if j < len(rest) else ''
                break
    elif pn in PWSH:
        for j, o in enumerate(rest):
            ol = o.casefold()
            if ol in ('-command', '-c', '-commandwithargs', '-cwa'):
                code = ' '.join(rest[j + 1:])
                break
            if ol in ('-encodedcommand', '-e', '-ec', '-enc'):
                return SCRIPT_WORD % ('a guarded script', 'an encoded command')
    elif pn in ('eval', 'invoke-expression', 'iex'):
        code = ' '.join(rest)
    elif pn == 'env':   # env -S splits its value into a command
        for j, o in enumerate(rest):
            m = re.match(r'^(?:-S|--split-string)(=?)(.*)$', o, re.S)
            if m:
                code = m.group(2) if (m.group(1) or m.group(2)) else (rest[j + 1] if j + 1 < len(rest) else '')
                break
            if not o.startswith('-'):
                break
    elif pn == 'xargs':
        j = 0
        while j < len(rest) and rest[j].startswith('-'):
            o = rest[j]
            j += 1
            if o == '--':
                break
            if len(o) == 2 and o[1] in 'nILPdEsa':
                j += 1
        return (judge_seg(rest[j:] + ['$__xargs__'], vars, ps, depth, where, text) or STOP) if rest[j:] else STOP
    if code is not None:
        if re.match(r'^\$\{?[A-Za-z_]\w*\}?$', code) and code.strip('${}') not in vars and not SCRIPT_ONLY:
            return SCRIPT_WORD % ('a guarded script', 'a command held in a variable')
        texts = expand(code, vars) if re.match(r'^\$\{?[A-Za-z_]\w*\}?$', code) else [code]
        for t in texts:
            why = shell_judge(t, ps, where, depth + 1, vars)
            if why:
                return why
    return None


def judge_prog(word, rest, vars, ps, depth, where, text, first):
    """A deny reason for the word run as a program with the words rest, STOP when the segment runs nothing more.
    A value the word may take with a space in it is read as a command; a word the hook cannot read (a glob, an
    unknown value) is judged as each guarded program it may stand for; behind another program word only as one
    that runs or changes a file in place, not as a writer of a plain argument (`grep "$p" <plan>` is a read)."""
    why = judge_script(word, rest, vars)
    if why:
        return why
    for c in expand(word, vars):
        if '$' in word and re.search(r'\s', c.replace(UNKNOWN, '')):   # word splitting of a held command
            why = shell_judge(' '.join([c.replace(UNKNOWN, '$__sub__')] + rest), ps, where, depth + 1, vars)
        elif UNKNOWN in c or GLOB.search(base(c)):
            if not first and UNKNOWN not in c:
                continue
            names = SHELLS | PWSH | MAY_RUN | INPLACE | (
                ARG_WRITERS | COPIERS | EXTRACTORS | INTERPRETERS if first else set())
            why = None
            for n in sorted(names):
                if globmatch(n, base(c)):
                    why = judge_named(n, word, rest, vars, ps, depth, where, text)
                    if why and why != STOP:
                        return why
            why = None
        else:
            why = judge_named(prog_name(c), word, rest, vars, ps, depth, where, text)
        if why:
            return why
    return None


def judge_seg(seg, vars, ps, depth, where, text):
    """A deny reason for one simple command: its redirects, then every word that may be a program word (the
    first, and each later one unless the first is a program that reads its words as data)."""
    for t in ([] if SCRIPT_ONLY else redirect_targets(seg)):
        why = target_why(t, vars, where, where.abs)
        if why:
            return why
    i = strip_wrappers(seg)
    pn = prog_name(seg[i]) if i < len(seg) else None
    if pn in ('for', 'case', 'function', 'select'):
        return None
    if pn in ('cd', 'pushd', 'chdir', 'set-location', 'sl', 'push-location'):
        ops = [w for w in seg[i + 1:] if not w.startswith('-')]
        where.abs = where.join(where.abs, ops[0], vars) if ops else None
        return None
    if pn is not None:
        seg, vars = find_words(seg, i, vars, where, where.abs)
    for k in range(len(seg)):   # the wrappers before the program word too (`env -S "<command>"`)
        w = seg[k]
        if k > i and pn in DATA_PROGS:
            break
        if k != i and (w.startswith(('-', '+')) or (k < i and (w in KEYWORDS or ASSIGN.match(w)))):
            continue
        why = judge_prog(w, seg[k + 1:], vars, ps, depth, where, text, k == i)
        if why == STOP:
            return None
        if why:
            return why
    return None


def shell_judge(cmd, ps, where, depth=0, outer=None):
    """A deny reason for a subagent's shell command, else None."""
    if depth > 4:
        return UNSPLIT
    text, nested = unwrap(cmd, ps)
    segs = split_segments(text.replace('>|', '>'), ps)
    if segs is None:
        return UNSPLIT
    vars = collect_vars(segs, dict(outer or {}))
    for seg in segs:
        why = judge_seg(seg, vars, ps, depth, where, cmd)
        if why:
            return why
    for kind, body in nested:
        if kind == 'shell':
            why = shell_judge(body, ps, where, depth + 1, vars)
        elif kind == 'interp' and not SCRIPT_ONLY and names_plan(body, vars):
            why = PLAN_WRITE % 'an interpreter fed a text naming plan.md'
        else:
            why = None
        if why:
            return why
    return None


def run_state(path, cwd):
    """True when the path, resolved, lies under a `.vulyk/state/` folder (any letter case; Windows drops a
    trailing dot or space and reads `name:stream` as the file)."""
    for _, parts in resolved(path, cwd):
        if any(parts[k] == '.vulyk' and parts[k + 1] == 'state' for k in range(len(parts) - 1)):
            return True
    return False


def subagent_judge(tool, ti, cwd):
    if tool in ('Edit', 'Write', 'MultiEdit'):
        path = ti.get('file_path')
        if isinstance(path, str) and path and run_state(path, cwd):
            return RUN_STATE % path
        return None
    cmd = ti.get('command')
    if tool in ('Bash', 'PowerShell') and isinstance(cmd, str):
        return shell_judge(cmd, tool == 'PowerShell', Where(cwd, cmd))
    return None


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
    global GUARDED, SCRIPT_ONLY
    try:
        data = json.loads(sys.stdin.buffer.read().decode('utf-8-sig', 'replace'))
    except Exception:
        sys.exit(0)
    if not isinstance(data, dict):
        sys.exit(0)
    tool = str(data.get('tool_name') or '')
    ti = data.get('tool_input') if isinstance(data.get('tool_input'), dict) else {}
    cwd = str(data.get('cwd') or os.environ.get('CLAUDE_PROJECT_DIR') or os.getcwd())
    sub = bool(data.get('agent_id'))
    if sub and tool in ('Bash', 'PowerShell', 'Edit', 'Write', 'MultiEdit'):
        GUARDED = True   # a subagent's call the hook cannot finish reading is refused
    if tool in ('Bash', 'PowerShell'):
        cmd = ti.get('command')
        acts = command_actions(cmd, tool == 'PowerShell', cwd) if isinstance(cmd, str) else []
    elif tool in ('Edit', 'Write', 'MultiEdit'):
        acts = file_actions(tool, ti, cwd)
    else:
        acts = []
    if sub and acts:
        deny(SUBAGENT)
    if sub and GUARDED:
        why = subagent_judge(tool, ti, cwd)
        if why:
            deny(why)
    if not sub and not acts and tool in ('Bash', 'PowerShell') and isinstance(cmd, str):
        SCRIPT_ONLY = True   # a guarded script run under another spelling: quotes, a pattern, a variable it sets
        why = shell_judge(cmd, tool == 'PowerShell', Where(cwd, cmd))
        SCRIPT_ONLY = False
        if why and why.startswith(SUBAGENT):
            deny(MAIN_SPELL + why[len(SUBAGENT):] + OWNER_CAN)
    if not acts:
        sys.exit(0)
    GUARDED = True
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
