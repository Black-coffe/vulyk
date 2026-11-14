#!/usr/bin/env bash
# PreToolUse hook (matcher Read|Grep|Glob|Bash|PowerShell): keeps a blind council seat inside its court
# (plan.md `## Contracts` C1 of audit-fixes-1113). It acts only when the input's agent_type is `council-opus`
# or `council-haiku`; any other agent and the main session pass untouched.
#   - Read, Grep, Glob: a path (Grep / Glob with no path: the call's cwd) that resolves outside
#     <project>/.vulyk/court/ is denied.
#   - Bash, PowerShell: a path argument that leaves the court is denied (each `cd` is followed). A word is a path
#     argument when it names an existing file or folder from the current folder, or when it starts with a drive,
#     /, ~ or .. and is an operand of a command that reads files (a redirect's target included). The script or
#     pattern of sed, awk, grep, rg and jq (their first word, or an -e value), every word of echo, printf, tr and
#     the like, and an option's value are operands of no such command, so a sed script (`/^## X/,/^## Y/p`), a tr
#     set or a quoted string that exists nowhere is no path; a URL is none. Allowed outside the court: <project>/.vulyk/reports/ (where the seat writes its
#     report) and system locations (/dev, /tmp, /usr, /bin, /etc, /opt, /proc, the Windows system folders).
#   - A git command that reads objects (log, show, diff, grep, blame, cat-file, ls-tree, archive, rev-list,
#     reflog, shortlog, whatchanged, format-patch, checkout, restore, stash, ...) is denied unless it names
#     pathspecs and every one lies outside docs/specs/ (a `<rev>:<path>` counts by its path).
#   - A command the hook cannot read (open quotes, a path operand or `cd` built from a variable or a
#     substitution) is denied; a `$` inside a script, a pattern or an echo word is no path. A heredoc body is text (the seat's report), not commands.
# Not covered, on purpose: a command run from outside the court that names no path (`ls`, `grep -r x` with
# no folder), what a program opens on its own (a script, an interpreter's -c code, a heredoc fed to a
# shell), a word that exists nowhere outside a reading command's operands (a script, a pattern, an option's
# value), and the temp folder.
# `record-seat` still checks the report itself.
# <project> is $CLAUDE_PROJECT_DIR, else the input cwd cut at /.vulyk/court/.
# No Python: a blind seat's every call is denied (the court cannot be checked); other callers pass.
# `--check <file>`: reads hook input from <file>; exit 1 on a deny (the reason on stdout), 0 otherwise, also for
# a file that is no hook input.
# The Python half lives below the `exit`, inside a no-op heredoc, as in git-guard.sh.
if [ "${1:-}" = "--check" ]; then
  [ -f "${2:-}" ] || exit 0
  IFS= read -r -d '' IN < "$2"
else
  IFS= read -r -d '' IN   # a builtin: another agent's call starts no process
fi
case "$IN" in *council-opus*|*council-haiku*) ;; *) exit 0 ;; esac
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
# No Python answered: a blind seat is denied, anyone else passes.
case "$IN" in
  *'"agent_type":"council-opus"'*|*'"agent_type": "council-opus"'*|*'"agent_type":"council-haiku"'*|*'"agent_type": "council-haiku"'*) ;;
  *) exit 0 ;;
esac
printf '%s\n' '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "VULYK court guard: no Python 3 answered ($VULYK_PY, python3, python, py), so this hook cannot check that a blind seat stays inside its court. Report the round as N/A - why: environment: no Python for the court guard."}}'
[ "${1:-}" = "--check" ] && exit 1
exit 0

: <<'PYTHON'
#<py>
import json, os, re, shlex, sys

CHECK = len(sys.argv) > 1 and sys.argv[1] == '--check'
SEATS = ('council-opus', 'council-haiku')
SEP = {';', '&&', '||', '|', '&', '\n', '(', ')', '{', '}'}
READS = {'log', 'show', 'diff', 'diff-tree', 'diff-index', 'diff-files', 'grep', 'blame', 'annotate', 'cat-file',
         'ls-tree', 'archive', 'rev-list', 'reflog', 'shortlog', 'whatchanged', 'format-patch', 'range-diff',
         'show-branch', 'difftool', 'checkout', 'restore', 'stash', 'bundle', 'fast-export', 'notes', 'cherry',
         'switch', 'worktree'}
