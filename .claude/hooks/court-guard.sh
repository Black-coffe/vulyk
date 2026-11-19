#!/usr/bin/env bash
# PreToolUse hook (matcher Read|Grep|Glob|Bash|PowerShell): keeps a blind council seat inside its court
# (plan.md `## Contracts` C1 of audit-fixes-1113, C2 of guards-1115). It acts only when the input's agent_type is
# `council-opus` or `council-haiku`; any other agent and the main session pass untouched.
#   - The seat's court is the round folder <project>/.vulyk/court/<slug>/<round>/ the call stands in (the input
#     cwd, then each `cd`); another round's court is denied. A call that stands in no court may name a court path
#     only while exactly one court exists; with more it is denied and told to work from inside its court.
#   - Every path is judged by its resolved form: links followed, `..` steps (also behind a folder or a wildcard),
#     letter case folded on Windows, a Git Bash spelling (/c/..., /tmp in any case) read as the Windows path, also
#     in the input cwd that relative paths start from.
#   - Read, Grep, Glob: a path (Grep / Glob with no path: the call's cwd; a Glob pattern that starts outside or
#     climbs with `..`) outside the court and <project>/.vulyk/reports/ is denied.
#   - Bash, PowerShell: a path argument that leaves the court is denied. A word is a path argument when it names
#     an existing file or folder from the current folder, or when it starts with a drive, /, ~ or .., or holds a
#     `..` step, and is an operand of a command that reads files: a redirect's target (glued to its word or not,
#     on any command), a value glued to a short option (`-o<path>`) or after `--opt=`, a `for` list, a file URL.
#     The script or pattern of sed, awk, grep, rg and jq (their first word, an -e value, or one glued to its
#     option), every word of echo, printf, tr and the like are none; a script file (`-f`, glued or not) is a path.
#     A variable set earlier in the same call is read as its value. Allowed outside the court:
#     <project>/.vulyk/reports/ (where the seat writes its report) and system locations (/dev, /tmp, /usr, /bin,
#     /etc, /opt, the Windows system folders), never one that resolves into the project, and never the main
#     session's working folder under the temp directory (a `claude*` entry of /tmp or of the temp folder).
#   - Commands are found in every command position: after `;`, `&&`, `||`, `|`, `&`, a newline, `(`, `{`, a
#     keyword (`!`, then, do, else, if, while, until), leading redirects and assignments, and the wrappers time,
#     command, exec, env, timeout, nice, nohup, setsid, stdbuf and xargs with their options; inside `$( )`,
#     backticks and `<( )` (quoted or not), and in the string given to eval or to `sh -c` (bash, dash, zsh, ...).
#     A program name built from a variable, a substitution, a brace or a wildcard is denied.
#   - `cd` is followed only where it surely takes effect; a cd that may not (a missing folder, after `||`, in a
#     pipe, a branch or a loop, in a subshell that ends) leaves every folder the call may stand in to be judged.
#     A cd with more than one folder or with a CDPATH is denied.
#   - git by an allowlist: `status`, `version` (or `--version`), `rev-parse` with its query options and plain
#     revisions, `ls-files` with its listing options; global options only `-C <dir>`, `--no-pager`, `-P`. Every
#     other verb (an alias and a low-level verb included), every other option, a `-c` setting, a GIT_* variable
#     and git fed words by xargs are denied, and a `<rev>:<path>` naming docs/specs/ is denied in every verb.
#   - A command the hook cannot read (open quotes or substitutions, a path operand or `cd` built from a
#     variable or a substitution it cannot resolve) is denied; a `$` inside a script, a pattern or an echo word is
#     no path. A heredoc body is text (the seat's report), not commands; a comment is cut where the shell cuts it.
# `record-seat` still checks the report itself.
# <project> is $CLAUDE_PROJECT_DIR, else the input cwd cut at /.vulyk/court/.
# No Python: a blind seat's every call is denied (the court cannot be checked); other callers pass.
# `--check <file>`: reads hook input from <file>; exit 1 on a deny (the reason on stdout), 0 otherwise, also for
# a file that is no hook input.
# The Python half lives below the `exit`, inside a no-op heredoc, as in git-guard.sh.
# This guard stops accidents and shortcuts of a cooperative agent, not an adversary. Left open, in general words:
#   - code handed to an interpreter on its command line (kept on purpose for seats: they measure with it), a
#     command string for a shell outside the sh family (PowerShell, cmd), and whatever a program opens or runs
#     on its own: a script file, a heredoc fed to a shell, a command another program runs for the seat;
#   - a path made at run time: read from a file or from input, printed by a command, held in a variable the call
#     does not set (a loop variable, `read`, the environment, an expansion with an operator) when its word shows
#     no folder step;
#   - a wildcard or brace word whose matches the hook does not expand (one that meets a link in the court);
#   - a command that names no path reads the folder it runs in, also when that folder is outside every court;
#   - a word that exists nowhere and is no reading command's operand (a script, a pattern, an echo word);
#   - which court a call that starts in no court enters by `cd`;
#   - a link that only the Git Bash layer knows, which Windows cannot resolve;
#   - refused although harmless (known over-denies, 0.55.0): a `case` statement, an arithmetic expansion that
#     holds a parenthesised group or a substitution, and a substitution after a `cd` into the court.
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
from urllib.parse import unquote

