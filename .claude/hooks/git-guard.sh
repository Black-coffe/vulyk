#!/usr/bin/env bash
# PreToolUse hook (matcher Bash|PowerShell): denies the git verbs that throw away uncommitted work
# (spec uncommitted-work-guard, card docs/defects/work-discarded-by-git-verb.md).
#
# Verbs: stash (push/save/bare, -u, drop, clear), checkout . / -f / [<ref>] -- <path> / <ref> <path>,
# restore (worktree form), reset --hard, clean -f, switch -f / --discard-changes, branch -D,
# worktree remove --force. Read-only forms pass: stash list/show, soft and mixed reset, checkout -b,
# clean -n, restore --staged alone.
#   - A subagent (the input carries agent_id) is denied every listed verb, with no git status call,
#     and any git call whose arguments cannot be read (unbalanced quotes).
#   - The main session is denied only when `git status --porcelain` shows the paths the verb would
#     discard dirty (tracked) or untracked (clean -f, stash -u); the reason names them, 10 at most then
#     `+N more`, and gives the safe path. stash drop/clear and branch -D lose a stash or commits, not
#     tree files: they are denied to subagents only.
# Not covered, on purpose: rm / Remove-Item, `bash -c`, scripts and aliases (git is matched only at a
# command position), a ref checkout over an untracked file, and a mod that answers `tool.check` (on a
# personal login it can approve a call this hook denied: the SessionStart brief names such a mod).
# Agents get no env off-switch. The owner turns the guard off by removing its entry from
# .claude/settings.json; install.sh then leaves it removed.
#
# Fails open: no python, bad JSON, a non-git command or any error -> silent exit 0.
# `--check <file>` (the card's check): reads hook input from <file>; a `porcelain` field stands in for
# `git status --porcelain`. Exit 1 on a deny (the reason on stdout), 0 otherwise, also for a file that
# is no hook input.
# The Python half lives below the `exit 0`, inside a no-op heredoc, as in defect-intake.sh.
if [ "${1:-}" = "--check" ]; then
  [ -f "${2:-}" ] || exit 0
  IFS= read -r -d '' IN < "$2"
else
  IFS= read -r -d '' IN   # a builtin: no `cat`, so an empty PATH still exits 0 in silence
fi
case "$IN" in *git*) ;; *) exit 0 ;; esac
for PY in python3 python; do
  command -v "$PY" >/dev/null 2>&1 || continue
  printf '%s' "$IN" | "$PY" -S -c 'import sys;sys.argv=sys.argv[1:];p=sys.argv[0];s=open(p,encoding="utf-8").read();exec(compile(s.split("\n#<py>\n",1)[1].split("\nPYTHON\n",1)[0],p,"exec"))' \
    "${BASH_SOURCE[0]}" "$@" 2>/dev/null
  rc=$?
  case $rc in 0|1) [ "${1:-}" = "--check" ] && exit "$rc"; exit 0 ;; esac
done
exit 0

: <<'PYTHON'
#<py>
import json, os, re, shlex, subprocess, sys

CHECK = len(sys.argv) > 1 and sys.argv[1] == '--check'
CAP = 10
SEP = {';', '&&', '||', '|', '&', '\n', '(', ')', '{', '}'}


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
    """The command with every heredoc body cut: its lines are text, not commands (`<<<` is no heredoc)."""
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


CD = ('cd', 'chdir', 'pushd', 'popd', 'set-location', 'sl', 'push-location', 'pop-location')
UNKNOWN = ''   # a cd the hook cannot follow: the whole tree of the call's cwd is checked instead


def cd_target(seg, now):
    """The folder a `cd` / `Set-Location` segment moves to from `now`, else None (not a cd)."""
    if not seg or seg[0].lower() not in CD:
        return None
    if seg[0].lower() in ('popd', 'pop-location') or '-' in seg[1:]:
        return UNKNOWN                              # back to a folder this command did not name
    if now == UNKNOWN:
        return UNKNOWN
    args = [a for a in seg[1:] if not a.startswith('-')]
    if not args:
        return os.path.expanduser('~')
    t = args[0]
    if re.search(r'[$`%]', t):                      # a variable or a command substitution
        return UNKNOWN
    m = re.match(r'^/([A-Za-z])(/.*)?$', t)
    if os.name == 'nt' and m:                       # Git Bash /e/x -> e:/x for a native git
        t = m.group(1) + ':' + (m.group(2) or '/')
    t = os.path.join(now, os.path.expanduser(t))
    return t if os.path.isdir(t) else UNKNOWN


