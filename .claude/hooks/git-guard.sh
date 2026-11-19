#!/usr/bin/env bash
# PreToolUse hook (matcher Bash|PowerShell): denies the git verbs that throw away uncommitted work or commits
# (spec uncommitted-work-guard, card docs/defects/work-discarded-by-git-verb.md), and a subagent's shell calls on
# the cycle's run state, on cycle.sh verbs that are not its own and, during a build, on git history (guards-1115).
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
# A line continuation (backslash-newline, PowerShell backtick-newline) is joined before reading; a `#` comment
# ends at its newline; quotes are followed across lines. Redirections (`2>/dev/null`, `>f`, `2>&1`) are taken out
# of a command wherever they stand. The command word is found past assignments, the shell keywords
# if/then/else/elif/do/while/until and `!`, `command`, `exec`, `time` and their options (`time -p`, `exec -a <name>`),
# and the wrappers env, timeout, nohup, nice, sudo and xargs (by basename, `/usr/bin/env git`; their options and
# values, env's assignments and timeout's duration skipped; the first git, cycle.sh, eval, shell or wrapper word
# after one is the command word, a word made by a variable before it being read as an option or its value; with
# none, a program word made by a variable or a pattern is judged as itself, and for a subagent one the command does
# not set is denied when its next words read as a cycle.sh verb outside the six or a listed git verb); a shell's
# options and the values they carry (`-euo pipefail`, `--rcfile <file>`) are skipped before its script or command
# string; `eval <words>`, and the main session's PowerShell evaluate-a-string command, are read as the command
# their words make. This parser serves every caller.
#   - A subagent (the input carries agent_id) is read on every shell call, with no text prefilter, and is denied:
#     every listed verb, with no git status call, and any git call whose arguments cannot be read (unbalanced
#     quotes, a verb holding $ or a backtick);
#     a shell call on the run state, `.vulyk/state/` judged by resolved path (`..`, links, letter case): a path
#     word or a redirect target under it (a glob is expanded; an echo or printf word and a grep pattern are text),
#     a cd into it, or text handed to a shell or an interpreter (`-c`, `-e`, a script read from stdin) that names
#     it; the reason names the Read tool for reading a record;
#     a script or program whose name cannot be read: the name a shell runs, or the command word, is read after
#     quote removal, a variable is resolved from an assignment or a `for` list in the same command, a glob is
#     matched against cycle.sh, a `${name:-default}` read as its default and as each value the command gives the
#     name (a command word whose default or value names git, cycle.sh, a shell, a wrapper or eval is judged as that
#     program; a value of several words is also read split, as an unquoted word is); a file name still holding $
#     or a backtick, a substitution anywhere in the name, or a script, program or command string that xargs hands
#     in (from its input, or through its replace string) is denied ("spell the script path") unless the shell
#     only checks syntax (`bash -n`); a variable only in the folder part passes, judged by its literal file name
#     (cycle.sh by the verb rule below);
#     every cycle.sh verb but advance, status, release, suite, stamp-red (never with --baseline) and close-story,
#     a verb, or a stamp-red argument, that is not literal, a verb xargs hands in, and stamp-red behind xargs;
#     while a docs/specs/*/DRIVER file exists in the repository the git command acts on (each cd and -C
#     followed where it takes effect: a cd in a subshell, or in a command string handed to a shell or a `!` alias,
#     moves only that child (one in eval moves the caller), one in a pipeline or the
#     background or with two folder words moves nothing, one after || makes the place unknown; --git-dir,
#     --work-tree, GIT_DIR and GIT_WORK_TREE judged by the place they name; a place the hook cannot read counts
#     as held), every verb that stages, makes a commit, or moves a branch or HEAD: add, stage,
#     commit, commit-tree, merge, cherry-pick, am, revert, rebase, pull, push, reset, checkout, switch, mv, rm,
#     bisect, filter-branch, restore --staged, apply --cached / --index / --3way, update-index (but --chmod), the
#     writing forms of branch, symbolic-ref and notes, worktree add -b / -B, and a fetch into a named ref.
#     close-story commits the story's paths. Git reads and `git update-index --chmod` pass.
#   - Every caller, the main session too, is denied `git tag -f` / `--force` and a forced push (-f, --force,
#     --force-with-lease, a `+` refspec, --mirror): forms no agent needs (the owner's answer); the owner runs them
#     in his own terminal. A subagent is also denied PowerShell's Invoke-Expression (`iex`); the main session may
#     run it (the owner's answer of 2026-11-16), its string read as commands.
#   - Beyond those, the main session is denied only when `git status --porcelain` shows the paths the verb would
#     discard dirty (tracked) or untracked (clean -f, stash -u); the reason names them, 10 at most then
#     `+N more`, and gives the safe path. The forms that lose a stash or commits, not tree files, are denied
#     to subagents only. A git status that times out denies: it cannot prove the tree is clean.
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
# 1 outside --check included (Python's own status for an uncaught error), on a command naming git (or, for a
# subagent, one the fallback's text rules below deny) is a deny that says the guard failed. An error inside the
# Python half exits 3, so it is denied the same way. Hook stdin is read as bytes, decoded UTF-8 (a BOM tolerated).
# No Python at all: a bash fallback denies every listed verb that follows a `git` word, for any caller, in Bash and
# PowerShell, reading the words of a `-c alias.<name>=` value as commands too and skipping redirections. It reads
# every word of the command, quoted or not. For a subagent it also denies, by text: a command naming the run state;
# a cycle.sh word (quotes removed, a glob matched) with a verb outside the six, a verb holding $ or a backtick, or
# stamp-red with --baseline; a shell's script word holding $ or a backtick unless the shell only checks syntax;
# and, while a docs/specs/*/DRIVER exists in the call's cwd or a parent, every history verb above after a `git`
# word (update-index only with --chmod passes). Other git commands pass.
# Passes silently: bad JSON, a main-session command naming neither git, cycle.sh nor PowerShell's evaluate-a-string
# command.
# `--check <file>` (the card's check): reads hook input from <file>; a `porcelain` field stands in for
# `git status --porcelain` (an object {"sleep": S, "timeout": T} stands in for a git status that takes S
# seconds against a T-second timeout). Exit 1 on a deny (the reason on stdout), 0 otherwise, also for a file that
# is no hook input.
# The Python half lives below the `exit 0`, inside a no-op heredoc, as in defect-intake.sh. The bash part uses
# builtins only, so an empty PATH still runs it.
#
# The guards stop accidents and shortcuts of a cooperative agent, not an adversary.
# Left open (the card's ## Check carries this list word for word):
#   - rm and Remove-Item, and a ref checkout over an untracked file;
#   - a script file run by a shell, and any other interpreter that runs git;
#   - command text piped into a shell, a here-string fed to a shell, an encoded PowerShell command, a PowerShell
#     here-string fed to a shell, and wrapper commands the hook does not know (a shell function or alias of the
#     session among them);
#   - an alias defined in git config rather than on the command line;
#   - a variable or substitution in an argument after the git verb;
#   - the run state reached by a name the command never spells (a parent folder walked by a recursive tool, a
#     folder reached by a cd the hook cannot follow), a redirect glued to the word before it, a target holding an
#     unresolved part beside the run state, and a move, copy, unpack or delete of a folder that holds it;
#   - while a DRIVER holds the repository, a subagent's git verbs off the history list above (tags, plumbing,
#     imports, config and remote edits, an alias set in git config), and command positions and global options the
#     parser does not know (a git word made by a substitution among them);
#   - for a subagent, a cycle.sh verb or script handed in by a program other than xargs, a program word behind a
#     wrapper option the hook does not know to take a value or behind a command string a wrapper runs, a program
#     behind a wrapper held in a variable the command does not set whose words read as no guarded verb, or one
#     followed on its line by a git, shell or cycle.sh word, and a command line after a heredoc whose end word the
#     hook reads short;
#   - refused although harmless (known over-denies, 0.55.0): for a subagent, a program word held in a variable the
#     command does not set, or sets from a substitution, whatever its words name;
#   - history rewrites other than a forced tag or push (rebase, amend, reflog expiry, gc pruning, history
#     filtering, the other remote forms) by the main session, and by a subagent while no DRIVER holds the repository;
#   - with no Python: a variable command word, a cd it does not follow (the cwd's DRIVER counts), a forced tag or
#     push, PowerShell's evaluate-a-string command, and a cycle.sh verb or script that xargs hands in;
#   - a mod that answers tool.check (on a personal login it can approve a call this hook denied: the SessionStart
#     brief names such a mod).
GUARD_VERBS='stash checkout restore reset merge clean switch branch worktree rm checkout-index read-tree update-ref'
HIST_VERBS=' add stage commit commit-tree merge cherry-pick am revert rebase pull push reset checkout switch mv rm restore apply bisect filter-branch update-index branch symbolic-ref notes '
CYCLE_OK=' advance status release suite stamp-red close-story '
CYCLE_OTHER=' reanchor judge escalate briefed branch record-seat pause resume claim manual-done revise open-round reopen repair '
ARG1="${1:-}"
if [ "$ARG1" = "--check" ]; then
  [ -f "${2:-}" ] || exit 0
  IFS= read -r -d '' IN < "$2"
