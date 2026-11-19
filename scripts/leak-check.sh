#!/usr/bin/env bash
# VULYK leak check - the `check:` of docs/defects/host-internals-in-public-repo.md (contract K1 of
# docs/specs/audit-fixes-1113/plan.md).
#
#   Usage: bash scripts/leak-check.sh <file>
#
# VULYK is a public repository. Work in it is often triggered by something that happened in a host
# project (a hive), and the evidence - a session's cwd, a transcript slug, a folder name - names that
# project's insides: client folders, people, chats. None of it may reach this repository.
#
# Flags, in the given file:
#   - an absolute path that leaves the VULYK root, whatever the drive or folder layout: a drive path
#     (<letter>:/<segment> or <letter>:\<segment>), a Git Bash or WSL drive path (/<letter>/<segment>,
#     /mnt/<letter>/<segment>), a home path (/home/<user>/..., /Users/<user>/...);
#   - a share path on another machine (\\<host>\<share>\..., //<host>/<share>/...), never the `//` of a URL;
#   - a Claude temp-folder path (.../AppData/Local/Temp/claude..., /tmp/claude...);
#   - the transcript slug of a place inside another project (<D>--Projects-<name>-docs-..., -src-, -files-, ...);
#   - every hive root in the private registry ${VULYK_HIVES_FILE:-$HOME/.vulyk/hives} (one `<path>[ | ...]` per
#     line, `#` comments), in any of its shapes: <D>:/..., <D>:\..., /<d>/..., /mnt/<d>/... and its transcript
#     slug. With no registry one stderr note is printed and this rule matches nothing. A hit is reported without
#     the root;
#   - any term of the private lists, one per line, `#` comments, matched as a whole word, case-insensitive,
#     a Cyrillic name also with its case endings (Акакий: Акакия, Акакием): the hand-kept
#     ${VULYK_PRIVATE_TERMS:-$HOME/.vulyk/private-terms}, the harvested ${VULYK_PRIVATE_TERMS_AUTO:-
#     $HOME/.vulyk/private-terms.auto} (names from this machine's hives, written by the owner's local harvester),
#     and ${VULYK_EXTRA_TERMS} when set (the defect card's synthetic fixture names). The lists stay on the machine;
#     a hit is reported without the term.
#
# Passes (the pass list): a path under the VULYK root (this script's parent folder, in any of its shapes);
# `~/...`; a `<placeholder>` or elided (`...`) first segment (<drive>:/<hive>/docs, /home/<user>/..., C:/...); system locations
# (<drive>:/Program Files/, <drive>:/Program Files (x86)/, <drive>:/ProgramData/, <drive>:/Windows/, and every
# Unix path that is not a home, a drive or a temp folder: /usr/bin/env, /dev/null, /etc/...); a URL (`://`);
# a stand-in built from a variable ($T/acme-hive/...).
#
# Exit 1 naming each hit; exit 0 for a clean file or a missing one. Exit 2 when no python is on PATH.
set -u

f="${1:-}"
[ -n "$f" ] && [ -f "$f" ] || exit 0
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "$HERE/lib.sh"
vulyk_python || { echo "leak-check: needs python 3 (python3, python or py)" >&2; exit 2; }
PY="$VULYK_PY"
ROOT="$(cd "$HERE/.." && { pwd -W 2>/dev/null || pwd; })"
HIVES="${VULYK_HIVES_FILE:-$HOME/.vulyk/hives}"
[ -f "$HIVES" ] || { echo "leak-check: note: no hive registry at \${VULYK_HIVES_FILE:-~/.vulyk/hives}; the hive-root rule matches nothing" >&2; HIVES=""; }

PYTHONIOENCODING=utf-8 "$PY" - "$f" "$ROOT" "$HIVES" "${VULYK_PRIVATE_TERMS:-$HOME/.vulyk/private-terms}" "${VULYK_PRIVATE_TERMS_AUTO:-$HOME/.vulyk/private-terms.auto}" "${VULYK_EXTRA_TERMS:-}" <<'PY'
import os, re, sys

path, root, hives = sys.argv[1], sys.argv[2], sys.argv[3]
term_files = [t for t in sys.argv[4:] if t]
text = open(path, encoding="utf-8", errors="replace").read()

STOP = r"\s`'\"()<>|,;*?\[\]{}"          # characters that end a path in prose, code and markdown
SEG = r"[^\\/" + STOP + r"]+"             # one path segment; never starts with `<` (a placeholder)
SEP = r"[\\/]+"


def norm(p):
    # One comparable form: forward slashes, a drive as `x:`, lower case, no trailing slash.
    p = p.replace("\\", "/")
    p = re.sub(r"/{2,}", "/", p)
    m = re.match(r"^/(?:mnt/)?([A-Za-z])(/.*)?$", p)
    if m:
        p = m.group(1) + ":" + (m.group(2) or "/")
    return p.rstrip("/").lower()


ROOT = norm(root)


def under_root(p):
    n = norm(p)
    return n == ROOT or n.startswith(ROOT + "/")