def split_segments(cmd, powershell):
    """Shell words cut into simple commands; None when the quotes do not close."""
    lex = shlex.shlex(cmd.replace('\r', ''), posix=True, punctuation_chars=';&|()')
    lex.whitespace = ' \t'
    lex.whitespace_split = True
    if powershell:
        lex.escape = '`'
    else:
        lex.escape = '\\'
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
                        segs.append(cur); cur = []
            else:
                cur.append(tok)
    except ValueError:
        return None
    if cur:
        segs.append(cur)
    return segs


def git_call(seg):
    """(dir, verb, args) when the simple command runs git, else None."""
    i = 0
    while i < len(seg) and (re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', seg[i]) or seg[i] in ('&', 'command', 'exec', 'time', 'env')):
        i += 1
    if i >= len(seg):
        return None
    if os.path.basename(seg[i].replace('\\', '/')).lower() not in ('git', 'git.exe'):
        return None
    i += 1
    where = None
    while i < len(seg) and seg[i].startswith('-'):
        o = seg[i]
        if o in ('-C', '-c', '--git-dir', '--work-tree', '--namespace') and i + 1 < len(seg):
            if o == '-C':
                where = seg[i + 1] if where is None else os.path.join(where, seg[i + 1])
            i += 2
        else:
            i += 1
    if i >= len(seg):
        return None
    return where, seg[i], seg[i + 1:]


def flags(args):
    """Short flag letters (-fd -> f, d) and long options of args."""
    short, long_ = set(), set()
    for a in args:
        if a == '--':
            break
        if a.startswith('--'):
            long_.add(a.split('=', 1)[0])
        elif a.startswith('-') and len(a) > 1:
            short.update(a[1:])
    return short, long_


def positionals(args, takes_value=()):
    out, i, dash = [], 0, False
    while i < len(args):
        a = args[i]
        if dash:
            out.append(a)
        elif a == '--':
            dash = True
        elif a in takes_value:
            i += 1
        elif not a.startswith('-'):
            out.append(a)
        i += 1
    return out


def after_dash(args):
    return args[args.index('--') + 1:] if '--' in args else None


def classify(verb, args, base):
    """None = passes. Else (paths, kinds, tree): paths [] = the whole tree; kinds of status entries that
    count ('t' tracked, 'u' untracked); tree False = it loses a stash or commits, not tree files."""
    s, l = flags(args)
    if verb == 'stash':
        sub = args[0] if args and not args[0].startswith('-') else 'push'
        if sub in ('drop', 'clear'):
            return [], '', False
        if sub not in ('push', 'save'):
            return None
        rest = args[1:] if args and args[0] == sub else args
        kinds = 'tu' if ('u' in s or 'a' in s or '--include-untracked' in l or '--all' in l) else 't'
        paths = positionals(rest, ('-m', '--message', '--pathspec-from-file')) if sub == 'push' else []
        return paths, kinds, True
    if verb == 'checkout':
        if s & {'b', 'B'} or '--orphan' in l:
            return None
        pos = positionals(args, ('--conflict', '--pathspec-from-file'))
        dash = after_dash(args)
        if dash is not None:
            return dash, 't', True
        if '.' in pos:
            return ['.'], 't', True
        if 'f' in s or '--force' in l:
            return [], 't', True
        if len(pos) >= 2:
            return pos[1:], 't', True
        if len(pos) == 1 and os.path.exists(os.path.join(base, pos[0])):
            return pos, 't', True
        return None
    if verb == 'restore':
        staged = 'S' in s or '--staged' in l
        work = 'W' in s or '--worktree' in l
        if staged and not work:
            return None
        pos = positionals(args, ('-s', '--source', '--pathspec-from-file'))
        return (pos, 't', True) if pos else None
    if verb == 'reset':
        return ([], 't', True) if '--hard' in l else None
    if verb == 'clean':
        if 'n' in s or '--dry-run' in l:
            return None
        if 'f' in s or '--force' in l:
            return positionals(args, ('-e', '--exclude')), 'u', True
        return None
    if verb == 'switch':
        return ([], 't', True) if ('f' in s or '--force' in l or '--discard-changes' in l) else None
    if verb == 'branch':
        if 'D' in s or (('d' in s or '--delete' in l) and ('f' in s or '--force' in l)):
            return [], '', False
        return None
    if verb == 'worktree':
        if args and args[0] == 'remove' and ('f' in s or '--force' in l):
            pos = positionals(args[1:])
            return (['@worktree', pos[0]] if pos else [], 't' + 'u', True)
        return None
    return None


def status(cwd, paths, fake):
    """Porcelain v1 entries [(xy, path)] under paths ([] = all); None when git status fails there."""
    if fake is not None:
        text = fake
    else:
        cmd = ['git', '-c', 'core.quotePath=false', '-C', cwd, 'status', '--porcelain', '--untracked-files=all']
        if paths:
            cmd += ['--'] + paths
        r = subprocess.run(cmd, capture_output=True, timeout=8)
        if r.returncode != 0:
            return None
        text = r.stdout.decode('utf-8', 'replace')
    out = []
    for line in text.splitlines():
        if len(line) > 3:
            p = line[3:].split(' -> ')[-1].strip('"')
            if fake is not None and paths and not any(
                    q in ('.', '') or p == q.rstrip('/') or p.startswith(q.rstrip('/') + '/') for q in paths):
                continue
            out.append((line[:2], p))
    return out


def deny(reason):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                             "permissionDecision": "deny",
                                             "permissionDecisionReason": reason}}))
    sys.exit(1 if CHECK else 0)