SYSTEM = ('/dev/', '/tmp/', '/usr/', '/bin/', '/etc/', '/opt/', '/proc/', '/mingw64/')
CD = ('cd', 'chdir', 'pushd', 'popd', 'set-location', 'sl', 'push-location', 'pop-location')
# Commands whose first word (or an -e value) is a script or a pattern, not a file; and their options that take
# a script, a file, or another value.
SCRIPTED = ('sed', 'gsed', 'awk', 'gawk', 'mawk', 'grep', 'egrep', 'fgrep', 'rg', 'jq')
SCRIPT_OPT = ('-e', '--expression', '--regexp')
FILE_OPT = ('-f', '--file', '--from-file')
VALUE_OPT = ('-v', '-F', '-m', '-A', '-B', '-C', '-g', '-t', '-T', '--glob', '--type', '--arg', '--argjson',
             '--max-count', '-d')
# Commands that read no file their words name (echo, printf, tr, ...): a word is a path only when it exists.
NO_FILES = ('echo', 'printf', 'tr', 'expr', 'test', '[', '[[', 'seq', 'date', 'sleep', 'true', 'false', 'export',
            'set', 'unset', 'write-output', 'write-host', 'basename', 'dirname')
TAIL = (' Work only inside COURT (cd into it first); a read outside it is a BREACH.')


def deny(reason):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                             "permissionDecision": "deny",
                                             "permissionDecisionReason": reason}}))
    sys.exit(0)


def native(p):
    """A Git Bash /e/x path as e:/x on Windows; ~ expanded."""
    p = os.path.expanduser(p)
    m = re.match(r'^/([A-Za-z])(/.*)?$', p)
    if os.name == 'nt' and m:
        p = m.group(1) + ':' + (m.group(2) or '/')
    return p


def full(p, here):
    return os.path.normcase(os.path.abspath(os.path.join(here, native(p))))


def under(p, root):
    root = root.rstrip('/\\')
    return p == root or p.startswith(root + os.sep) or p.startswith(root + '/')


def quoted(line, pos):
    """True when pos sits inside a '...' or "..." string of line."""
    q = None
    for ch in line[:pos]:
        if q is None and ch in '\'"':
            q = ch
        elif ch == q:
            q = None
    return q is not None


def drop_heredocs(cmd):
    """The command with every heredoc body cut: its lines are text (the seat's report), not commands."""
    lines, out, i = cmd.split('\n'), [], 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        i += 1
        for m in re.finditer(r'(?<!<)<<(?!<)-?[ \t]*([\'"]?)([A-Za-z_][A-Za-z0-9_]*)\1', line):
            if quoted(line, m.start()):
                continue
            while i < len(lines) and lines[i].strip() != m.group(2):
                i += 1
            i += 1
    return '\n'.join(out)


def split_segments(cmd, powershell):
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


