#!/usr/bin/env bash
# The session-handoff hook (.claude/hooks/handoff.sh -> handoff.py) and its wiring in .claude/settings.json.
# No model calls, no network.
#
#   Usage: bash tests/handoff.test.sh            # from anywhere; SRC is the repo root
#
# The hook-mode cases live in tests/handoff-hooks.test.py (real payload bytes on stdin, one temp HOME and
# project per case); this file runs them, then the wrapper's interpreter fallback and the settings wiring.
# The context-window matrix has a suite of its own: tests/handoff-window.test.py.
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
# shellcheck source=scripts/lib.sh
. "$SRC/scripts/lib.sh"
vulyk_python || { echo "handoff.test.sh: needs python 3 (python3, python or py)"; exit 1; }
PYBIN="$(command -v "$VULYK_PY")"
LEDGER="$T/checks"; FAILS="$T/fails"; : > "$LEDGER"; : > "$FAILS"
ok()  { printf 'x\n' >> "$LEDGER"; echo "  ok    $1"; }
bad() { printf 'x\n' >> "$LEDGER"; printf 'x\n' >> "$FAILS"; echo "::error::$1"; }
expect_eq() { # expect_eq <label> <expected> <actual>
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 - expected '$2', got '$3'"; fi
}
W() { cygpath -w "$1" 2>/dev/null || printf '%s' "$1"; }   # native python.exe cannot open /tmp/... paths

echo "--- handoff.py hook modes (tests/handoff-hooks.test.py)"
if PYTHONIOENCODING=utf-8 "$PYBIN" "$(W "$SRC/tests/handoff-hooks.test.py")" "$(W "$SRC/.claude/hooks/handoff.py")" > "$T/hooks.out" 2>&1; then
  ok "handoff-hooks.test.py: $(tail -1 "$T/hooks.out")"
else
  bad "handoff-hooks.test.py failed:"; sed 's/^/        /' "$T/hooks.out"
fi

echo "--- handoff.sh: an interpreter that exits 1 is passed over (P10-10)"
# python3 is a Python that cannot run the script (a Python 2, a broken venv: exit 1 at import);
# the next name is a working one. The wrapper used to take that exit 1 as "ran" and stop there.
FB="$T/py-exit1"; mkdir -p "$FB"
printf '#!/bin/sh\necho "ImportError: cannot import name timezone" >&2\nexit 1\n' > "$FB/python3"
printf '#!/bin/sh\nexec "%s" "$@"\n' "$PYBIN" > "$FB/python"
chmod +x "$FB/python3" "$FB/python"
( cd "$T" && VULYK_PY= PATH="$FB:$PATH" bash "$SRC/.claude/hooks/handoff.sh" status < /dev/null 2>/dev/null; echo "exit=$?" ) > "$T/exit1.out"
if grep -q '^root *:' "$T/exit1.out" && grep -q '^exit=0$' "$T/exit1.out"; then
  ok "handoff.sh status falls through a python3 that exits 1 to the next working Python"
else bad "handoff.sh stopped at a python3 that exits 1:"; sed 's/^/        /' "$T/exit1.out"; fi
printf '#!/bin/sh\nexit 1\n' > "$FB/python"; cp "$FB/python" "$FB/py"; chmod +x "$FB/python" "$FB/py"
( cd "$T" && VULYK_PY= PATH="$FB:$PATH" bash "$SRC/.claude/hooks/handoff.sh" status < /dev/null > /dev/null 2>&1; echo "exit=$?" ) > "$T/allbad.out"
expect_eq "handoff.sh exits 0 when every interpreter exits 1 (fail-open)" "exit=0" "$(tr -d '\r' < "$T/allbad.out")"

echo "--- handoff.sh: a preset \$VULYK_PY goes first, as in the defect hooks"
# Every python name on PATH is shadowed by a stub that logs and exits 1, so a run that reaches PATH shows up.
VP="$T/vulyk-py"; mkdir -p "$VP/bin"
for n in python3 python py; do printf '#!/bin/sh\necho %s >> "%s/path-hits"\nexit 1\n' "$n" "$VP" > "$VP/bin/$n"; done
printf '#!/bin/sh\necho x >> "%s/count"\nexec "%s" "$@"\n' "$VP" "$PYBIN" > "$VP/counting-py"
chmod +x "$VP/bin/"* "$VP/counting-py"
( cd "$T" && VULYK_PY="$VP/counting-py" PATH="$VP/bin:$PATH" bash "$SRC/.claude/hooks/handoff.sh" status < /dev/null 2>/dev/null
  echo "exit=$?" ) > "$T/vp.out"
if grep -q '^root *:' "$T/vp.out" && [ "$(grep -c . "$VP/count" 2>/dev/null)" = 1 ] && [ ! -s "$VP/path-hits" ]; then
  ok "handoff.sh status runs through \$VULYK_PY once and never reaches a python on PATH"
else bad "handoff.sh did not run through \$VULYK_PY (count=$(grep -c . "$VP/count" 2>/dev/null), PATH hits: $(tr '\n' ' ' < "$VP/path-hits" 2>/dev/null)):"
  sed 's/^/        /' "$T/vp.out"; fi

echo "--- settings.json: SessionEnd hooks carry an explicit timeout (P10-03)"
# Without one a SessionEnd hook gets Claude Code's short exit budget (1.5 s); the dump takes 1.4-7 s.
PYTHONIOENCODING=utf-8 "$PYBIN" - "$(W "$SRC/.claude/settings.json")" > "$T/se.out" 2>&1 <<'PY'
import json, sys
hooks = [h for g in json.load(open(sys.argv[1], encoding="utf-8"))["hooks"].get("SessionEnd", [])
         for h in g.get("hooks", [])]
for h in hooks:
    t = h.get("timeout")
    print("%s timeout=%s" % (h["command"].rsplit("/", 1)[-1], t if type(t) is int and t >= 10 else "MISSING"))
PY
grep -q 'handoff.sh sessionend timeout=' "$T/se.out" && ! grep -q MISSING "$T/se.out" \
  && ok "every SessionEnd hook, handoff.sh sessionend among them, has a timeout >= 10 s" \
  || { bad "a SessionEnd hook has no timeout:"; sed 's/^/        /' "$T/se.out"; }

CHECKS="$(grep -c . "$LEDGER" || true)"
FAILED="$(grep -c . "$FAILS" || true)"
echo "handoff.test.sh: $CHECKS checks, $FAILED failed"
[ "$FAILED" -eq 0 ]