def main():
    try:
        data = json.loads(sys.stdin.read())
    except Exception:
        sys.exit(0)
    if not isinstance(data, dict):
        sys.exit(0)
    tool = str(data.get('tool_name') or '')
    if tool not in ('Bash', 'PowerShell'):
        sys.exit(0)
    cmd = (data.get('tool_input') or {}).get('command')
    if not isinstance(cmd, str) or 'git' not in cmd:
        sys.exit(0)
    sub = bool(data.get('agent_id'))
    cwd = str(data.get('cwd') or os.getcwd())
    fake = data.get('porcelain') if CHECK else None
    segs = split_segments(drop_heredocs(cmd), tool == 'PowerShell')
    if segs is None:
        if sub and re.search(r'(^|[\s;&|(])git(\.exe)?\s', cmd):
            deny('VULYK git guard: this git call cannot be read (its quotes do not close), and a subagent may not '
                 'run a git command that can throw away work. Leave the tree as it is and report the step instead.')
        sys.exit(0)
    here = cwd                                       # follows each cd of the command, in order
    for seg in segs:
        moved = cd_target(seg, here)
        if moved is not None:
            here = moved
            continue
        call = git_call(seg)
        if not call:
            continue
        where, verb, args = call
        blind = here == UNKNOWN
        base = cwd if blind else (here if not where else os.path.join(here, where))
        hit = classify(verb, args, base)
        if not hit:
            continue
        paths, kinds, tree = hit
        shown = ' '.join(['git', verb] + args)
        if sub:
            deny('VULYK git guard: a subagent may not run `%s` - it can throw away uncommitted work that is '
                 'not yours (another story, the Queen, runtime data). Leave the tree as it is; if the story '
                 'truly needs this, report it under ## Findings and return NEEDS_CONTEXT.' % shown)
        if not tree:
            continue
        if paths[:1] == ['@worktree'] and not blind:
            base, paths = os.path.join(here, paths[1]), []
            if not os.path.isdir(base):
                continue
        if blind:
            paths = []                               # relative to a folder the hook cannot name
        try:
            entries = status(base, paths, fake)
            if entries is None and not blind:        # a folder git cannot read (a Git Bash /tmp on Windows)
                entries = status(cwd, [], fake)
            entries = entries or []
        except Exception:
            continue
        lost = [p for xy, p in entries
                 if (xy == '??' and 'u' in kinds) or (xy not in ('??', '!!') and 't' in kinds)]
        if not lost:
            continue
        more = '' if len(lost) <= CAP else ', +%d more' % (len(lost) - CAP)
        deny('VULYK git guard: `%s` would throw away uncommitted work in: %s%s. Commit these files as their own '
             'commit first, leave them as they are, or, if they really should go, run the command yourself in '
             'your own terminal.' % (shown, ', '.join(lost[:CAP]), more))
    sys.exit(0)


try:
    main()
except SystemExit:
    raise
except Exception:
    sys.exit(0)
PYTHON
