#!/usr/bin/env bash
# VULYK portability gate - the `check:` of docs/defects/shell-needs-gnu-or-bash4.md.
#
#   Usage: bash scripts/portability-check.sh              # the tree: git ls-files '*.sh', the constitution,
#                                                         # .claude/commands/*.md, .claude/agents/*.md
#          bash scripts/portability-check.sh <file>...    # those files only (the card's `check: ... <arg>`)
#
# A grep gate for shell that runs on Linux only: a stock macOS has /bin/bash 3.2 and BSD sed, date,
# stat, grep, readlink, find and xargs, no `timeout`, and Windows' python3 may be the Store stub.
# Rules (each hit prints `portability-check: <file>:<line>: <rule>: <text>`):
#   bash4        declare -A, ${v,,} ${v^^}, mapfile, readarray, |&, &>>
#   sed-i        a bare `sed -i` (sed_inplace, or an attached suffix: sed -i.bak)
#   sed-bre      \| \+ \? in a sed without -E / -r
#   grep-P stat-c readlink-f find-printf xargs-r     the GNU-only flag
#   date-d       date -d, --date, date -I with no same-line `||` fallback (lib.sh date_epoch / date_shift)
#   pct-n        %N in a date format
#   timeout      timeout / gtimeout in command position, outside scripts/lib.sh (run_capped)
#   python       python / python3 / py in command position, or `command -v` / which / type of them,
#                outside scripts/lib.sh (vulyk_python, bash scripts/py.sh)
#   array        "${a[@]}" / "${a[*]}" not inside ${a[@]+...}, in a file that sets -u (bash 3.2 calls an
#                empty array unbound)
# Not read: comments, heredoc bodies (Python, file contents), and in an .md file everything but
# inline code spans and shell fences. The one bypass is a same-line `# portable: <reason>`, counted
# in the summary line. No warn mode, no rule switch.
#
# Exit 0 clean (`portability-check: ok (<n> files, <m> allowed)`), 1 any hit (`<k> hit(s)`), 2 usage:
# a named file missing, nothing to scan (no args outside a git checkout, or an empty list), no python.
set -u
# shellcheck source=scripts/lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
vulyk_python || { echo "portability-check: needs python 3 (python3, python or py)" >&2; exit 2; }
case "${1:-}" in -h|--help) sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

PYTHONIOENCODING=utf-8 "$VULYK_PY" - "$@" <<'PY'
import os, re, subprocess, sys


def crash(kind, value, tb):  # a broken gate is a usage failure (2), never a hit (1)
    sys.__excepthook__(kind, value, tb)
    sys.stdout.flush()
    os._exit(2)


sys.excepthook = crash

args = sys.argv[1:]
if args:
    missing = [a for a in args if not os.path.isfile(a)]
    if missing:
        for a in missing:
            print("portability-check: no such file: %s" % a, file=sys.stderr)
        sys.exit(2)
    files = [(a, a) for a in args]
else:
    try:
        root = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True,
                              text=True, check=True).stdout.strip()
        listed = subprocess.run(["git", "-C", root, "ls-files", "*.sh"], capture_output=True,
                                text=True, check=True).stdout.splitlines()
    except (OSError, subprocess.CalledProcessError):
        print("portability-check: not in a git checkout - nothing to scan", file=sys.stderr)
        sys.exit(2)
    const = "CLAUDE.vulyk.md" if os.path.isfile(os.path.join(root, "CLAUDE.vulyk.md")) else "CLAUDE.md"
    extra = [const]
    for d in (".claude/commands", ".claude/agents"):
        p = os.path.join(root, d)
        if os.path.isdir(p):
            extra += sorted("%s/%s" % (d, f) for f in os.listdir(p) if f.endswith(".md"))
    rels = [r for r in listed + extra if not r.startswith("tests/fixtures/")]
    files = [(r, os.path.join(root, r)) for r in dict.fromkeys(rels) if os.path.isfile(os.path.join(root, r))]
if not files:
    print("portability-check: nothing to scan", file=sys.stderr)
    sys.exit(2)