def main():
    try:
        data = json.loads(sys.stdin.buffer.read().decode('utf-8-sig', 'replace'))
    except Exception:
        sys.exit(0)
    if not isinstance(data, dict) or data.get('agent_type') not in SEATS:
        sys.exit(0)
    tool = str(data.get('tool_name') or '')
    ti = data.get('tool_input') if isinstance(data.get('tool_input'), dict) else {}
    cwd = str(data.get('cwd') or os.getcwd())
    project = os.environ.get('CLAUDE_PROJECT_DIR') or ''
    if not project:
        m = re.search(r'[/\\]\.vulyk[/\\]court([/\\]|$)', cwd)
        project = cwd[:m.start()] if m else cwd
    project = full(project, cwd)
    court = os.path.join(project, '.vulyk', 'court')
    reports = os.path.join(project, '.vulyk', 'reports')
    seat = data.get('agent_type')

    def outside(p):
        return not under(p, court)

    if tool in ('Read', 'Grep', 'Glob'):
        paths = []
        for key in ('file_path', 'path', 'notebook_path'):
            v = ti.get(key)
            if isinstance(v, str) and v:
                paths.append(v)
        if tool in ('Grep', 'Glob') and not ti.get('path'):
            paths.append(cwd)
        pat = ti.get('pattern')
        if tool == 'Glob' and isinstance(pat, str) and re.match(r'^([/\\~]|[A-Za-z]:|\.\.)', pat):
            paths.append(re.split(r'[*?\[{]', pat, 1)[0] or pat)
        for p in paths:
            if outside(full(p, cwd)):
                deny('VULYK court guard: %s of %s by the %s seat - it lies outside the court.%s'
                     % (tool, p, seat, TAIL))
        sys.exit(0)
    if tool not in ('Bash', 'PowerShell'):
        sys.exit(0)
    cmd = ti.get('command')
    if not isinstance(cmd, str):
        sys.exit(0)
    segs = split_segments(drop_heredocs(cmd), tool == 'PowerShell')
    if segs is None:
        deny('VULYK court guard: this command cannot be read (its quotes do not close), and a blind seat may '
             'run only commands the hook can check.' + TAIL)

    def allowed(tok, p):
        return not outside(p) or under(p, reports) or tok.replace('\\', '/').startswith(SYSTEM) or \
            tok in ('/dev/null', '/tmp', 'NUL', '$null') or \
            re.match(r'^[A-Za-z]:[/\\](windows|program files)', tok, re.I) is not None

    def check_path(tok, here, operand):
        """Deny when the word is a path argument leaving the court; return its full path or None. A word is a
        path when it names an existing file or folder, or, as an operand of a command that reads files, starts
        with a drive, /, ~ or .. (a script, a pattern, a tr set or a quoted string is none)."""
        t = re.sub(r'^\d*[<>]+&?', '', tok)
        if t != tok:
            operand = True                              # `<file`, `>file`: the redirect's own target
        if t.startswith('-') and '=' in t:
            t, operand = t.split('=', 1)[1], False      # an option's value: a path only when it exists
        if not t or t.startswith('-') or '://' in t or t in ('$null',):
            return None
        looks = re.match(r'^(~|/|[A-Za-z]:([/\\]|$)|\.\.([/\\]|$))', t) is not None
        if re.search(r'[$`]', t):
            if operand and (looks or (t.startswith(('$', '"$', '`')) and re.search(r'[/\\]', t))):
                deny('VULYK court guard: the path `%s` is built from a variable or a substitution, so the hook '
                     'cannot tell whether it leaves the court.%s' % (t, TAIL))
            return None
        try:
            exists = os.path.exists(os.path.join(here, native(t)))
        except (ValueError, OSError):
            exists = False
        if not exists and not (looks and operand):
            return None
        p = full(t, here)
        if not allowed(t, p):
            deny('VULYK court guard: `%s` names %s, outside the court, in a blind seat\'s command.%s'
                 % (' '.join(seg), t, TAIL))
        return p

    def operands(seg, i):
        """(word, operand) for each word after the command word seg[i]: False for the script or pattern of
        sed, awk, grep, rg and jq (their first word, or an -e value) and for every word of a command that reads
        no files (echo, printf, tr, ...); a redirect's target is an operand."""
        name = os.path.basename(seg[i].replace('\\', '/')).lower() if i < len(seg) else ''
        name = name[:-4] if name.endswith('.exe') else name
        out, script, skip, redirect = [], name not in SCRIPTED, None, False
        for k in range(i + 1, len(seg)):
            w = seg[k]
            if redirect or w in ('<', '>', '>>', '<<<') or re.match(r'^\d*[<>]+&?$', w):
                out.append((w, redirect))
                redirect = not redirect and w != '<<<'
                continue
            if name in NO_FILES:
                out.append((w, False))
            elif skip is not None:
                out.append((w, skip))
                skip = None
            elif name in SCRIPTED and w in SCRIPT_OPT:
                out.append((w, False))
                skip, script = False, True
            elif name in SCRIPTED and w in FILE_OPT:
                out.append((w, False))
                skip = True
            elif name in SCRIPTED and w in VALUE_OPT:
                out.append((w, False))
                skip = False
            elif w.startswith('-'):
                out.append((w, False))
            elif not script:
                out.append((w, False))
                script = True
            else:
                out.append((w, True))
        return out

    def rel_hit(rel):
        """True when a pathspec relative to the repo top is docs/specs, inside it, or above it."""
        rel = re.sub(r'^(\./)+', '', rel.replace('\\', '/')).strip('/').lower()
        if rel in ('', '.'):
            return True
        stop = re.split(r'[*?\[]', rel, 1)
        if len(stop) > 1:                              # a glob: whatever it may reach from its fixed prefix
            fixed = stop[0].rsplit('/', 1)[0] if '/' in stop[0] else ''
            return fixed == '' or 'docs/specs'.startswith(fixed) or fixed.startswith('docs/specs')
        return rel in ('docs', 'docs/specs') or rel.startswith('docs/specs/')

    def spec_hit(p):
        """rel_hit for a full path: relative to its court round, else to the project."""
        if under(p, court):
            return rel_hit('/'.join(os.path.relpath(p, court).replace('\\', '/').split('/')[2:]))
        if under(p, project):
            return rel_hit(os.path.relpath(p, project))
        return False

    here = cwd
    for seg in segs:
        name = seg[0].lower()
        if name in CD:
            if name in ('popd', 'pop-location') or '-' in seg[1:]:
                deny('VULYK court guard: `%s` moves to a folder the hook cannot name.%s' % (' '.join(seg), TAIL))
            args = [a for a in seg[1:] if not a.startswith('-')]
            if not args:
                deny('VULYK court guard: `%s` moves to the home folder, outside the court.%s' % (' '.join(seg), TAIL))
            if re.search(r'[$`%]', args[0]):
                deny('VULYK court guard: `%s` moves to a folder built from a variable or a substitution.%s'
                     % (' '.join(seg), TAIL))
            p = full(args[0], here)
            if outside(p):
                deny('VULYK court guard: `%s` leaves the court.%s' % (' '.join(seg), TAIL))
            here = p
            continue
        i = 0
        while i < len(seg) and (re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', seg[i]) or seg[i] in ('command', 'exec', 'time', '&')
                                or os.path.basename(seg[i].replace('\\', '/')).lower() in ('env', 'env.exe')):
            i += 1
        for k in range(1, min(i, len(seg))):
            check_path(seg[k], here, False)             # assignments and env's words: a path only when it exists
        for tok, operand in operands(seg, i):
            check_path(tok, here, operand)
        if i >= len(seg) or os.path.basename(seg[i].replace('\\', '/')).lower() not in ('git', 'git.exe'):
            continue
        i += 1
        base = here
        while i < len(seg) and seg[i].startswith('-'):
            if seg[i] in ('-C', '-c', '--git-dir', '--work-tree', '--namespace') and i + 1 < len(seg):
                if seg[i] == '-C':
                    base = full(seg[i + 1], base)
                i += 2
            else:
                i += 1
        if i >= len(seg) or seg[i] not in READS:
            continue
        verb, args = seg[i], seg[i + 1:]
        cut = args.index('--') if '--' in args else len(args)
        hits, n = False, 0
        for k, a in enumerate(args):
            if k == cut or (k < cut and a.startswith('-')):
                continue
            if re.search(r'[$`]', a):
                hit = True
            elif a.startswith(':'):                     # a magic pathspec (:/x, :(top)x): from the repo top
                hit = rel_hit(re.sub(r'^:(\([^)]*\)|/)?', '', a))
            elif k < cut and ':' in a and not re.match(r'^[A-Za-z]:[/\\]', a):
                hit = rel_hit(a.split(':', 1)[1])       # <rev>:<path>, the path from the repo top
            elif k > cut:
                hit = spec_hit(full(a, base))
            else:                                       # before --: a path when it exists or has a slash
                try:
                    exists = os.path.exists(os.path.join(base, native(a)))
                except (ValueError, OSError):
                    exists = False
                if not (exists or '/' in a or '\\' in a):
                    continue                            # a revision or a pattern
                hit = spec_hit(full(a, base))
            n += 1
            hits = hits or hit
        shown = ' '.join(seg)
        if n == 0:
            deny('VULYK court guard: `%s` reads git objects with no pathspec, and the history holds the spec\'s '
                 'plan and stories. Name the paths outside docs/specs/ after `--`.%s' % (shown, TAIL))
        if hits:
            deny('VULYK court guard: `%s` reads docs/specs/ from git, which a blind seat may not see.%s'
                 % (shown, TAIL))
    sys.exit(0)


try:
    main()
except SystemExit:
    raise
except Exception as e:
    deny('VULYK court guard: the hook failed (%s), so this blind seat\'s call is refused.' % e.__class__.__name__)
PYTHON
