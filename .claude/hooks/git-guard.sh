#!/usr/bin/env bash
# PreToolUse hook (matcher Bash|PowerShell): denies the git verbs that throw away uncommitted work or commits
# (spec uncommitted-work-guard, card docs/defects/work-discarded-by-git-verb.md).
#
# Verbs (GUARD_VERBS below, VERBS in the Python half: one list each, a test compares them):
#   tree files: stash (push/save/bare, -u), checkout . / -f / [<ref>] -- <path> / <ref> <path>, restore (worktree
#   form), reset --hard / --merge, merge --abort, clean -f, switch -f / --discard-changes, worktree remove --force,
#   rm -f / --force (not --cached, not -n), checkout-index -f, read-tree -u with --reset or -m;
#   a stash or commits: stash drop/clear, branch -D / -f / -M / -C / -d --force, checkout -B, switch -C /
#   --force-create, update-ref (every form: it deletes or moves a ref by force).
# Read-only and unforced forms pass: stash list/show, soft and mixed reset, a merge that is not --abort, checkout -b (a forced checkout -b / -B /
# --orphan is a forced checkout), clean -n, restore --staged alone, rm --cached, rm without -f, checkout-index
# without -f, read-tree without -u, branch -d, switch -c.
# The same verbs are read where a shell is handed them: `bash|sh|zsh|dash|ksh -c <string>`, `pwsh|powershell
# -Command <words>`, a heredoc fed to such a shell (`bash <<X`, `cat <<X | sh`: its body is read as commands; a
# heredoc fed to anything else is text), and a `git -c alias.<name>=<value>` given on the same command line (a `!`
# value is read as a shell command).
# A line continuation (backslash-newline, PowerShell backtick-newline) is joined before reading. The command word
# is found past assignments, the shell keywords if/then/else/elif/do/while/until and `!`, `command`, `exec`, `time`,
# and the wrappers env, timeout, nohup, nice, sudo and xargs (by basename, `/usr/bin/env git`; their options and
# values skipped); `eval <words>` is read as the command its words make.
#   - A subagent (the input carries agent_id) is denied every listed verb, with no git status call,
#     and any git call whose arguments cannot be read (unbalanced quotes, a verb holding $ or a backtick).
#     While any docs/specs/*/DRIVER file exists it is also denied `git commit` and `git add` (close-story commits
#     the story's paths; `git update-index --chmod` stays allowed). It may run only these cycle.sh verbs:
#     advance, status, release, suite, stamp-red (never with --baseline) and close-story.
#   - The main session is denied only when `git status --porcelain` shows the paths the verb would
#     discard dirty (tracked) or untracked (clean -f, stash -u); the reason names them, 10 at most then
#     `+N more`, and gives the safe path. The forms that lose a stash or commits, not tree files, are denied
#     to subagents only. A git status that times out denies: it cannot prove the tree is clean.
# Not covered, on purpose: rm / Remove-Item; a script file run by a shell (`bash x.sh`) and any other interpreter
# that runs git (`python -c`, `node -e`, a heredoc fed to python); command text piped into a shell (`echo 'git
# stash' | bash`), a here-string fed to a shell (`bash <<< 'git stash'`) and PowerShell `Invoke-Expression` (`iex`):
# the text may come from anywhere, so these cannot be enumerated (the no-Python fallback, reading every word, denies
# a literal one); `pwsh -EncodedCommand` and a PowerShell here-string fed to a shell; an alias defined in git config rather than by `-c` on the command line; a variable
# or substitution in the git command word or in an argument after the verb (only the verb itself is read as
# unreadable); any other wrapper command (stdbuf, ionice, watch, a shell function or alias of the session); a
# ref checkout over an untracked file; tag -f, push --force and the other remote forms, rebase, commit --amend,
# reflog expire, gc --prune, filter-branch; and a mod that answers `tool.check` (on a personal login it can approve
# a call this hook denied: the SessionStart brief names such a mod).
# Agents get no env off-switch. The owner turns the guard off by removing its entry from
# .claude/settings.json; install.sh then leaves it removed.
#
# Law 5 (0.48.1): the main session is denied `cycle.sh close-story <story>` when the story's plan.md says
# Tier 3 or 4: there a worker closes its own story, and a returned worker's story is re-dispatched, never
# finished by the Queen. A subagent and Tier 1-2 pass; `stamp-red` passes (ADR-025's re-stamp escape).
# A story token holding $, a backtick or %, or whose plan.md cannot be read, is of unknown tier and
# denied (fails closed, like the git half).
# Python: $VULYK_PY, python3, python, py, as lib.sh. An exit of 0 means it ran (and 1 under --check, its deny); 126,
# 127, 9009 or 49 that it did not start (Windows' python3 alias), so the next launcher is tried; any other exit,
# 1 outside --check included (Python's own status for an uncaught error), on a command naming git is a deny that
# says the guard failed. An error inside the Python half exits 3, so it is denied the same way. Hook stdin is
# read as bytes, decoded UTF-8 (a BOM tolerated).
# No Python at all: a bash fallback denies every listed verb that follows a `git` word, for any caller, in Bash and
# PowerShell. It reads every word of the command, quoted or not, so it is stricter than the Python half; other
# git commands pass.
# Passes silently: bad JSON, a command naming neither git nor cycle.sh.
# `--check <file>` (the card's check): reads hook input from <file>; a `porcelain` field stands in for
# `git status --porcelain` (an object {"sleep": S, "timeout": T} stands in for a git status that takes S
# seconds against a T-second timeout). Exit 1 on a deny (the reason on stdout), 0 otherwise, also for a file that
# is no hook input.
# The Python half lives below the `exit 0`, inside a no-op heredoc, as in defect-intake.sh. The bash part uses
# builtins only, so an empty PATH still runs it.
GUARD_VERBS='stash checkout restore reset merge clean switch branch worktree rm checkout-index read-tree update-ref'
ARG1="${1:-}"
if [ "$ARG1" = "--check" ]; then
  [ -f "${2:-}" ] || exit 0
  IFS= read -r -d '' IN < "$2"