NAME = r"[A-Za-z_][A-Za-z0-9_]*"
# command position: line or span start, after a separator or a keyword that runs its next word
CP = (r"(?:^|[;&|(`{]|\$\(|\b(?:then|do|else|if|elif|while|until|exec|time|sudo|command|xargs(?:\s+-\S+)*|env(?:\s+-\S+)*)(?=\s))"
      r"\s*(?:" + NAME + r"=\S*\s+)*")
END = r"(?=\s|$|[;)|&`])"
FLAGS = r"(?:-\S+\s+)*"
RULES = [  # read on the whole code text, quoted parts included: a sed script lives in quotes
    ("bash4", re.compile(r"\b(?:declare|local|typeset)\s+-[A-Za-z]*A\b|\$\{" + NAME + r"(?:\[[^\]]*\])?(?:,|\^)")),
    ("sed-i", re.compile(r"\bsed\s+" + FLAGS + r"(?:-[A-Za-z]*i(?=\s|$)|--in-place\b)")),
    ("grep-P", re.compile(r"\bgrep\s+" + FLAGS + r"(?:-[A-Za-z]*P|--perl-regexp\b)")),
    ("pct-n", re.compile(r"%[0-9]*N")),
    ("readlink-f", re.compile(r"\breadlink\s+" + FLAGS + r"-[A-Za-z]*f")),
    ("find-printf", re.compile(r"\bfind\b.*\s-f?printf\b")),
    ("xargs-r", re.compile(r"\bxargs\s+" + FLAGS + r"(?:-[A-Za-z0-9]*r\b|--no-run-if-empty\b)")),
]
WORDS = [  # judged only where the word <w> is code, not quoted text: "(python3 or python)" is a message
    ("bash4", re.compile(CP + r"(?P<w>mapfile|readarray)" + END + r"|(?P<o>\|&|&>>)")),
    ("timeout", re.compile(CP + r"(?P<w>g?timeout)" + END)),
    ("python", re.compile(CP + r"(?P<w>python3?|py)" + END
                          + r"|\b(?:command\s+-v|which|type(?:\s+-\w+)*|hash)\s+(?P<o>python3?|py)" + END)),
]
FALLBACK = [  # a GNU form after a same-line `||` fallback is not a hit
    ("date-d", re.compile(r"\bdate\s+(?:-\S+\s+)*?(?:-[A-Za-z]*d\b|--date\b|-I)")),
    ("stat-c", re.compile(r"\bstat\s+" + FLAGS + r"(?:-[A-Za-z]*c\b|--format\b|--printf\b)")),
]
SED = re.compile(r"\bsed(?:_inplace)?\b(.*)")
BRE = re.compile(r"(?<!\\)(?:\\\\)*\\[|+?]")   # an odd run of backslashes: \\| is a literal backslash, then a bar
ARRAY = re.compile(r'"\$\{(' + NAME + r')\[([@*])\]\}"')
NOUNSET = re.compile(r"(?:^|[;&]\s*)\s*set\s+(?:-[A-Za-z]*u|-o\s+nounset)", re.M)
HEREDOC = re.compile(r"(?<!<)<<(-?)\s*(['\"]?)(" + NAME + r")\2")
PORTABLE = re.compile(r"#\s*portable:\s*\S")


def scan(line, stack):
    """(code, comment, is_code) for one line; `stack` carries open quotes and $( ) across lines.
    is_code[i] is False inside single quotes and inside double quotes outside a $( ) or backticks.
    A `#` at the start or after whitespace, in plain code, starts the comment."""
    is_code, i, n = [], 0, len(line)
    while i < n:
        ch, top = line[i], stack[-1]
        if top == "'":
            is_code.append(False)
            if ch == "'":
                stack.pop()
        elif top == '"':
            if ch == "\\" and i + 1 < n:
                is_code += [False, False]; i += 2; continue
            if ch == '"':
                stack.pop(); is_code.append(False)
            elif line.startswith("$(", i):
                stack.append(["sub", 0]); is_code += [True, True]; i += 2; continue
            elif ch == "`":
                stack.append("bt"); is_code.append(True)
            else:
                is_code.append(False)
        else:
            if ch == "\\" and i + 1 < n:
                is_code += [True, True]; i += 2; continue
            if ch == "#" and len(stack) == 1 and (i == 0 or line[i - 1].isspace()):
                return line[:i], line[i:], is_code
            is_code.append(ch not in "'\"")
            if ch in "'\"":
                stack.append(ch)
            elif top == "bt" and ch == "`":
                stack.pop()
            elif ch == "`":
                stack.append("bt")
            elif isinstance(top, list) and ch == "(":
                top[1] += 1
            elif isinstance(top, list) and ch == ")":
                if top[1]:
                    top[1] -= 1
                else:
                    stack.pop()
        i += 1
    return line, "", is_code