SYSTEM = r"(?:Program Files(?: \(x86\))?|ProgramData|Windows)(?![\w.-])"
DRIVE = re.compile(r"(?<![A-Za-z0-9_$%{}<>~.-])[A-Za-z]:" + SEP + r"(?!" + SYSTEM + r")" + SEG + r"(?:" + SEP + SEG + r")*" + r"[\\/]?", re.I)
GITBASH = re.compile(r"(?<![\w.~/$:%{}<>-])/(?:mnt/)?[A-Za-z]/" + SEG + r"(?:/" + SEG + r")*/?")
HOME = re.compile(r"(?<![\w.~/$:%{}<>-])/(?:home|Users)/" + SEG + r"(?:/" + SEG + r")*/?")
TEMP = re.compile(r"(?:AppData" + SEP + r"Local" + SEP + r"Temp|(?<![\w.~/$:%{}<>-])/tmp)" + SEP + r"claude[^\\/" + STOP + r"]*", re.I)
# A share on another machine, either spelling: \\<host>\<share> or //<host>/<share> - never after a `:` (a URL),
# a word character or another slash; the host opens with a letter or a digit (a <placeholder> or $VAR passes).
UNC = re.compile(r"(?<![\w\\/:.$%{}<>~-])(?:\\\\[A-Za-z0-9][A-Za-z0-9._-]*\\|//[A-Za-z0-9][A-Za-z0-9._-]*/)" + SEG
                 + r"(?:" + SEP + SEG + r")*")
SLUG = re.compile(r"\b[A-Za-z]--Projects-(?!vulyk-)[A-Za-z0-9_-]+?-(?:docs|src|specs|files|raw|memory|claude)-[A-Za-z0-9_-]*", re.I)
CYR = re.compile(r"[А-Яа-яЁёІіЇїЄєҐґ]")
ENDINGS = "аяйьеиоуыюёіїєАЯЙЬЕИОУЫЮЁІЇЄ"


def root_rx(r):
    # A registered root in each shape a session writes it: drive path either way, Git Bash, WSL, the slug.
    n = norm(r)
    m = re.match(r"^([a-z]):(/.*)?$", n)
    if m:
        d, rest = m.group(1), (m.group(2) or "").strip("/")
        segs = [s for s in rest.split("/") if s]
        tail = "".join(SEP + re.escape(s) for s in segs)
        forms = [d + ":" + tail, r"/(?:mnt/)?" + d + tail]
        slug = re.escape(d) + "--" + "-".join(re.sub(r"[^A-Za-z0-9]", "-", s) for s in segs)
    else:
        segs = [s for s in n.split("/") if s]
        if not segs:
            return None
        forms = ["".join("/" + re.escape(s) for s in segs)]
        slug = "-" + "-".join(re.sub(r"[^A-Za-z0-9]", "-", s) for s in segs)
    alts = [f + r"(?![\w.-])" for f in forms] + [r"(?<![\w-])" + slug + r"(?![\w.])"]
    return re.compile(r"(?<![\w])(?:" + "|".join(alts) + ")", re.I)


roots = []
if hives and os.path.isfile(hives):
    for ln in open(hives, encoding="utf-8", errors="replace"):
        ln = ln.strip()
        if not ln or ln.startswith("#"):
            continue
        r = ln.split("|", 1)[0].strip()
        if r and not under_root(r):
            rx = root_rx(r)
            if rx:
                roots.append(rx)

hits = []
for n, line in enumerate(text.splitlines(), 1):
    for rx, why in ((DRIVE, "an absolute path outside the VULYK root"), (GITBASH, "a Git Bash or WSL path outside the VULYK root"),
                    (HOME, "a home path outside the VULYK root")):
        for m in rx.finditer(line):
            # `C:/...` is an elision, not a path: a first segment of dots alone passes like a <placeholder>.
            first = re.split(r"[\\/]+", re.sub(r"^(?:[A-Za-z]:|/mnt/[A-Za-z]|/[A-Za-z]|/home|/Users)[\\/]+", "", m.group(0)))[0]
            if re.fullmatch(r"[.…]+", first) or under_root(m.group(0)):
                continue
            hits.append((n, why, m.group(0)))
    for m in UNC.finditer(line):
        hits.append((n, "a share path on another machine", m.group(0)))
    for m in TEMP.finditer(line):
        hits.append((n, "a Claude temp-folder path", m.group(0)))
    for m in SLUG.finditer(line):
        hits.append((n, "a transcript slug inside another project", m.group(0)))
    if any(rx.search(line) for rx in roots):
        hits.append((n, "a registered hive root", "<from the private registry>"))

terms = set()
for tf in term_files:
    if os.path.isfile(tf):
        terms |= {t.strip() for t in open(tf, encoding="utf-8", errors="replace")
                  if t.strip() and not t.strip().startswith("#")}
alts = []
for t in sorted(terms, key=len, reverse=True):
    base = t.rstrip(ENDINGS) if CYR.search(t) else t
    if CYR.search(t) and len(base) >= 3:
        alts.append(re.escape(base) + r"\w{0,3}")
    else:
        alts.append(re.escape(t))
if alts:
    TERMS = re.compile(r"(?<![\w-])(?:" + "|".join(alts) + r")(?![\w-])", re.I)
    for n, line in enumerate(text.splitlines(), 1):
        if TERMS.search(line):
            hits.append((n, "a private term", "<from the private lists>"))

for n, why, what in hits:
    print("%s:%d: %s: %s" % (path, n, why, what))
sys.exit(1 if hits else 0)
PY