else
  IFS= read -r -d '' IN   # a builtin: no `cat`, so an empty PATH still exits 0 in silence
fi
case "$IN" in *git*|*close-story*|*cycle.sh*) ;; *) exit 0 ;; esac

fb_deny() { # fb_deny <reason> - prints the deny line (the reason holds no quote or backslash) and exits
  printf '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "%s"}}\n' "$1"
  [ "$ARG1" = "--check" ] && exit 1
  exit 0
}

fb_scan() { # sets FB_GIT (the command has a git word) and FB_HIT (the first listed verb that follows one)
  FB_GIT=; FB_HIT=
  local re c w b v state=0 IFS=' '
  re='"tool_name"[[:space:]]*:[[:space:]]*"(Bash|PowerShell)"'
  [[ $IN =~ $re ]] || return 0
  re='"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'
  [[ $IN =~ $re ]] || return 0
  c="${BASH_REMATCH[1]}"
  # JSON escapes, then every quote, operator and redirection, become word breaks
  c="${c//\\\\/ }"; c="${c//\\n/ }"; c="${c//\\t/ }"; c="${c//\\r/ }"; c="${c//\\\"/ }"
  c="${c//;/ }"; c="${c//&/ }"; c="${c//|/ }"; c="${c//(/ }"; c="${c//)/ }"; c="${c//\{/ }"; c="${c//\}/ }"
  c="${c//</ }"; c="${c//>/ }"; c="${c//\'/ }"; c="${c//\`/ }"; c="${c//	/ }"
  set -f
  for w in $c; do
    case $state in
      0) b="${w##*/}"
         case "$b" in [Gg][Ii][Tt]|[Gg][Ii][Tt].[Ee][Xx][Ee]) FB_GIT=1; state=1 ;; esac ;;
      1) case "$w" in
           -C|-c|--git-dir|--work-tree|--namespace) state=2 ;;
           -*) ;;
           *) case " $GUARD_VERBS " in *" $w "*) FB_HIT="$w"; return 0 ;; esac
              state=0 ;;
         esac ;;
      2) state=1
         case "$w" in
           [Aa][Ll][Ii][Aa][Ss].*=*)
             v="${w#*=}"; v="${v#!}"
             case " $GUARD_VERBS " in *" $v "*) FB_HIT="$v"; return 0 ;; esac ;;
         esac ;;
    esac
  done
  return 0
}