def sed_bre(code):
    for m in SED.finditer(code):
        rest = re.split(r"\s\|\s|;\s", m.group(1), maxsplit=1)[0]
        flags = [w for w in rest.split() if re.match(r"-[A-Za-z]+$", w)]
        if any(re.search(r"[Er]", w) for w in flags) or "--regexp-extended" in rest:
            continue
        if BRE.search(rest):
            return True
    return False


def hits_of(code, is_code, path, nounset):
    out = [r for r, rx in RULES if rx.search(code)]
    lib = path.replace("\\", "/").endswith("scripts/lib.sh")
    for r, rx in WORDS:
        if lib and r != "bash4":
            continue
        for m in rx.finditer(code):
            at = m.start("w") if m.group("w") else m.start("o")
            if is_code[at]:
                out.append(r)
                break
    if sed_bre(code):
        out.append("sed-bre")
    if "||" not in code:
        out += [r for r, rx in FALLBACK if rx.search(code)]
    if nounset:
        for m in ARRAY.finditer(code):
            if not code[:m.start()].endswith("${%s[%s]+" % (m.group(1), m.group(2))):
                out.append("array")
                break
    return out


def pieces(path, lines):
    """(line number, text, fresh) to judge: every line of a shell file, or an .md file's shell fences and
    its inline code spans of two words or more (a one-word span names a thing, it runs nothing).
    fresh: start a new quote state (each span, each fence)."""
    if not path.lower().endswith(".md"):
        for n, ln in enumerate(lines, 1):
            yield n, ln, n == 1
        return
    fence = None
    for n, ln in enumerate(lines, 1):
        m = re.match(r"\s*(```+|~~~+)\s*([\w-]*)", ln)
        if fence is None and m:
            fence = [m.group(1), m.group(2).lower() in ("", "sh", "bash", "shell", "console", "zsh"), True]
            continue
        if fence is not None:
            if ln.strip().startswith(fence[0]):
                fence = None
            elif fence[1]:
                yield n, ln, fence[2]
                fence[2] = False
            continue
        for s in re.finditer(r"(`+)(.+?)\1", ln):
            span = s.group(2).strip()
            if len(span.split()) > 1:
                yield n, span, True


total, allowed, found = 0, 0, []
for shown, path in files:
    total += 1
    try:
        text = open(path, encoding="utf-8", errors="replace").read().replace("\r\n", "\n")
    except OSError as e:
        print("portability-check: cannot read %s: %s" % (shown, e), file=sys.stderr)
        sys.exit(2)
    nounset = bool(NOUNSET.search(text))
    pending, stack = [], ["code"]   # heredoc terminators still to come: (word, strip-tabs); quote state
    for n, ln, fresh in pieces(path, text.split("\n")):
        if fresh:
            pending, stack = [], ["code"]
        if pending:
            word, dash = pending[0]
            if (ln.lstrip("\t") if dash else ln) == word:
                pending.pop(0)
            continue
        code, comment, is_code = scan(ln, stack)
        for m in HEREDOC.finditer(code):
            if is_code[m.start()]:
                pending.append((m.group(3), m.group(1) == "-"))
        rules = hits_of(code, is_code, path, nounset)
        if not rules:
            continue
        if PORTABLE.match(comment.strip()):
            allowed += 1
            continue
        for r in dict.fromkeys(rules):
            found.append("portability-check: %s:%d: %s: %s" % (shown, n, r, ln.strip()))


for f in found:
    print(f)
if found:
    print("portability-check: %d hit(s)" % len(found))
    sys.exit(1)
print("portability-check: ok (%d files, %d allowed)" % (total, allowed))
PY