else
  IFS= read -r -d '' IN   # a builtin: no `cat`, so an empty PATH still exits 0 in silence
fi
SUB=; re='"agent_id"[[:space:]]*:[[:space:]]*"[^"]'
[[ $IN =~ $re ]] && SUB=1                    # a subagent: no text prefilter, every shell call is read
[ -n "$SUB" ] || case "$IN" in *git*|*close-story*|*cycle.sh*|*[Ii][Ee][Xx]*|*[Ii]nvoke-[Ee]xpression*) ;; *) exit 0 ;; esac

fb_deny() { # fb_deny <reason> - prints the deny line (quotes and backslashes dropped from the reason) and exits
  local r="${1//\\/}"; r="${r//\"/}"
  printf '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "%s"}}\n' "$r"
  [ "$ARG1" = "--check" ] && exit 1
  exit 0
}

fb_scan() { # sets FB_RAW (the command), FB_GIT (it has a git word), FB_HIT (the first listed verb that follows
  # one) and FB_HV (the first history verb that follows one)
  FB_RAW=; FB_GIT=; FB_HIT=; FB_HV=
  local re c w b v state=0 IFS=' '
  re='"tool_name"[[:space:]]*:[[:space:]]*"(Bash|PowerShell)"'
  [[ $IN =~ $re ]] || return 0
  re='"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'
  [[ $IN =~ $re ]] || return 0
  c="${BASH_REMATCH[1]}"; FB_RAW="$c"
  # JSON escapes, then every quote and operator, become word breaks; a redirection stays a word of its own
  c="${c//\\\\/ }"; c="${c//\\n/ }"; c="${c//\\t/ }"; c="${c//\\r/ }"; c="${c//\\\"/ }"
  c="${c//;/ }"; c="${c//&/ }"; c="${c//|/ }"; c="${c//(/ }"; c="${c//)/ }"; c="${c//\{/ }"; c="${c//\}/ }"
  c="${c//</ < }"; c="${c//>/ > }"; c="${c//\'/ }"; c="${c//\`/ }"; c="${c//	/ }"
  set -f
  for w in $c; do
    case $state in
      0) b="${w##*/}"
         case "$b" in [Gg][Ii][Tt]|[Gg][Ii][Tt].[Ee][Xx][Ee]) FB_GIT=1; state=1 ;; esac ;;
      1) case "$w" in
           -C|-c|--git-dir|--work-tree|--namespace) state=2 ;;
           '<'|'>') state=3 ;;
           -*|[0-9]|[0-9][0-9]) ;;
           *) b="${w##*/}"
              case "$b" in [Gg][Ii][Tt]|[Gg][Ii][Tt].[Ee][Xx][Ee]) continue ;; esac   # a git word: a new git call
              case " $GUARD_VERBS " in *" $w "*) FB_HIT="$w"; return 0 ;; esac
              [ -z "$FB_HV" ] && case "$HIST_VERBS" in *" $w "*) FB_HV="$w" ;; esac
              state=0 ;;
         esac ;;
      2) state=1
         case "$w" in
           [Aa][Ll][Ii][Aa][Ss].*=*)
             v="${w#*=}"; v="${v#!}"
             case " $GUARD_VERBS " in *" $v "*) FB_HIT="$v"; return 0 ;; esac
             [ -z "$FB_HV" ] && case "$HIST_VERBS" in *" $v "*) FB_HV="$v" ;; esac ;;
         esac ;;
      3) state=1 ;;                                    # a redirection's target
    esac
  done
  return 0
}