for PY in ${VULYK_PY:+"$VULYK_PY"} python3 python py; do   # lib.sh's order (vulyk_python)
  command -v "$PY" >/dev/null 2>&1 || continue
  printf '%s' "$IN" | "$PY" -S -c 'import sys;sys.argv=sys.argv[1:];p=sys.argv[0];s=open(p,encoding="utf-8").read();exec(compile(s.split("\n#<py>\n",1)[1].split("\nPYTHON\n",1)[0],p,"exec"))' \
    "${BASH_SOURCE[0]}" "$@" 2>/dev/null
  rc=$?
  [ "$rc" = 1 ] && [ "$ARG1" = "--check" ] && exit 1      # under --check, 1 is its deny; outside, a crash
  case $rc in
    0) exit 0 ;;
    126|127|9009|49) ;;                                   # it did not start: the next launcher
    *) fb_scan
       [ -n "$FB_GIT" ] && fb_deny "VULYK git guard: the guard failed (its Python exited $rc) on a git command, so the command is denied. Fix that Python or set VULYK_PY to a working one; the owner can run the command in their own terminal." ;;
  esac
done
fb_scan
[ -n "$FB_HIT" ] && fb_deny "VULYK git guard: no Python, so the bash fallback denies every git $FB_HIT, from anyone: it cannot read which paths the command would touch. Install Python 3 or set VULYK_PY; the owner can run the command in their own terminal."
exit 0

: <<'PYTHON'
#<py>
import glob, json, os, re, shlex, subprocess, sys

CHECK = len(sys.argv) > 1 and sys.argv[1] == '--check'
CAP = 10
SEP = {';', '&&', '||', '|', '&', '\n', '(', ')', '{', '}'}
VERBS = ('stash', 'checkout', 'restore', 'reset', 'merge', 'clean', 'switch', 'branch', 'worktree', 'rm', 'checkout-index', 'read-tree', 'update-ref')
SHELLS = ('bash', 'sh', 'zsh', 'dash', 'ksh', 'pwsh', 'powershell')
# a shell named as a command word somewhere on a heredoc's line: `bash <<X`, `cat <<X | sh`
SHELL_RE = re.compile(r'(^|[\s;&|(])([^\s;&|()<>]*[/\\])?(%s)(\.exe)?(?=$|[\s;&|)<])' % '|'.join(SHELLS), re.I)
CYCLE_OK = ('advance', 'status', 'release', 'suite', 'stamp-red', 'close-story')


def base(word):
    """The lower-case basename of a command word, `.exe` dropped."""
    b = os.path.basename(word.replace('\\', '/')).lower()
    return b[:-4] if b.endswith('.exe') else b


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
    """The command with every heredoc body cut: its lines are text, not commands (`<<<` is no heredoc). A
    heredoc on a line that names a shell (`bash <<X`, `cat <<X | sh`) is a script: its body stays, read as commands."""
    lines, out, i = cmd.split('\n'), [], 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        i += 1
        for m in re.finditer(r'(?<!<)<<(?!<)-?[ \t]*([\'"]?)([A-Za-z_][A-Za-z0-9_]*)\1', line):
            if quoted(line, m.start()) or SHELL_RE.search(line[:m.start()] + ' ' + line[m.end():]):
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
    """Shell words cut into simple commands; None when the quotes do not close. A line continuation
    (backslash-newline in Bash, backtick-newline in PowerShell) is joined first: one command, not two."""
    cmd = cmd.replace('\r', '').replace('`\n' if powershell else '\\\n', '')
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=';&|()')
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


KEYWORDS = ('if', 'then', 'else', 'elif', 'do', 'while', 'until', '!', '&', 'command', 'exec', 'time')
WRAPPERS = ('env', 'timeout', 'nohup', 'nice', 'sudo', 'xargs')
LANDS = ('git', 'cycle.sh', 'eval') + SHELLS + WRAPPERS   # a wrapper's options end at the first of these


def command_word(seg):
    """The index of the simple command's command word: assignments, shell keywords (then, do, else, !, ...),
    `&`, command, exec and time skipped; behind a wrapper (env, timeout, nohup, nice, sudo, xargs) the next word
    that is git, cycle.sh, eval, a shell or another wrapper, its options and values (`timeout -s KILL 5`) skipped."""
    i = 0
    while i < len(seg):
        if re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', seg[i]) or seg[i] in KEYWORDS:
            i += 1
        elif base(seg[i]) in WRAPPERS:
            nxt = [j for j in range(i + 1, len(seg)) if base(seg[j]) in LANDS]
            if not nxt:
                return i + 1
            i = nxt[0]
        else:
            break
    return i