CHECK = len(sys.argv) > 1 and sys.argv[1] == '--check'
SEATS = ('council-opus', 'council-haiku')
SEP = {';', '&&', '||', '|', '&', '\n', '(', ')', '{', '}'}
# git for a seat: the verbs it may run, each with the options it may give (None: any option). A word that is no
# option is a pathspec (status, ls-files) or a revision (rev-parse); any `<rev>:<path>` into docs/specs/ is denied.
GIT_VERBS = {
    'status': None,
    'version': None,
    'rev-parse': ('--show-toplevel', '--show-prefix', '--show-cdup', '--git-dir', '--absolute-git-dir',
                  '--git-common-dir', '--is-inside-work-tree', '--is-inside-git-dir', '--is-bare-repository',
                  '--abbrev-ref', '--symbolic-full-name', '--short', '--verify', '-q', '--quiet'),
    'ls-files': ('-c', '--cached', '-d', '--deleted', '-m', '--modified', '-o', '--others', '-i', '--ignored',
                 '-s', '--stage', '-u', '--unmerged', '-k', '--killed', '-z', '-t', '-v', '-f', '--directory',
                 '--no-empty-directory', '--eol', '--deduplicate', '--exclude-standard', '--full-name',
                 '--error-unmatch', '--recurse-submodules', '--sparse'),
}
GIT_GLOBAL = ('--no-pager', '-P')
SYSTEM = ('/dev/', '/tmp/', '/usr/', '/bin/', '/etc/', '/opt/', '/mingw64/')
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
ASSIGN = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?\+?=')
# Words before a command that leave it the command: keywords, and wrappers that run the next word, each with
# (its options that take a value, those of them that name a file, the operands it takes before the command).
KEYWORDS = ('!', 'then', 'do', 'else', 'if', 'elif', 'while', 'until', 'coproc')
WRAP = {
    'time': ((), (), 0), 'command': ((), (), 0), 'builtin': ((), (), 0), 'nohup': ((), (), 0),
    'setsid': ((), (), 0), 'exec': (('-a',), (), 0),
    'env': (('-u', '--unset', '-C', '--chdir'), ('-C', '--chdir'), 0),
    'timeout': (('-s', '--signal', '-k', '--kill-after'), (), 1),
    'nice': (('-n', '--adjustment'), (), 0),
    'stdbuf': (('-i', '-o', '-e', '--input', '--output', '--error'), (), 0),
    'xargs': (('-I', '-L', '-n', '-P', '-s', '-d', '-E', '-a', '--arg-file', '--delimiter', '--max-args',
               '--max-procs', '--max-chars', '--replace', '--eof', '--max-lines'), ('-a', '--arg-file'), 0),
}
SHELLS = ('sh', 'bash', 'dash', 'zsh', 'ksh', 'mksh', 'ash')


