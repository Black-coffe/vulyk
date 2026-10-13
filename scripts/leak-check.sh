#!/usr/bin/env bash
# VULYK leak check - the `check:` of docs/defects/host-internals-in-public-repo.md.
#
#   Usage: bash scripts/leak-check.sh <file>
#
# VULYK is a public repository. Work in it is often triggered by something that happened in a host
# project (a hive), and the evidence - a session's cwd, a transcript slug, a folder name - names that
# project's insides: client folders, people, chats. None of it may reach this repository.
#
# Flags, in the given file:
#   - a path that goes INTO another project, past its root, in any of the shapes a session leaves
#     behind: <drive>:\Projects\<name>\<more>, <drive>:/Projects/<name>/<more>, /<drive>/Projects/<name>/<more>, and the
#     transcript slug <D>--Projects-<name>-docs-... (-src-, -files-, ...). A project's root alone (<drive>:/Projects/<name>) passes, and
#     so does VULYK's own tree.
#   - any term of the private list, one per line, case-insensitive (`#` comments):
#     ${VULYK_PRIVATE_TERMS:-$HOME/.vulyk/private-terms}. The list stays on the owner's machine.
#
# Exit 1 naming each hit; exit 0 for a clean file or a missing one. Exit 2 when no python is on PATH.
set -u

f="${1:-}"
[ -n "$f" ] && [ -f "$f" ] || exit 0
PY="$(command -v python3 || command -v python)" || { echo "leak-check: needs python3 or python" >&2; exit 2; }

"$PY" - "$f" "${VULYK_PRIVATE_TERMS:-$HOME/.vulyk/private-terms}" <<'PY'
import os, re, sys

path, terms_file = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8", errors="replace").read()

SEP = r"[\\/]+"
DEEP = re.compile(
    r"(?:\b[A-Za-z]:|(?<![\w.~])/[A-Za-z](?=/))" + SEP + r"Projects" + SEP +
    r"(?!vulyk(?:[\\/\s`'\")]|$))([^\\/\s`'\")]+)" + SEP + r"[^\s`'\")]+", re.I)
SLUG = re.compile(r"\b[A-Za-z]--Projects-(?!vulyk-)[A-Za-z0-9_-]+?-(?:docs|src|specs|files|raw|memory|claude)-[A-Za-z0-9_-]*", re.I)

hits = []
for n, line in enumerate(text.splitlines(), 1):
    for m in DEEP.finditer(line):
        hits.append((n, "a path inside another project", m.group(0)))
    for m in SLUG.finditer(line):
        hits.append((n, "a transcript slug inside another project", m.group(0)))

if os.path.isfile(terms_file):
    terms = [t.strip() for t in open(terms_file, encoding="utf-8", errors="replace")
             if t.strip() and not t.strip().startswith("#")]
    low = [(n, l.lower()) for n, l in enumerate(text.splitlines(), 1)]
    for t in terms:
        for n, l in low:
            if t.lower() in l:
                hits.append((n, "a private term", "<from the private list>"))

for n, why, what in hits:
    print("%s:%d: %s: %s" % (path, n, why, what))
sys.exit(1 if hits else 0)
PY