fb_sub() { # sets FB_SUBR: the subagent rule FB_RAW breaks, read by its text (no Python), else empty
  FB_SUBR=
  local c w b st=0 synt= re IFS=' '
  c="${FB_RAW//\'/}"; c="${c//\\\"/}"; c="${c//\"/}"   # quotes removed, not word breaks: `cy''cle.sh` is cycle.sh
  re='[Vv][Uu][Ll][Yy][Kk](/|\\)+[Ss][Tt][Aa][Tt][Ee]'
  [[ $c =~ $re ]] && { FB_SUBR='it names the run state, which only cycle.sh writes; read a record with the Read tool'; return 0; }
  c="${c//\\\\//}"; c="${c//\\n/ }"; c="${c//\\t/ }"; c="${c//\\r/ }"
  c="${c//;/ }"; c="${c//&/ }"; c="${c//|/ }"; c="${c//(/ }"; c="${c//)/ }"; c="${c//\{/ }"; c="${c//\}/ }"
  c="${c//</ }"; c="${c//>/ }"; c="${c//	/ }"
  set -f
  for w in $c; do
    case $st in
      g) st=0                                          # after a glob that matches cycle.sh: a verb not its own
         case "$CYCLE_OTHER" in *" $w "*) FB_SUBR="cycle.sh $w is not a subagent verb"; return 0 ;; esac ;;
      c) st=0
         case "$w" in *[\$\`]*) FB_SUBR="a cycle.sh verb it cannot read"; return 0 ;; esac
         case "$CYCLE_OK" in *" $w "*) ;; *) FB_SUBR="cycle.sh $w is not a subagent verb"; return 0 ;; esac
         if [ "$w" = stamp-red ]; then
           case "$c" in *--baseline*) FB_SUBR='cycle.sh stamp-red --baseline is the Queens'; return 0 ;; esac
         fi
         continue ;;
      s) case "$w" in
           --*|+*) continue ;;
           -*c*) st=0; continue ;;                     # a command string: its words are read on
           -*n*) synt=1; continue ;;
           -*) continue ;;
         esac
         st=0
         case "$w" in *[\$\`]*) [ -z "$synt" ] && { FB_SUBR="a script word it cannot read; spell the script path"; return 0; } ;; esac ;;
    esac
    b="${w##*/}"
    if [ "$b" = cycle.sh ]; then st=c; continue; fi
    if [[ cycle.sh == $b ]]; then st=g; continue; fi
    case "$b" in bash|sh|zsh|dash|ksh|bash.exe|sh.exe) st=s; synt= ;; esac
  done
  return 0
}

fb_held() { # true when a docs/specs/*/DRIVER exists in the call's cwd or a parent, up to the folder holding .git
  local d up f re='"cwd"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'
  set +f
  d="$PWD"; [[ $IN =~ $re ]] && d="${BASH_REMATCH[1]//\\\\//}"
  while :; do
    for f in "$d"/docs/specs/*/DRIVER; do [ -e "$f" ] && return 0; done
    [ -e "$d/.git" ] && return 1
    up="${d%/*}"
    { [ "$up" = "$d" ] || [ -z "$up" ]; } && return 1
    d="$up"
  done
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
    *) fb_scan; FB_SUBR=
       [ -n "$SUB" ] && fb_sub
       [ -n "$FB_GIT$FB_SUBR" ] && fb_deny "VULYK git guard: the guard failed (its Python exited $rc) on a git command, so the command is denied. Fix that Python or set VULYK_PY to a working one; the owner can run the command in their own terminal." ;;
  esac
done
fb_scan
[ -n "$FB_HIT" ] && fb_deny "VULYK git guard: no Python, so the bash fallback denies every git $FB_HIT, from anyone: it cannot read which paths the command would touch. Install Python 3 or set VULYK_PY; the owner can run the command in their own terminal."
if [ -n "$SUB" ]; then
  fb_sub
  [ -n "$FB_SUBR" ] && fb_deny "VULYK git guard: no Python, so the bash fallback reads a subagent's command by its text and denies it: $FB_SUBR. Install Python 3 or set VULYK_PY; report the step under ## Findings if the story needs it."
  if [ -n "$FB_HV" ] && fb_held; then
    case "$FB_HV $FB_RAW" in
      "update-index "*--chmod*) ;;
      *) fb_deny "VULYK git guard: no Python, so the bash fallback denies a subagent every git $FB_HV while a docs/specs/*/DRIVER file holds a spec: close-story commits the story's paths. Leave the tree as it is; install Python 3 or set VULYK_PY." ;;
    esac
  fi
fi
exit 0

: <<'PYTHON'
#<py>
import fnmatch, glob, itertools, json, os, re, shlex, subprocess, sys

CHECK = len(sys.argv) > 1 and sys.argv[1] == '--check'
CAP = 10
SEP = {';', '&&', '||', '|', '&', '\n', '(', ')', '{', '}'}
VERBS = ('stash', 'checkout', 'restore', 'reset', 'merge', 'clean', 'switch', 'branch', 'worktree', 'rm', 'checkout-index', 'read-tree', 'update-ref')
SHELLS = ('bash', 'sh', 'zsh', 'dash', 'ksh', 'pwsh', 'powershell')
INTERPS = ('python', 'python3', 'py', 'node', 'perl', 'ruby', 'php', 'deno', 'bun', 'osascript', 'awk', 'tclsh', 'lua')
# a shell named as a command word somewhere on a heredoc's line: `bash <<X`, `cat <<X | sh`
SHELL_RE = re.compile(r'(^|[\s;&|(])([^\s;&|()<>]*[/\\])?(%s)(\.exe)?(?=$|[\s;&|)<])' % '|'.join(SHELLS), re.I)
HEREDOC_RE = re.compile(r'<<(?!<)-?[ \t]*([\'"]?)([A-Za-z_][A-Za-z0-9_]*)\1')
CYCLE_OK = ('advance', 'status', 'release', 'suite', 'stamp-red', 'close-story')
CYCLE_OTHER = ('reanchor', 'judge', 'escalate', 'briefed', 'branch', 'record-seat', 'pause', 'resume', 'claim',
               'manual-done', 'revise', 'open-round', 'reopen', 'repair')   # the bash part's CYCLE_OTHER
STATE_RE = re.compile(r'vulyk[\\/]+state', re.I)
TEXT_CMDS = ('echo', 'printf', 'write-output', 'write-host')
GREPS = ('grep', 'egrep', 'fgrep', 'rg', 'select-string')
EVAL_STRING = ('iex', 'invoke-expression')
EVAL_RE = re.compile(r'iex|invoke-expression', re.I)


def base(word):
    """The lower-case basename of a command word, `.exe` dropped."""
    b = os.path.basename(word.replace('\\', '/')).lower()
    return b[:-4] if b.endswith('.exe') else b


def as_code(cmd, powershell):
    """The command as code: each `#` comment cut up to its newline, and each heredoc body cut (its lines are text)
    unless the heredoc's line names a shell (`bash <<X`, `cat <<X | sh`: the body is a script, read as commands).
    Quotes are followed across lines, so a `#` or a `<<` inside a string is neither; `<<<` is no heredoc."""
    esc = '`' if powershell else '\\'
    lines, out, q, i = cmd.split('\n'), [], None, 0
    while i < len(lines):
        line, keep, ends, j = lines[i], [], [], 0
        i += 1
        while j < len(line):
            ch = line[j]
            if q:
                if ch == esc and q == '"' and j + 1 < len(line):
                    keep.append(line[j:j + 2]); j += 2; continue
                if ch == q:
                    q = None
                keep.append(ch); j += 1; continue
            if ch == esc and j + 1 < len(line):
                keep.append(line[j:j + 2]); j += 2; continue
            if ch in '\'"':
                q = ch
            elif ch == '#' and (j == 0 or line[j - 1] in ' \t;&|()'):
                break                                   # a comment: the rest of the line
            elif ch in '<>' and line[j + 1:j + 2] == '&':
                keep.append(ch + '\x01'); j += 2; continue   # >&, <&: a descriptor, not a command break
            elif ch == '&' and line[j + 1:j + 2] == '>':
                keep.append('\x01'); j += 1; continue        # &>: both streams to a file
            elif ch == '<' and not (j and line[j - 1] == '<'):
                m = HEREDOC_RE.match(line, j)
                if m:
                    ends.append(m.group(2)); keep.append(line[j:m.end()]); j = m.end(); continue
            keep.append(ch); j += 1
        code = ''.join(keep)
        out.append(code)
        if ends and q is None:
            script = SHELL_RE.search(HEREDOC_RE.sub(' ', code))
            for end in ends:
                body = []
                while i < len(lines) and lines[i].strip() != end:
                    body.append(lines[i]); i += 1
                i += 1
                if script:
                    lines[i:i] = body                   # a script: its lines are read next, as commands
    return '\n'.join(out)


CD = ('cd', 'chdir', 'pushd', 'popd', 'set-location', 'sl', 'push-location', 'pop-location')
UNKNOWN = ''   # a cd the hook cannot follow: the whole tree of the call's cwd is checked instead


def native(t):
    """A path word as this Python reads it: `~` expanded, Git Bash /e/x -> e:/x on Windows."""
    m = re.match(r'^/([A-Za-z])(/.*)?$', t)
    if os.name == 'nt' and m:
        t = m.group(1) + ':' + (m.group(2) or '/')
    return os.path.expanduser(t)


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
    if len(args) > 1 and len(args) == len(seg) - 1:
        return now                                  # `cd a b` fails (too many arguments): it does not move
    t = args[0]
    if re.search(r'[$`%]', t):                      # a variable or a command substitution
        return UNKNOWN
    t = os.path.join(now, native(t))
    return t if os.path.isdir(t) else UNKNOWN


SCOPES = itertools.count(1)


class Seg(list):
    """A simple command's words, with the subshell it runs in (scope: the open subshells, outermost first) and the
    operators before (pre) and after (post) it, so a cd is followed only where it takes effect."""
    scope, pre, post = (), ';', ';'


def cd_effect(seg):
    """'no' for a cd that never moves the next command (in a pipeline or the background), 'maybe' for one that may
    not run (after ||), else 'yes'. A cd inside a subshell is kept to that subshell by its scope."""
    if seg.pre == '|' or seg.post in ('|', '&'):
        return 'no'
    return 'maybe' if seg.pre == '||' else 'yes'


def split_segments(cmd, powershell):
    """Shell words cut into simple commands; None when the quotes do not close. A line continuation
    (backslash-newline in Bash, backtick-newline in PowerShell) is joined first: one command, not two."""
    cmd = cmd.replace('\r', '').replace('`\n' if powershell else '\\\n', '')
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=';&|()')
    lex.whitespace = ' \t'
    lex.whitespace_split = True
    lex.commenters = ''                             # as_code cut the comments, each up to its newline
    if powershell:
        lex.escape = '`'
    else:
        lex.escape = '\\'
    segs, cur, scope, pre = [], Seg(), (), ';'

    def close(post):
        nonlocal cur
        if cur:
            cur.scope, cur.pre, cur.post = scope, pre, post
            segs.append(cur)
        cur = Seg()

    try:
        for tok in lex:
            if tok in SEP or set(tok) <= set(';&|()\n'):
                kind = next((s for s in ('||', '&&', '|', '&') if s in tok), ';')
                close(kind)
                for ch in tok:                      # each ( opens a subshell, each ) closes the innermost
                    if ch == '(':
                        scope = scope + (next(SCOPES),)
                    elif ch == ')':
                        scope = scope[:-1]
                pre = kind
            elif '\n' in tok:
                parts = tok.split('\n')
                for i, p in enumerate(parts):
                    if p:
                        cur.append(p)
                    if i < len(parts) - 1 and cur:
                        close(';'); pre = ';'
            else:
                cur.append(tok)
    except ValueError:
        return None
    close(';')
    return segs


REDIR = re.compile(r'^(\d+|\*|\x01)?(<<<|<<-?|>>|>\||>\x01|<\x01|<>|>|<)(.*)$', re.S)   # as_code wrote & as \x01


def redirections(seg):
    """(words, targets): the simple command with its redirections taken out, and the files they name."""
    words, targets, i = [], [], 0
    while i < len(seg):
        m = REDIR.match(seg[i])
        if not m:
            words.append(seg[i]); i += 1
            continue
        op, rest = m.group(2), m.group(3)
        if op in ('>\x01', '<\x01') and re.fullmatch(r'\d+-?|-', rest):
            i += 1                                  # 2>&1, >&2, <&-: a descriptor, no file
            continue
        if not rest and i + 1 < len(seg):
            i += 1; rest = seg[i]
        if not op.startswith('<<'):
            targets.append(rest)
        i += 1
    return words, targets


KEYWORDS = ('if', 'then', 'else', 'elif', 'do', 'while', 'until', '!', '&', 'command', 'exec', 'time')
WRAPPERS = ('env', 'timeout', 'nohup', 'nice', 'sudo', 'xargs')
LANDS = ('git', 'cycle.sh', 'eval') + SHELLS + WRAPPERS   # a wrapper's options end at the first of these
# the wrapper options that take the next word as their value
WRAP_VALUED = {
    'env': ('-u', '--unset', '-C', '--chdir', '-S', '--split-string'),
    'timeout': ('-s', '--signal', '-k', '--kill-after'),
    'nice': ('-n', '--adjustment'),
    'sudo': ('-u', '--user', '-g', '--group', '-h', '--host', '-p', '--prompt', '-C', '--close-from', '-D',
             '--chdir', '-r', '--role', '-t', '--type', '-T', '--command-timeout', '-U', '--other-user'),
    'xargs': ('-I', '-n', '--max-args', '-L', '--max-lines', '-P', '--max-procs', '-s', '--max-chars', '-d',
              '--delimiter', '-E', '-a', '--arg-file'),
}
DYNAMIC = re.compile(r'[$`*?[]')   # a word made by a variable, a substitution or a pattern


def wrapped(seg, i):
    """The index of the word the wrapper at seg[i] runs: its options and their values, env's assignments and
    timeout's duration skipped."""
    w = base(seg[i])
    vals, k, need = WRAP_VALUED.get(w, ()), i + 1, 1 if w == 'timeout' else 0
    while k < len(seg):
        a = seg[k]
        if a == '--':
            return k + 1
        if a in vals:
            k += 2
        elif (a.startswith('-') and len(a) > 1) or (w == 'env' and (
                a == '-' or re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', a))):
            k += 1
        elif need:
            need, k = need - 1, k + 1
        else:
            break
    return k


def command_word(seg):
    """The index of the simple command's command word: assignments, shell keywords (then, do, else, !, ...),
    `&`, command, exec and time with their options skipped; behind a wrapper (env, timeout, nohup, nice, sudo,
    xargs) the next word that is git, cycle.sh, eval, a shell or another wrapper (a word made by a variable before
    it may be an option or its value), else the word it runs (options, values and a duration skipped)."""
    i = 0
    while i < len(seg):
        if re.match(r'^\$[A-Za-z_][A-Za-z0-9_]*$', seg[i]) and seg[i + 1:i + 2] == ['=']:
            i += 2                                  # PowerShell `$x = <command>`
        elif re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', seg[i]) or seg[i] in KEYWORDS:
            kw = seg[i]
            i += 1
            while kw in ('command', 'exec', 'time') and i < len(seg) and seg[i].startswith('-'):
                i += 2 if (kw == 'exec' and seg[i] == '-a') else 1
        elif base(seg[i]) in WRAPPERS:
            run = wrapped(seg, i)
            nxt = [j for j in range(i + 1, len(seg)) if base(seg[j]) in LANDS]
            if nxt:
                i = nxt[0]                              # `env $OPT git ...`: a variable there may be an option
            elif run < len(seg) and DYNAMIC.search(seg[run]):
                i = run                                 # `timeout 60 $c`, `nice scripts/cyc*.sh`: judged as made
            else:
                return run
        else:
            break
    return i


def shell_opts(seg, i):
    """For the Bash-like shell at seg[i]: (k, string, syntax), k the first word past its options and the values
    they carry (`-o pipefail`, `-euo pipefail`, `+O extglob`, `--rcfile <file>`), string True when a `-c` makes
    seg[k] its command string, syntax True for `-n`."""
    k, string, syntax = i + 1, False, False
    while k < len(seg):
        a = seg[k]
        if a == '--':
            return k + 1, string, syntax
        if a in ('--rcfile', '--init-file'):
            k += 2
        elif a.startswith('--'):
            k += 1
        elif a.startswith(('-', '+')) and len(a) > 1:
            string = string or (a[0] == '-' and 'c' in a[1:])
            syntax = syntax or (a[0] == '-' and 'n' in a[1:])
            k += 1 + a[1:].count('o') + a[1:].count('O')   # each o / O of a cluster takes the next word
        else:
            break
    return min(k, len(seg)), string, syntax


def fed_string(seg):
    """(text, powershell) when the simple command hands a shell a command string (`bash -c <s>`, `pwsh -Command
    <words>`, `eval <words>`), else None."""
    i = command_word(seg)
    if i < len(seg) and seg[i] == 'eval':
        return ' '.join(seg[i + 1:]), False
    if i < len(seg) and base(seg[i]) in EVAL_STRING:   # the main session's evaluated string, read as PowerShell
        return ' '.join(seg[i + 1:]), True
    if i >= len(seg) or base(seg[i]) not in SHELLS:
        return None
    if base(seg[i]) in ('pwsh', 'powershell'):
        for k in range(i + 1, len(seg)):
            low = seg[k].lower()
            if low == '-c' or (len(low) >= 4 and '-command'.startswith(low)):
                return ' '.join(seg[k + 1:]), True
        return None
    k, string, _ = shell_opts(seg, i)
    if string:
        return (seg[k] if k < len(seg) else ''), False
    return None                                         # a script file: not read


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


def git_places(seg, exported):
    """The places a git call is pointed at beside its cwd and -C: [(kind, value)], kind 'dir' (--git-dir,
    GIT_DIR) or 'tree' (--work-tree, GIT_WORK_TREE); exported: earlier `export GIT_DIR=` words of the command."""
    i, out = command_word(seg), []
    for w in seg[:i] + ['%s=%s' % kv for kv in exported.items()]:
        m = re.match(r'^GIT_(DIR|WORK_TREE)=(.*)$', w)
        if m:
            out.append(('dir' if m.group(1) == 'DIR' else 'tree', m.group(2)))
    i += 1
    while i < len(seg) and seg[i].startswith('-'):
        o, v = seg[i].split('=', 1) if '=' in seg[i] else (seg[i], None)
        if o in ('--git-dir', '--work-tree'):
            if v is None and i + 1 < len(seg):
                i += 1; v = seg[i]
            out.append(('dir' if o == '--git-dir' else 'tree', v or ''))
        elif o in ('-C', '-c', '--namespace') and v is None:
            i += 1
        i += 1
    return out


def driver_held(cwd):
    """True when a docs/specs/*/DRIVER file exists in cwd or a parent, up to the first folder holding .git;
    True too for a folder the hook cannot read (it may be held)."""
    if not cwd or not os.path.isdir(cwd):
        return True
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


HISTORY = ('add', 'stage', 'commit', 'commit-tree', 'merge', 'cherry-pick', 'am', 'revert', 'rebase', 'pull',
           'push', 'reset', 'checkout', 'switch', 'mv', 'bisect', 'filter-branch')
BRANCH_LIST = {'a', 'r', 'l', 'v'}
BRANCH_LIST_LONG = {'--list', '--all', '--remotes', '--show-current', '--contains', '--no-contains', '--merged',
                    '--no-merged', '--points-at', '--verbose', '--format', '--sort', '--color', '--no-color',
                    '--column', '--no-column', '--abbrev', '--no-abbrev', '--ignore-case', '--omit-empty'}


def rewrites_history(verb, args):
    """True when a git verb stages, makes a commit, or moves a branch or HEAD (a G2 verb under a DRIVER)."""
    s, l = flags(args)
    if verb in HISTORY:
        return True
    if verb == 'rm':
        return not ('n' in s or '--dry-run' in l)
    if verb == 'restore':
        return 'S' in s or '--staged' in l
    if verb == 'apply':
        return bool({'--cached', '--index', '--3way'} & l) or '3' in s
    if verb == 'update-index':
        opts = [a for a in args if a.startswith('-') and a != '--']
        return not opts or any(not o.startswith('--chmod') for o in opts)
    if verb == 'branch':
        if s & {'d', 'D', 'm', 'M', 'c', 'C', 'f', 'u', 't'} or l - BRANCH_LIST_LONG:
            return True
        return bool(positionals(args)) and not (s & BRANCH_LIST or l & BRANCH_LIST_LONG)
    if verb == 'symbolic-ref':
        return 'd' in s or '--delete' in l or len(positionals(args, ('-m',))) >= 2
    if verb == 'notes':
        pos = positionals(args, ('--ref',))
        return bool(pos) and pos[0] in ('add', 'append', 'copy', 'edit', 'merge', 'remove', 'prune')
    if verb == 'worktree':
        return bool(args) and args[0] == 'add' and bool(s & {'b', 'B'})
    if verb == 'fetch':
        return any(':' in p for p in positionals(args))
    return False


def forced_remote(verb, args):
    """True for `tag -f` and a forced push: denied to every caller (the owner's answer)."""
    s, l = flags(args)
    if verb == 'tag':
        return 'f' in s or '--force' in l
    if verb == 'push':
        return ('f' in s or bool({'--force', '--force-with-lease', '--mirror'} & l)
                or any(p.startswith('+') for p in positionals(args)))
    return False


def in_state(path):
    """True when path, resolved (`..`, links, letter case), lies in a project's run state `.vulyk/state/`."""
    try:
        p = os.path.realpath(path)
    except (OSError, ValueError):
        p = os.path.abspath(path)
    parts = [x.lower() for x in re.split(r'[\\/]+', os.path.normcase(p)) if x]
    return any(parts[i] == '.vulyk' and parts[i + 1] == 'state' for i in range(len(parts) - 1))


VAR_RE = re.compile(r'\$\{([A-Za-z_][A-Za-z0-9_]*)\}|\$([A-Za-z_][A-Za-z0-9_]*)')


def expand(word, env):
    """The values a word can take: its $name / ${name} variables resolved from env (name -> [values])."""
    outs = [word]
    for _ in range(4):
        new, changed = [], False
        for w in outs:
            m = VAR_RE.search(w)
            name = m and (m.group(1) or m.group(2))
            vals = env.get(name) if m else None
            if vals is None:
                vals = env.get(name.lower()) if m else None
            if vals is None:
                new.append(w)
                continue
            changed = True
            new.extend(w[:m.start()] + v + w[m.end():] for v in vals[:20])
        outs = new[:50]
        if not changed:
            break
    return outs


def note_vars(seg, env, exported):
    """Records the variables a simple command sets: `x=v`, `export x=v`, PowerShell `$x = v`, `for x in a b`."""
    if len(seg) >= 3 and seg[0] == 'for' and seg[2] == 'in':
        env[seg[1]] = seg[3:] or ['']
        return
    if len(seg) >= 3 and re.match(r'^\$[A-Za-z_][A-Za-z0-9_]*$', seg[0]) and seg[1] == '=':
        env[seg[0][1:].lower()] = [' '.join(seg[2:])]
        return
    exp = seg[0] in ('export', 'local', 'declare', 'readonly', 'typeset')
    words = [w for w in seg[1:] if not w.startswith('-')] if exp else seg
    if words and all(re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', w) for w in words):
        for w in words:
            n, v = w.split('=', 1)
            env[n] = [v]
            if exp and n in ('GIT_DIR', 'GIT_WORK_TREE'):
                exported[n] = v


SYNTAX = 'syntax'      # a shell that only checks syntax (`bash -n`): it runs nothing
UNREADABLE = None


def xargs_replace(seg, i):
    """The replace string of an xargs before seg[i] (`-I R`, `-IR`, `-i[R]`, `--replace[=R]`), else None."""
    for j in range(i):
        if base(seg[j]) != 'xargs':
            continue
        for k in range(j + 1, i):
            a = seg[k]
            if a == '-I' and k + 1 < i:
                return seg[k + 1]
            if a.startswith('-I') and len(a) > 2:
                return a[2:]
            if a.startswith('-i'):
                return a[2:] or '{}'
            if a.startswith('--replace'):
                return a.partition('=')[2] or '{}'
    return None


def cycle_named(word):
    """True when a script word names cycle.sh, spelled out or by a pattern that matches it."""
    b = base(word)
    return b == 'cycle.sh' or bool(re.search(r'[*?[]', b) and fnmatch.fnmatchcase('cycle.sh', b))


def handed_run(text, rep):
    """True when xargs's replace string rep, in the command string text, fills in what runs: a command word, a
    script word, a nested command string, a cycle.sh verb or a stamp-red argument."""
    segs = split_segments(as_code(text, False), False)
    if segs is None:
        return True
    for s in segs:
        s, _ = redirections(s)
        i = command_word(s)
        if i >= len(s):
            continue
        got, fed = run_word(s), fed_string(s)
        if rep in s[i] or (fed and handed_run(fed[0], rep)):
            return True
        if got and got != SYNTAX and got[0] is not UNREADABLE and rep in s[got[0]]:
            return True
        for n, w in enumerate(s[:-1]):
            if cycle_named(w) and (rep in s[n + 1] or (s[n + 1] == 'stamp-red' and any(rep in a for a in s[n + 2:]))):
                return True
    return False


def run_word(seg):
    """What the simple command runs: (index of the script or program word, behind_xargs), SYNTAX, None when it
    runs nothing a name can tell (a command string, a script read from stdin, PowerShell's file forms), or
    (UNREADABLE, True) when xargs hands in the script, the program or the command string (it comes from its
    input, or holds its replace string)."""
    i = command_word(seg)
    if i >= len(seg):
        return None
    xargs = any(base(w) == 'xargs' for w in seg[:i])
    rep = xargs_replace(seg, i) if xargs else None
    handed = lambda w: rep is not None and rep in w   # a word xargs fills in from its input
    b = base(seg[i])
    if b in ('pwsh', 'powershell'):
        return None
    if b in SHELLS or seg[i] in ('.', 'source'):
        k, string, syntax = shell_opts(seg, i)
        if string:                                      # a command string: fed_string reads it
            if xargs and (k >= len(seg) or (rep is not None and handed_run(seg[k], rep))):
                return UNREADABLE, True
            return None
        if syntax:
            return SYNTAX
        if k >= len(seg):
            return (UNREADABLE, True) if xargs else None
        return ((UNREADABLE, True) if handed(seg[k]) else (k, xargs))
    return (UNREADABLE, True) if handed(seg[i]) else (i, xargs)


def takes_text(seg):
    """True when the simple command hands a shell or an interpreter text to run: `-c` / `-e` code, or a script
    read from stdin (a pipe, a heredoc, `-`)."""
    i = command_word(seg)
    if i >= len(seg):
        return False
    b = base(seg[i])
    if b in SHELLS:
        return fed_string(seg) is not None or run_word(seg) is None
    if b not in INTERPS and not re.match(r'^python\d', b):
        return False
    rest = seg[i + 1:]
    if any(a in ('-c', '-e', '-E', '--eval', '-p', '--print', '-r', '-') for a in rest):
        return True
    return not [a for a in rest if not a.startswith('-')]


def path_words(seg, targets):
    """The words of a simple command that may name a path: every argument and redirect target, an `--opt=value`
    or `NAME=value` value too; an echo / printf word and a grep pattern are text, not paths."""
    i = command_word(seg)
    words = list(seg[:i])
    b = base(seg[i]) if i < len(seg) else ''
    if b not in TEXT_CMDS:
        rest = seg[i:]
        if b in GREPS:
            pat = [k for k, a in enumerate(rest) if k and not a.startswith('-')]
            given = any(a in ('-e', '-f', '--regexp', '--file', '-pattern') or a.startswith('--regexp=')
                        for a in rest)
            drop = set() if given or not pat else {pat[0]}
            drop |= {k + 1 for k, a in enumerate(rest) if a in ('-e', '--regexp', '-pattern')}
            rest = [a for k, a in enumerate(rest) if k not in drop]
        words += rest
    out = []
    for w in words + list(targets):
        out.append(w)
        if '=' in w:
            out.append(w.split('=', 1)[1])
    return out


def touches_state(seg, targets, here, cwd, env):
    """The word of a simple command that names the run state, else None."""
    root = cwd if here == UNKNOWN else here
    for w in path_words(seg, targets):
        for v in expand(w, env):
            if not v or re.search(r'[$`]', v):
                continue
            p = os.path.join(root, native(v))
            hits = [p] + (glob.glob(p)[:200] if re.search(r'[*?[]', v) else [])
            if any(in_state(h) for h in hits):
                return w
    return None


def deny(reason):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                             "permissionDecision": "deny",
                                             "permissionDecisionReason": reason}}))
    sys.exit(1 if CHECK else 0)


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