def prog(w):
    """A command word's program name: its base name, lower case, without .exe."""
    n = os.path.basename(w.replace('\\', '/')).lower()
    return n[:-4] if n.endswith('.exe') else n


def deny(reason):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                             "permissionDecision": "deny",
                                             "permissionDecisionReason": reason}}))
    sys.exit(0)


def native(p):
    """A Git Bash /e/x path as e:/x and /tmp as the user temp folder on Windows; ~ expanded."""
    p = os.path.expanduser(p)
    if os.name != 'nt':
        return p
    m = re.match(r'^/([A-Za-z])(/.*)?$', p)
    if m:
        return m.group(1) + ':' + (m.group(2) or '/')
    temp = os.environ.get('TEMP') or os.environ.get('TMP')
    if temp and re.match(r'^/tmp(/|$)', p, re.I):           # Windows folds case: /TMP is /tmp
        return temp.rstrip('/\\') + p[4:]
    return p


def full(p, here):
    """The resolved path: links followed (realpath), case folded on Windows; a Git Bash cwd converted too."""
    j = os.path.join(native(here), native(p))
    try:
        return os.path.normcase(os.path.realpath(j))
    except (OSError, ValueError):
        return os.path.normcase(os.path.abspath(j))


def scratch(tok, p):
    """True for the main session's working folder under the temp directory: a `claude*` entry of /tmp or of the
    temp folder, by the word as typed or by its resolved path."""
    slash = tok.replace('\\', '/')
    if re.match(r'^/+tmp/+claude', slash, re.I if os.name == 'nt' else 0):
        return True
    for t in {os.environ.get(k) for k in ('TMPDIR', 'TEMP', 'TMP')} | {'/tmp'}:
        if t:
            base = full(t, '/')
            if p.startswith(os.path.join(base, 'claude')):
                return True
    return False


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


def comment_at(line, esc='\\'):
    """The index where an unquoted `#` at a word start opens a comment on line, else len(line)."""
    q, k = None, 0
    while k < len(line):
        ch = line[k]
        if ch == esc and q != "'":
            k += 2
            continue
        if q:
            if ch == q:
                q = None
        elif ch in '\'"':
            q = ch
        elif ch == '#' and (k == 0 or line[k - 1] in ' \t;&|()<>'):
            return k
        k += 1
    return len(line)


def drop_heredocs(cmd):
    """The command with every heredoc body cut: its lines are text (the seat's report), not commands. The
    delimiter is the whole word (quotes taken off); a `<<` inside quotes, a comment or `(( ))` is no heredoc."""
    lines, out, i = cmd.split('\n'), [], 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        i += 1
        stop = comment_at(line)
        for m in re.finditer(r'(?<!<)<<(?!<)-?[ \t]*((?:\'[^\']*\'|"[^"]*"|[^\s;&|<>()\'"])+)', line):
            head = line[:m.start()]
            if m.start() >= stop or quoted(line, m.start()) or head.count('((') > head.count('))'):
                continue
            word = re.sub(r'[\'"\\]', '', m.group(1))
            while i < len(lines) and lines[i].strip() != word:
                i += 1
            i += 1
    return '\n'.join(out)


def strip_comments(cmd, powershell):
    esc = '`' if powershell else '\\'
    return '\n'.join(line[:comment_at(line, esc)] for line in cmd.split('\n'))


def substitutions(cmd):
    """The bodies of every `$( )` and backtick substitution outside single quotes (quoted in "..." too), or None
    when one does not close. `$(( ))` is arithmetic: its inside is scanned on, for a substitution within."""
    out, i, q = [], 0, None
    while i < len(cmd):
        c = cmd[i]
        if c == '\\' and q != "'":
            i += 2
            continue
        if q == "'":
            q = None if c == "'" else q
            i += 1
            continue
        if c == "'" and q is None:
            q = "'"
        elif c == '"':
            q = None if q == '"' else '"'
        elif c == '`':
            j = i + 1
            while j < len(cmd) and cmd[j] != '`':
                j += 2 if cmd[j] == '\\' else 1
            if j >= len(cmd):
                return None
            out.append(cmd[i + 1:j])
            i = j
        elif cmd.startswith('$(', i) and not cmd.startswith('$((', i):
            depth, j, iq = 1, i + 2, None
            while j < len(cmd) and depth:
                d = cmd[j]
                if d == '\\' and iq != "'":
                    j += 2
                    continue
                if iq:
                    iq = None if d == iq else iq
                elif d in '\'"':
                    iq = d
                elif d == '(':
                    depth += 1
                elif d == ')':
                    depth -= 1
                j += 1
            if depth:
                return None
            out.append(cmd[i + 2:j - 1])
            i = j - 1
        i += 1
    return out