def fed_string(seg):
    """(text, powershell) when the simple command hands a shell a command string (`bash -c <s>`, `pwsh -Command
    <words>`, `eval <words>`), else None."""
    i = command_word(seg)
    if i < len(seg) and seg[i] == 'eval':
        return ' '.join(seg[i + 1:]), False
    if i >= len(seg) or base(seg[i]) not in SHELLS:
        return None
    ps = base(seg[i]) in ('pwsh', 'powershell')
    k = i + 1
    while k < len(seg):
        a = seg[k]
        if ps:
            low = a.lower()
            if low == '-c' or (len(low) >= 4 and '-command'.startswith(low)):
                return ' '.join(seg[k + 1:]), True
        else:
            if a in ('-o', '+o', '-O', '+O'):
                k += 1
            elif a.startswith('-') and not a.startswith('--') and 'c' in a[1:]:
                return (seg[k + 1] if k + 1 < len(seg) else ''), False
            elif not a.startswith(('-', '+')):
                return None                             # a script file: not read
        k += 1
    return None


def git_call(seg):
    """(dir, verb, args) when the simple command runs git, else None. A `-c alias.<name>=<value>` given on the
    same command line is expanded: a `!` value comes back as verb '!' with the shell command as its one arg."""
    i = command_word(seg)
    if i >= len(seg) or base(seg[i]) != 'git':
        return None
    i += 1
    where, alias = None, {}
    while i < len(seg) and seg[i].startswith('-'):
        o = seg[i]
        if o in ('-C', '-c', '--git-dir', '--work-tree', '--namespace') and i + 1 < len(seg):
            if o == '-C':
                where = seg[i + 1] if where is None else os.path.join(where, seg[i + 1])
            if o == '-c' and seg[i + 1].lower().startswith('alias.') and '=' in seg[i + 1]:
                name, value = seg[i + 1].split('=', 1)
                alias[name[len('alias.'):].lower()] = value.strip()
            i += 2
        else:
            i += 1
    if i >= len(seg):
        return None
    verb, args = seg[i], seg[i + 1:]
    value = alias.get(verb.lower())
    if value is not None:
        if value.startswith('!'):
            return where, '!', [value[1:]]
        try:
            words = shlex.split(value)
        except ValueError:
            words = value.split()
        if not words:
            return None
        verb, args = words[0], words[1:] + args
    return where, verb, args


def cycle_call(seg):
    """(verb, rest) of a simple command that runs cycle.sh (directly or through a shell), else None."""
    i = command_word(seg)
    if i < len(seg) and base(seg[i]) in SHELLS:
        i += 1
        while i < len(seg) and seg[i].startswith('-'):
            i += 1
    if i + 1 < len(seg) and base(seg[i]) == 'cycle.sh':
        return seg[i + 1], seg[i + 2:]
    return None


def driver_held(cwd):
    """True when a docs/specs/*/DRIVER file exists in cwd or a parent, up to the first folder holding .git."""
    d = os.path.abspath(cwd)
    while True:
        if glob.glob(os.path.join(glob.escape(d), 'docs', 'specs', '*', 'DRIVER')):
            return True
        up = os.path.dirname(d)
        if os.path.exists(os.path.join(d, '.git')) or up == d:
            return False
        d = up


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
    if verb not in VERBS:
        return None
    s, l = flags(args)
    forced = 'f' in s or '--force' in l
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
        if s & {'b', 'B'} or '--orphan' in l:          # a new branch keeps the tree, unless forced
            if forced:
                return [], 't', True
            return ([], '', False) if 'B' in s else None   # -B resets an existing branch: its commits
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
    if verb == 'reset':                                # --merge drops a file's changes the reset touches, like --hard
        return ([], 't', True) if ('--hard' in l or '--merge' in l) else None
    if verb == 'merge':                                # --abort resets the tree to the pre-merge head
        return ([], 't', True) if '--abort' in l else None
    if verb == 'clean':
        if 'n' in s or '--dry-run' in l:
            return None
        if 'f' in s or '--force' in l:
            return positionals(args, ('-e', '--exclude')), 'u', True
        return None
    if verb == 'switch':
        if forced or '--discard-changes' in l:
            return [], 't', True
        return ([], '', False) if ('C' in s or '--force-create' in l) else None
    if verb == 'branch':                               # -D, -f, -M, -C and -d --force move or delete by force
        return ([], '', False) if (s & {'D', 'M', 'C'} or forced) else None
    if verb == 'worktree':
        if args and args[0] == 'remove' and forced:
            pos = positionals(args[1:])
            return (['@worktree', pos[0]] if pos else [], 't' + 'u', True)
        return None
    if verb == 'rm':
        if '--cached' in l or 'n' in s or '--dry-run' in l or not forced:
            return None
        return positionals(args, ('--pathspec-from-file',)), 't', True
    if verb == 'checkout-index':
        if not forced:
            return None
        return ([] if ('a' in s or '--all' in l) else positionals(args, ('--prefix', '--stage'))), 't', True
    if verb == 'read-tree':
        return ([], 't', True) if ('u' in s and ('m' in s or '--reset' in l)) else None
    if verb == 'update-ref':                           # deletes or moves a ref by force: no read-only form
        return ([], '', False) if args else None
    return None