DEFAULT_RE = re.compile(r'\$\{[A-Za-z_][A-Za-z0-9_]*:?-([^${}`]+)\}')
DEFAULTED = re.compile(r'\$\{([A-Za-z_][A-Za-z0-9_]*):?[-=]([^${}`]*)\}')
# the programs a command word is judged as when a variable in it may name one: those whose words the hook reads on
READS = {'git', 'cycle.sh', 'eval', '.', 'source'} | set(SHELLS) | set(WRAPPERS) | set(EVAL_STRING)


def word_values(word, env):
    """The values a word can take: expand's, and for a `${name:-default}` both its default and each value the
    command gives the name."""
    outs = []
    for w in expand(word, env):
        m = DEFAULTED.search(w)
        if not m:
            outs.append(w)
            continue
        vals = env.get(m.group(1)) or env.get(m.group(1).lower()) or []
        outs.extend(w[:m.start()] + v + w[m.end():] for v in list(vals)[:20] + [m.group(2)])
    return outs[:50]


def variants(seg, env):
    """For a command word holding a variable: the words it stands for, once per program the hook reads through
    (git, cycle.sh, a shell, a wrapper, eval) that the word's default or a value from the command may name,
    spelled out; a value of several words (`C="bash x.sh revise"; $C`) is split as an unquoted word is; else None."""
    i = command_word(seg)
    if i >= len(seg) or '$' not in seg[i]:
        return None
    names = []
    for c in word_values(seg[i], env):
        if re.search(r'[$`]', c):
            continue
        for ws in [[c]] + ([c.split()] if len(c.split()) > 1 else []):
            if base(ws[0]) in READS and ws not in names:
                names.append(ws)
    return names or None