PUNCT = re.compile(r'&&|\|\||\|&|;;&?|;&|&>>?|<<<|<<|<>|>>|>\||[<>]&|[<>]\(|[<>]|[;&|()]')


def items(cmd, powershell):
    """The command as a list of (kind, text): word, sep (; && || | & newline), redir (< > >> <& ...), open and
    close (a subshell, a process substitution); None when its quotes do not close."""
    cmd = cmd.replace('\r', '').replace('`\n' if powershell else '\\\n', '')
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=';&|()<>')
    lex.whitespace = ' \t'
    lex.whitespace_split = True
    lex.commenters = ''                                  # comments are cut by strip_comments, quote-aware
    lex.escape = '`' if powershell else '\\'
    out = []
    try:
        for tok in lex:
            if tok and set(tok) <= set(';&|()<>'):
                for op in PUNCT.findall(tok):
                    if op in ('(', '<(', '>('):
                        out.append(('open', op))
                    elif op == ')':
                        out.append(('close', op))
                    elif '<' in op or '>' in op:
                        out.append(('redir', op))
                    else:
                        out.append(('sep', op))
            elif tok in SEP:
                out.append(('sep', ';'))                # { } group in the current shell
            elif '\n' in tok:
                for k, part in enumerate(tok.split('\n')):
                    if k:
                        out.append(('sep', '\n'))
                    if part:
                        out.append(('word', part))
            else:
                out.append(('word', tok))
    except ValueError:
        return None
    return out


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
    courts = os.path.join(project, '.vulyk', 'court')
    reports = os.path.join(project, '.vulyk', 'reports')
    seat = data.get('agent_type')

    def court_of(p):
        """The round folder .vulyk/court/<slug>/<round> that holds p, or None."""
        if not under(p, courts):
            return None
        parts = os.path.relpath(p, courts).replace('\\', '/').split('/')
        if len(parts) < 2 or parts[0] in ('', '.', '..'):
            return None
        return os.path.join(courts, parts[0], parts[1])

    def court_count():
        n = 0
        try:
            for slug in os.listdir(courts):
                d = os.path.join(courts, slug)
                if os.path.isdir(d):
                    n += sum(1 for r in os.listdir(d) if os.path.isdir(os.path.join(d, r)))
        except OSError:
            pass
        return n

    stand = [court_of(full(cwd, cwd))]                  # the court the call stands in, moved by each `cd`

    def outside(p):
        if stand[0]:
            return not under(p, stand[0])
        return court_of(p) is None or court_count() != 1

    def why(p):
        """The deny reason's tail: a call in no court naming a court path while more than one court exists."""
        if not stand[0] and court_of(p) is not None:
            return (' This call stands in no court and more than one court exists, so the hook cannot tell which '
                    'is yours: work from inside your court (in Bash, `cd COURT && ...` first).')
        return TAIL

    if tool in ('Read', 'Grep', 'Glob'):
        paths = []
        for key in ('file_path', 'path', 'notebook_path'):
            v = ti.get(key)
            if isinstance(v, str) and v:
                paths.append(v)
        if tool in ('Grep', 'Glob') and not ti.get('path'):
            paths.append(cwd)
        pat = ti.get('pattern')
        if tool == 'Glob' and isinstance(pat, str) and (re.match(r'^([/\\~]|[A-Za-z]:|\.\.)', pat)
                                                        or '..' in re.split(r'[/\\]', pat)):
            paths.append(re.split(r'[*?\[{]', pat, 1)[0] or pat)
        for p in paths:
            fp = full(p, cwd)
            if outside(fp) and not under(fp, reports):
                deny('VULYK court guard: %s of %s by the %s seat - it lies outside the court.%s'
                     % (tool, p, seat, why(fp)))
        sys.exit(0)
    if tool not in ('Bash', 'PowerShell'):
        sys.exit(0)
    cmd = ti.get('command')
    if not isinstance(cmd, str):
        sys.exit(0)
    ps = tool == 'PowerShell'
    VARS = {}                                           # NAME -> value set earlier in this call (None: unknown)
    shown = ['']

    def unreadable():
        deny('VULYK court guard: this command cannot be read (its quotes or substitutions do not close), and a '
             'blind seat may run only commands the hook can check.' + TAIL)

    def expand(t):
        """$NAME and ${NAME} replaced by a value set earlier in the same call; anything else is left."""
        def one(m):
            v = VARS.get(m.group(1) or m.group(2))
            return v if v is not None else m.group(0)
        return re.sub(r'\$\{([A-Za-z_][A-Za-z0-9_]*)\}|\$([A-Za-z_][A-Za-z0-9_]*)', one, t)

    def allowed(tok, p):
        if not outside(p) or under(p, reports):
            return True
        # a system location is judged as typed, but never one that climbs back out with `..`, never one whose
        # resolved path lies inside this project outside the court (on Linux and macOS a project may itself live
        # under /tmp), and never the main session's working folder under the temp directory
        slash = tok.replace('\\', '/')
        if under(p, project) or '..' in slash.split('/') or scratch(tok, p):
            return False
        return slash.startswith(SYSTEM) or tok in ('/dev/null', '/tmp', 'NUL', '$null') or \
            re.match(r'^[A-Za-z]:[/\\](windows|program files)', tok, re.I) is not None

    def looks(t):
        """A word shaped like a path: a drive, /, ~ or .. at its start, or a `..` step anywhere in it."""
        return re.match(r'^(~|/|[A-Za-z]:([/\\]|$)|\.\.([/\\]|$))', t) is not None or '..' in re.split(r'[/\\]', t)

    def check_path(tok, here, kind):
        """Deny when the word is a path argument leaving the court; return its full path or None. kind: operand
        (of a command that reads files: a path when it exists or looks like one), opt (an option: its value,
        glued or after `=`, judged as an operand), script or word (a script, a pattern, an echo word: a path
        only when it exists)."""
        t = re.sub(r'^\d*[<>]+&?', '', tok)
        if t != tok:
            kind = 'operand'                            # `<file`, `>file`: the redirect's own target
        t = expand(t)
        if t.startswith('-'):
            if '=' in t:                                # an option's value
                t, kind = t.split('=', 1)[1], 'operand' if kind in ('opt', 'operand') else 'word'
            elif kind in ('opt', 'operand') and not t.startswith('--'):
                glued = [t[k:] for k in range(2, len(t)) if t[k:] not in ('/', '\\') and looks(t[k:])]
                if not glued:                           # `-tf<path>`, `-o<path>`: the value glued to the option
                    return None
                t, kind = glued[0], 'operand'
            else:
                return None
        if re.match(r'^file://', t, re.I):              # a file URL names a path
            u = re.sub(r'^localhost(?=/)', '', unquote(t[7:]), flags=re.I)
            if os.name == 'nt' and re.match(r'^/[A-Za-z]:', u):
                u = u[1:]
            t = u if u.startswith('/') or re.match(r'^[A-Za-z]:', u) else '//' + u
            kind = 'operand' if kind == 'opt' else kind
        if not t or t.startswith('-') or '://' in t or t in ('$null',):
            return None
        if os.name != 'nt' and '..' in t.split('\\'):
            t = t.replace('\\', '/')                    # a backslash path, judged as the Windows form it spells
        lk = looks(t)
        if re.search(r'[$`]', t):
            if kind == 'operand' and (lk or (t.startswith(('$', '"$', '`')) and re.search(r'[/\\]', t))):
                deny('VULYK court guard: the path `%s` is built from a variable or a substitution, so the hook '
                     'cannot tell whether it leaves the court.%s' % (t, TAIL))
            return None
        try:
            exists = os.path.exists(os.path.join(native(here), native(t)))
        except (ValueError, OSError):
            exists = False
        if not exists and not (lk and kind == 'operand'):
            return None
        p = full(t, here)
        if not allowed(t, p):
            deny('VULYK court guard: `%s` names %s, outside the court, in a blind seat\'s command.%s'
                 % (shown[0], t, why(p)))
        return p

    def each(H, tok, kind):
        for h in list(H):
            check_path(tok, h, kind)

    def operands(seg, i):
        """(word, kind) for each word after the command word seg[i]: script for the script or pattern of sed,
        awk, grep, rg and jq (their first word, an -e value, one glued to its option, their options), word for
        every word of a command that reads no files (echo, printf, tr, ...), opt for another command's option,
        operand for the rest; a script file (`-f`, glued or not) is an operand."""
        name = prog(seg[i]) if i < len(seg) else ''
        out, script, skip = [], name not in SCRIPTED, None
        for k in range(i + 1, len(seg)):
            w = seg[k]
            if name in NO_FILES:
                out.append((w, 'word'))
            elif skip is not None:
                out.append((w, skip))
                skip = None
            elif name in SCRIPTED and w in SCRIPT_OPT:
                out.append((w, 'script'))
                skip, script = 'script', True
            elif name in SCRIPTED and (w.startswith(('--expression=', '--regexp=', '--source='))
                                       or (len(w) > 2 and w.startswith('-e'))):
                out.append((w, 'script'))               # a script glued to its option is the script
                script = True
            elif name in SCRIPTED and w in FILE_OPT:
                out.append((w, 'script'))
                skip, script = 'operand', True
            elif name in SCRIPTED and (w.startswith(('--file=', '--from-file=')) or (len(w) > 2 and w.startswith('-f'))):
                out.append((w.split('=', 1)[1] if w.startswith('--') else w[2:], 'operand'))   # a glued script file
                script = True
            elif name in SCRIPTED and w in VALUE_OPT:
                out.append((w, 'script'))
                skip = 'script'
            elif w.startswith('-'):
                out.append((w, 'script' if name in SCRIPTED else 'opt'))
            elif not script:
                out.append((w, 'script'))
                script = True
            else:
                out.append((w, 'operand'))
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

    def check_git(seg, i):
        """seg[i] is a git word: deny every form off the seat's allowlist (GIT_VERBS, GIT_GLOBAL, `-C <dir>`)."""

        def refuse(what):
            deny('VULYK court guard: `%s` - %s, and a blind seat git read outside the allowlist is denied (it may run '
                 'git status, version, rev-parse with a query option, ls-files).%s' % (shown[0], what, TAIL))
        i += 1
        while i < len(seg) and seg[i].startswith('-'):
            if seg[i] == '--version':
                return
            if seg[i] == '-C' and i + 1 < len(seg):
                i += 2
            elif seg[i] in GIT_GLOBAL:
                i += 1
            else:
                refuse('git option %s is not on the list' % seg[i])
        if i >= len(seg):
            return
        verb, args = seg[i], seg[i + 1:]
        if verb not in GIT_VERBS:
            refuse('git %s is not on the list (an alias or a low-level verb counts as unlisted)' % verb)
        opts = GIT_VERBS[verb]
        for a in args:
            if re.search(r'[$`]', a):
                refuse('the word %s is built from a variable or a substitution' % a)
            if a.startswith('-'):
                if opts is not None and a != '--' and a.split('=', 1)[0] not in opts and \
                        not (verb == 'ls-files' and re.match(r'^-[cdmoiskuztvf]+$', a)):
                    refuse('git %s %s is not on the list' % (verb, a))
            elif ':' in a and not a.startswith(':') and not re.match(r'^[A-Za-z]:[/\\]', a) and \
                    rel_hit(a.split(':', 1)[1]):
                refuse('the revision %s names docs/specs/' % a)

    def head(words, H):
        """(index of the command word, wrapped, via xargs): past assignments, keywords (`!`, then, do, ...) and
        the wrappers that run the next word as a command (time, command, exec, env, timeout, nice, xargs, ...)
        with their options; a file a wrapper reads (`xargs -a`, `env -C`) is judged as a path."""
        i, wrapped, xa = 0, False, False
        while i < len(words):
            w = words[i]
            if ASSIGN.match(w):
                each(H, w, 'word')                      # an assignment: a path only when it exists
                i += 1
                continue
            if w in KEYWORDS:
                i, wrapped = i + 1, True
                continue
            n = prog(w)
            if n not in WRAP:
                break
            vals, files, npos = WRAP[n]
            wrapped, xa, i = True, xa or n == 'xargs', i + 1
            while i < len(words) and words[i].startswith('-'):
                o = words[i]
                i += 1
                if o == '--':
                    break
                if n == 'env' and (o.startswith('-S') or o.startswith('--split-string')):
                    deny('VULYK court guard: `%s` hands env a command string the hook cannot check.%s'
                         % (shown[0], TAIL))
                if o in vals and i < len(words):
                    if o in files:
                        each(H, words[i], 'operand')
                    i += 1
                elif '=' in o and o.split('=', 1)[0] in files:
                    each(H, o.split('=', 1)[1], 'operand')
            i += min(npos, len(words) - i)
        return i, wrapped, xa

    def shell_string(words, i):
        """The command string of `sh -c <string>` (any option cluster holding c), else None."""
        k, c = i + 1, False
        while k < len(words):
            a = words[k]
            if a in ('-o', '+o', '-O', '+O', '--rcfile', '--init-file'):
                k += 2
            elif a == '--':
                k += 1
                break
            elif re.match(r'^[-+][A-Za-z]+$', a):
                c = c or (a[0] == '-' and 'c' in a[1:])
                k += 1
            elif a.startswith('--'):
                k += 1
            else:
                break
        if not c:
            return None
        return words[k] if k < len(words) else ''

    def assign(w):
        name, _, v = w.partition('=')
        v = expand(v)
        VARS[name.split('[')[0].rstrip('+')] = None if re.search(r'[$`]', v) else v

    def segment(words, reds, H, certain, depth):
        shown[0] = ' '.join(words + [o + (t or '') for o, t in reds])
        for op, t in reds:
            if t is None or op == '<<':                 # a heredoc's delimiter is no path
                continue
            if op.endswith('&') and re.match(r'^(\d+-?|-)$', t):
                continue                                # a descriptor copy, `2>&1`
            each(H, t, 'word' if op == '<<<' else 'operand')
        if not words:
            return
        if any(re.match(r'^GIT_[A-Za-z0-9_]*=', w) for w in words):
            deny('VULYK court guard: `%s` sets a GIT_* variable, which points git elsewhere; a blind seat may not.%s'
                 % (shown[0], TAIL))
        if words[0] in ('for', 'select'):               # the list after `in` is read as operands
            if 'in' in words:
                for w in words[words.index('in') + 1:]:
                    each(H, w, 'operand')
            return
        if words[0] == 'case':
            return
        i, wrapped, xa = head(words, H)
        if i >= len(words):
            if not wrapped:                             # NAME=value alone: it holds for the rest of the call
                for w in words:
                    assign(w)
            return
        w = expand(words[i])
        if re.search(r'[$`]', w) or ('{' in w and re.search(r',|\.\.', w)) or \
                (w not in ('[', '[[') and re.search(r'[*?\[]', w)):
            deny('VULYK court guard: `%s` runs a program whose name is built from a variable, a substitution, a '
                 'brace or a glob, so the hook cannot tell what runs; a blind seat may not.%s' % (shown[0], TAIL))
        words = words[:i] + [w] + words[i + 1:]
        n = prog(w)
        if n in CD:
            change_dir(words, i, H, certain and not wrapped and i == 0)
            return
        if n in ('export', 'declare', 'local', 'readonly', 'typeset'):
            for a in words[i + 1:]:
                if ASSIGN.match(a):
                    assign(a)
                each(H, a, 'word')
            return
        if n in ('eval', 'iex', 'invoke-expression'):
            walk(' '.join(words[i + 1:]), H, depth + 1)   # eval runs in this shell: its cd moves the call
            return
        if n in SHELLS:
            s = shell_string(words, i)
            if s is not None:
                walk(s, list(H), depth + 1)
                return
        if n == 'git':
            if xa:
                deny('VULYK court guard: `%s` hands git words read from input, which the hook cannot check; a '
                     'blind seat may not.%s' % (shown[0], TAIL))
            check_git(words, i)
        for tok, kind in operands(words, i):
            each(H, tok, kind)

    def change_dir(seg, i, H, certain):
        if prog(seg[i]) in ('popd', 'pop-location') or '-' in seg[i + 1:]:
            deny('VULYK court guard: `%s` moves to a folder the hook cannot name.%s' % (shown[0], TAIL))
        args = [a for a in seg[i + 1:] if not a.startswith('-')]
        if not args:
            deny('VULYK court guard: `%s` moves to the home folder, outside the court.%s' % (shown[0], TAIL))
        if len(args) > 1 or 'CDPATH' in cmd:
            deny('VULYK court guard: `%s` is a cd the shell may not take as written (more than one folder, or a '
                 'CDPATH), so the hook cannot tell where later paths lead.%s' % (shown[0], TAIL))
        a = expand(args[0])
        if re.search(r'[$`%]', a):
            deny('VULYK court guard: `%s` moves to a folder built from a variable or a substitution.%s'
                 % (shown[0], TAIL))
        new = []
        for h in list(H):
            p = full(a, h)
            if stand[0] is None and court_of(p) is not None:
                stand[0] = court_of(p)                  # a call that starts in no court enters one
            if outside(p):
                deny('VULYK court guard: `%s` leaves the court.%s' % (shown[0], TAIL))
            new.append(p)
        # A cd that surely takes effect moves the call; one that may not (a missing folder, a branch, a pipe,
        # a background job, a subshell left later) keeps every folder the call may stand in, each judged.
        if certain and all(os.path.isdir(p) for p in new):
            H[:] = new
        else:
            H[:] = list(dict.fromkeys(H + new))

    def walk(text, H, depth):
        if depth > 8:
            unreadable()
        text = strip_comments(drop_heredocs(text), ps)
        subs = substitutions(text)
        its = items(text, ps)
        if subs is None or its is None:
            unreadable()
        for body in subs:                               # a substitution runs where the call stands
            walk(body, list(H), depth + 1)
        entries, words, reds, pend = [], [], [], None
        for kind, v in its + [('sep', None)]:
            if kind == 'word':
                if pend is not None:
                    reds.append((pend, v))
                    pend = None
                else:
                    words.append(v)
                continue
            if pend is not None:
                reds.append((pend, None))
                pend = None
            if kind == 'redir':
                if words and words[-1].isdigit():
                    words.pop()                         # the descriptor number of `2>`
                pend = v
                continue
            if words or reds:
                entries.append(('seg', words, reds))
            words, reds = [], []
            entries.append((kind, v))
        saved, cond = [], [False]
        for k, e in enumerate(entries):
            if e[0] == 'sep':
                if e[1] in ('||', '|', '&', '|&'):
                    cond[0] = True
                continue
            if e[0] == 'open':
                saved.append((list(H), cond[0]))
                continue
            if e[0] == 'close':
                if saved:
                    old, cond[0] = saved.pop()
                    H[:] = old
                continue
            before = entries[k - 1] if k else ('sep', None)
            after = entries[k + 1] if k + 1 < len(entries) else ('sep', None)
            certain = (not cond[0] and before[1] in (None, ';', '&&', '\n', '(')
                       and not (after[0] == 'sep' and after[1] in ('||', '|', '&', '|&')))
            segment(e[1], e[2], H, certain, depth)

    walk(cmd, [cwd], 0)
    sys.exit(0)


try:
    main()
except SystemExit:
    raise
except Exception as e:
    deny('VULYK court guard: the hook failed (%s), so this blind seat\'s call is refused.' % e.__class__.__name__)
PYTHON