def status(cwd, paths, fake):
    """Porcelain v1 entries [(xy, path)] under paths ([] = all); None when git status fails there.
    Raises subprocess.TimeoutExpired when git status does not answer in time. Under --check a fake
    {"sleep": S, "timeout": T} runs a stub that takes S seconds against a T-second timeout."""
    if isinstance(fake, str):
        text = fake
    else:
        cmd = ['git', '-c', 'core.quotePath=false', '-C', cwd, 'status', '--porcelain', '--untracked-files=all']
        if paths:
            cmd += ['--'] + paths
        limit = 8
        if isinstance(fake, dict):
            cmd = [sys.executable, '-S', '-c', 'import time; time.sleep(%f)' % float(fake.get('sleep', 0))]
            limit = float(fake.get('timeout', limit))
        r = subprocess.run(cmd, capture_output=True, timeout=limit)
        if r.returncode != 0:
            return None
        text = r.stdout.decode('utf-8', 'replace')
    out = []
    for line in text.splitlines():
        if len(line) > 3:
            p = line[3:].split(' -> ')[-1].strip('"')
            if isinstance(fake, str) and paths and not any(
                    q in ('.', '') or p == q.rstrip('/') or p.startswith(q.rstrip('/') + '/') for q in paths):
                continue
            out.append((line[:2], p))
    return out


UNREAD = -1    # a story whose tier the hook cannot read: the main session is denied (fails closed)


def story_tier(base, story):
    """The leading digit of the first **Tier:** line of the story's plan.md, else None; UNREAD when the
    story token holds a variable or a substitution ($, backtick, %) or its plan.md cannot be read."""
    if re.search(r'[$`%]', story):
        return UNREAD
    plan = os.path.join(base, os.path.dirname(story), 'plan.md')
    try:
        with open(plan, encoding='utf-8', errors='replace') as f:
            for line in f:
                if line.startswith('**Tier:**'):
                    m = re.match(r'\s*([1-4])', line[len('**Tier:**'):])
                    return int(m.group(1)) if m else None
    except OSError:
        return UNREAD
    return None


def closes_story(seg):
    """The story path of a `cycle.sh close-story <story>` simple command, else None."""
    for k, w in enumerate(seg[:-2]):
        if os.path.basename(w.replace('\\', '/')) == 'cycle.sh' and seg[k + 1] == 'close-story':
            return seg[k + 2]
    return None


def deny(reason):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                             "permissionDecision": "deny",
                                             "permissionDecisionReason": reason}}))
    sys.exit(1 if CHECK else 0)