def as_git(seg, env):
    """seg with its command word spelled as git when that word holds a variable whose default (`${X:-git}`) or
    value from the command (`G=git; $G`) names git: a defaulted variable that names git is judged as git."""
    i = command_word(seg)
    if i >= len(seg) or '$' not in seg[i]:
        return seg
    for name in expand(seg[i], env):
        word = DEFAULT_RE.sub(r'\1', name)
        if base(word) == 'git':
            return seg[:i] + [word] + seg[i + 1:]
    return seg


def judge_run(seg, env, bash):
    """For a subagent: a deny reason for the script or program the simple command runs, else None. An
    unresolved PowerShell command word (`$x -ne 0` is an expression there) is not judged."""
    got = run_word(seg)
    if got is None or got == SYNTAX:
        return None
    k, xargs = got
    if k is UNREADABLE:
        return ('VULYK git guard: a subagent may not run a script, a program or a command string that xargs hands '
                'in - the hook cannot read what runs. Spell it out.')
    shell_script = k != command_word(seg)
    behind = not shell_script and any(base(w) in WRAPPERS for w in seg[:k])
    rep = xargs_replace(seg, k) if xargs else None
    words = lambda v: v.split() or [v]                 # an unquoted variable is split into words
    for whole in word_values(seg[k], env):             # a `${S:-default}` script word is read as its default too
        if behind and re.fullmatch(r'\$\{?[A-Za-z_][A-Za-z0-9_]*\}?', whole):
            # `timeout 60 $PY x.py`: a program the command does not set, judged by the words it is given
            tail = seg[k + 1:]
            if tail and (tail[0] in CYCLE_OTHER or classify(tail[0], tail[1:], '.') or (
                    tail[0] == 'stamp-red' and any(a.split('=', 1)[0] == '--baseline' for a in tail))):
                return ('VULYK git guard: a subagent may not run `%s` - its program is a variable the command does '
                        'not set, and its words read as an owner-only cycle.sh verb or a git verb that throws work '
                        'away. Spell the program.' % ' '.join(seg[k:]))
            continue
        # the value as one word (quoted) and as the words it splits into (unquoted): both are judged
        for name, extra in [(whole, [])] + ([(words(whole)[0], words(whole)[1:])] if len(words(whole)) > 1 else []):
            if re.search(r'[$`]', name) and not (shell_script or bash):
                continue
            b = base(DEFAULT_RE.sub(r'\1', name))     # `${X:-python3}` names its default
            if '`' in name or '$(' in name or re.search(r'[$`]', b):
                return ('VULYK git guard: a subagent may not run `%s` - the script or program name holds a '
                        'variable or a substitution the hook cannot resolve. Spell the script path.' % seg[k])
            # a variable only in the folder part: the literal file name says what runs, judged below
            if not cycle_named(name):
                continue
            tail = extra + seg[k + 1:]
            if not tail:
                if xargs:
                    return ('VULYK git guard: a subagent may not run cycle.sh with a verb that xargs hands in - the '
                            'hook cannot read which verb it is. Spell the verb.')
                continue
            why = judge_cycle(tail, env, xargs, rep)
            if why:
                return why
    return None


def judge_cycle(tail, env, xargs, rep):
    """For a subagent: a deny reason for cycle.sh run with the words tail (its verb first), else None."""
    for value in expand(tail[0], env):
        split = value.split() or [value]               # `v="stamp-red x"; cycle.sh $v`: the words it splits into
        verb, rest = split[0], split[1:] + tail[1:]
        if re.search(r'[$`*?[]', verb) or (rep is not None and rep in verb):
            return ('VULYK git guard: a subagent may not run cycle.sh with the verb `%s` - it is not literal. '
                    'Spell the verb.' % tail[0])
        if verb not in CYCLE_OK:
            return ('VULYK git guard: a subagent may not run `cycle.sh %s` - its cycle.sh verbs are advance, '
                    'status, release, suite, stamp-red (never with --baseline) and close-story; the rest are the '
                    'Queen\'s or the owner\'s. Report the step under ## Findings and return NEEDS_CONTEXT.'
                    % ' '.join([verb] + rest))
        if verb == 'stamp-red':
            if xargs:
                return ('VULYK git guard: a subagent may not run `cycle.sh stamp-red` behind xargs - its input can '
                        'add an argument (it could be --baseline). Spell each argument.')
            vals = [w for a in rest for v in expand(a, env) for w in (v.split() or [v])]
            if any(re.search(r'[$`*?[]', v) for v in vals):
                return ('VULYK git guard: a subagent may not run `cycle.sh stamp-red` with an argument that is '
                        'not literal (it could be --baseline). Spell each argument.')
            if any(v.split('=', 1)[0] == '--baseline' for v in vals):
                return ('VULYK git guard: a subagent may not run `cycle.sh stamp-red %s` - its cycle.sh verbs '
                        'are advance, status, release, suite, stamp-red (never with --baseline) and close-story.'
                        % ' '.join(rest))
    return None


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
    sub = bool(data.get('agent_id'))
    if not isinstance(cmd, str) or (not sub and 'git' not in cmd and 'close-story' not in cmd
                                    and 'cycle.sh' not in cmd and not EVAL_RE.search(cmd)):
        sys.exit(0)
    cwd = str(data.get('cwd') or os.getcwd())
    fake = data.get('porcelain') if CHECK else None
    state_msg = ('VULYK git guard: a subagent shell call on the run state is denied (`%s` names .vulyk/state/, '
                 'which only cycle.sh writes and the cycle trusts). Read a record with the Read tool; '
                 '`cycle.sh status` gives the cycle\'s view.')

    def parse(text, powershell):
        """The simple commands of text; an unreadable one is the end for a subagent's git call."""
        segs = split_segments(as_code(text, powershell), powershell)
        if segs is None:
            if sub and re.search(r'(^|[\s;&|(])git(\.exe)?\s', text):
                deny('VULYK git guard: this git call cannot be read (its quotes do not close), and a subagent may '
                     'not run a git command that can throw away work. Leave the tree as it is and report the step '
                     'instead.')
            return []
        return segs

    def inherit(segs, sc):
        """Commands handed on run inside the scope sc: the caller's own for eval, a new child scope for a shell."""
        for s in segs:
            s.scope = sc + s.scope
        return segs

    if sub and in_state(cwd):
        deny(state_msg % cwd)
    work = parse(cmd, tool == 'PowerShell')
    held = {}                                        # place -> a DRIVER file holds it, looked up once each
    here = cwd                                       # follows each cd of the command, in order
    heres = {(): cwd}                                # subshell scope -> where its shell stands
    env, exported = {}, {}                           # variables the command sets, for a subagent's script word
    k = 0
    while k < len(work):
        src = work[k]
        sc = getattr(src, 'scope', ())
        if sc not in heres:                          # a subshell starts where its parent stands
            p = sc
            while p not in heres:
                p = p[:-1]
            heres[sc] = heres[p]
        here = heres[sc]
        seg, targets = redirections(src)
        k += 1
        if not seg and not targets:
            continue
        alt = variants(seg, env) if seg else None
        if alt:                                      # `${S:-bash} -c ...`: judged as each program it may name
            i = command_word(seg)
            j = next(n for n, w in enumerate(src) if w is seg[i])
            news = []
            for a in alt:
                s2 = Seg(src[:j] + a + src[j + 1:])
                s2.scope, s2.pre, s2.post = sc, getattr(src, 'pre', ';'), getattr(src, 'post', ';')
                news.append(s2)
            work[k:k] = news
            continue
        if sub and seg and command_word(seg) < len(seg) and base(seg[command_word(seg)]) in EVAL_STRING:
            deny('VULYK git guard: PowerShell\'s Invoke-Expression (`iex`) runs a string the hook cannot read, and no '
                 'agent needs it. Run the command itself, or the owner runs it in his own terminal.')
        if sub:
            note_vars(seg, env, exported)
            hit = touches_state(seg, targets, here, cwd, env)
            if hit is None and takes_text(seg) and STATE_RE.search(cmd):
                hit = seg[command_word(seg)]
            if hit is not None:
                deny(state_msg % hit)
        if not seg:
            continue
        fed = fed_string(seg)                        # `bash -c <s>`: its commands are read next, in place
        if fed is not None:                          # a shell is a child: its cd moves only itself; eval runs here
            why = sub and judge_run(seg, env, tool == 'Bash')   # a command string xargs hands in
            if why:
                deny(why)
            own = seg[command_word(seg)] == 'eval' or base(seg[command_word(seg)]) in EVAL_STRING
            work[k:k] = inherit(parse(*fed), sc if own else sc + (next(SCOPES),))
            continue
        moved = cd_target(seg, here)
        if moved is not None:
            if sub and moved != UNKNOWN and in_state(moved):
                deny(state_msg % ' '.join(seg))
            eff = cd_effect(src) if isinstance(src, Seg) else 'yes'
            if eff == 'maybe' and moved != here:
                moved = UNKNOWN                      # it may or may not have moved: a place the hook cannot name
            if eff != 'no':
                here = heres[sc] = moved
            continue
        if sub:
            why = judge_run(seg, env, tool == 'Bash')
            if why:
                deny(why)
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
        seg = as_git(seg, env)
        call = git_call(seg)
        if not call:
            continue
        where, verb, args = call
        if verb == '!':                              # a `-c alias.<name>=!<command>`: a child shell's command
            work[k:k] = inherit(parse(args[0], False), sc + (next(SCOPES),))
            continue
        if sub and re.search(r'[$`]', verb):
            deny('VULYK git guard: the verb of `%s` cannot be read (it holds a variable or a substitution), and '
                 'a subagent may not run a git command that can throw away work. Spell the verb out, or leave '
                 'the tree as it is and report the step instead.' % ' '.join(seg))
        shown = ' '.join(['git', verb] + args)
        if forced_remote(verb, args):
            deny('VULYK git guard: `%s` - a forced tag or push overwrites what others hold, and no agent needs it. '
                 'A subagent reports the step under ## Findings and returns NEEDS_CONTEXT; the owner runs it in his '
                 'own terminal.' % shown)
        if sub and rewrites_history(verb, args):
            places = git_places(seg, exported)
            if here == UNKNOWN or (where and re.search(r'[$`%]', where)):
                spots = [None]                       # a folder the hook cannot read counts as held
            else:
                at = here if not where else os.path.join(here, native(where))
                spots = [] if any(kd == 'dir' for kd, _ in git_places(seg, {})) else [at]
                for kd, v in places:
                    if not v or re.search(r'[$`%]', v):
                        spots.append(None)
                        continue
                    p = os.path.join(at, native(v))
                    spots.append(os.path.dirname(p) if (kd == 'dir' and base(p) == '.git') else p)
            for spot in spots:
                if spot not in held:
                    held[spot] = driver_held(spot)
                if held[spot]:
                    deny('VULYK git guard: a subagent may not run `%s` while a docs/specs/*/DRIVER file holds the '
                         'repository it acts on - every verb that stages, makes a commit, or moves a branch or HEAD '
                         'is close-story\'s: it commits the story\'s paths, and a commit of your own hides edits '
                         'from its scope check. Leave the tree as it is.' % shown)
        blind = here == UNKNOWN
        base_ = cwd if blind else (here if not where else os.path.join(here, where))
        hit = classify(verb, args, base_)
        if not hit:
            continue
        paths, kinds, tree = hit
        if sub:
            deny('VULYK git guard: a subagent may not run `%s` - it can throw away uncommitted work that is '
                 'not yours (another story, the Queen, runtime data). Leave the tree as it is; if the story '
                 'truly needs this, report it under ## Findings and return NEEDS_CONTEXT.' % shown)
        if not tree:
            continue
        if paths[:1] == ['@worktree'] and not blind:
            base_, paths = os.path.join(here, paths[1]), []
            if not os.path.isdir(base_):
                continue
        if blind:
            paths = []                               # relative to a folder the hook cannot name
        timed_out = False
        try:
            entries = status(base_, paths, fake)
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