def main():
    try:
        data = json.loads(sys.stdin.buffer.read().decode('utf-8-sig', 'replace'))   # UTF-8 bytes, BOM or not
    except Exception:
        sys.exit(0)
    if not isinstance(data, dict):
        sys.exit(0)
    tool = str(data.get('tool_name') or '')
    if tool not in ('Bash', 'PowerShell'):
        sys.exit(0)
    cmd = (data.get('tool_input') or {}).get('command')
    if not isinstance(cmd, str) or ('git' not in cmd and 'close-story' not in cmd and 'cycle.sh' not in cmd):
        sys.exit(0)
    sub = bool(data.get('agent_id'))
    cwd = str(data.get('cwd') or os.getcwd())
    fake = data.get('porcelain') if CHECK else None

    def parse(text, powershell):
        """The simple commands of text; an unreadable one is the end for a subagent's git call."""
        segs = split_segments(drop_heredocs(text), powershell)
        if segs is None:
            if sub and re.search(r'(^|[\s;&|(])git(\.exe)?\s', text):
                deny('VULYK git guard: this git call cannot be read (its quotes do not close), and a subagent may '
                     'not run a git command that can throw away work. Leave the tree as it is and report the step '
                     'instead.')
            return []
        return segs

    work = parse(cmd, tool == 'PowerShell')
    held = None                                      # a DRIVER file, looked up once, on the first commit or add
    here = cwd                                       # follows each cd of the command, in order
    k = 0
    while k < len(work):
        seg = work[k]
        k += 1
        fed = fed_string(seg)                        # `bash -c <s>`: its commands are read next, in place
        if fed is not None:
            work[k:k] = parse(*fed)
            continue
        moved = cd_target(seg, here)
        if moved is not None:
            here = moved
            continue
        cyc = cycle_call(seg) if sub else None
        if cyc and (cyc[0] not in CYCLE_OK or (cyc[0] == 'stamp-red'
                                               and any(a.split('=', 1)[0] == '--baseline' for a in cyc[1]))):
            deny('VULYK git guard: a subagent may not run `cycle.sh %s` - its cycle.sh verbs are advance, status, '
                 'release, suite, stamp-red (never with --baseline) and close-story; the rest are the Queen\'s or '
                 'the owner\'s. Report the step under ## Findings and return NEEDS_CONTEXT.'
                 % ' '.join([cyc[0]] + cyc[1]))
        story = None if sub else closes_story(seg)
        tier = story_tier(cwd if here == UNKNOWN else here, story) if story else None
        if tier == UNREAD:
            deny('VULYK Law 5: `cycle.sh close-story %s` from the main session - the hook cannot tell this '
                 'story\'s tier (the path holds a variable or a substitution, or its plan.md cannot be read), '
                 'and a Tier 3-4 story is closed by its worker. Name the story by its literal path, or dispatch '
                 'its worker again, or stop for the owner, who can close it in their own terminal.' % story)
        if (tier or 0) >= 3:
            deny('VULYK Law 5: `cycle.sh close-story %s` from the main session - this is a Tier 3-4 story, so its '
                 'worker closes it and the Queen never finishes a returned worker\'s story herself, nor edits '
                 'its files. Write the error under its ## Findings and dispatch its worker again, or stop for '
                 'the owner, who can close it in their own terminal.'
                 % story)
        call = git_call(seg)
        if not call:
            continue
        where, verb, args = call
        if verb == '!':                              # a `-c alias.<name>=!<command>`: a shell command
            work[k:k] = parse(args[0], False)
            continue
        if sub and verb in ('commit', 'add'):
            if held is None:
                held = driver_held(cwd)
            if held:
                deny('VULYK git guard: a subagent may not run `git %s` while a docs/specs/*/DRIVER file holds a '
                     'spec - close-story commits the story\'s paths, and a commit of your own hides edits from '
                     'its scope check. Leave the tree as it is.' % verb)
        if sub and re.search(r'[$`]', verb):
            deny('VULYK git guard: the verb of `%s` cannot be read (it holds a variable or a substitution), and '
                 'a subagent may not run a git command that can throw away work. Spell the verb out, or leave '
                 'the tree as it is and report the step instead.' % ' '.join(seg))
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
        timed_out = False
        try:
            entries = status(base, paths, fake)
            if entries is None and not blind:        # a folder git cannot read (a Git Bash /tmp on Windows)
                entries = status(cwd, [], fake)
            entries = entries or []
        except subprocess.TimeoutExpired:
            timed_out = True
        except Exception:
            continue
        if timed_out:
            deny('VULYK git guard: `%s` - git status timed out, cannot prove the tree is clean. Commit or leave '
                 'the work as it is, or run the command yourself in your own terminal.' % shown)
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
    sys.exit(3)    # an error inside this half: the bash part denies a command naming git, as for a crash
PYTHON
