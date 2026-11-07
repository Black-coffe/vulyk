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
( cd "$T" && PATH="$FB:$PATH" bash "$SRC/.claude/hooks/handoff.sh" status < /dev/null 2>/dev/null; echo "exit=$?" ) > "$T/exit1.out"
if grep -q '^root *:' "$T/exit1.out" && grep -q '^exit=0$' "$T/exit1.out"; then
  ok "handoff.sh status falls through a python3 that exits 1 to the next working Python"
else bad "handoff.sh stopped at a python3 that exits 1:"; sed 's/^/        /' "$T/exit1.out"; fi
printf '#!/bin/sh\nexit 1\n' > "$FB/python"; cp "$FB/python" "$FB/py"; chmod +x "$FB/python" "$FB/py"
( cd "$T" && PATH="$FB:$PATH" bash "$SRC/.claude/hooks/handoff.sh" status < /dev/null > /dev/null 2>&1; echo "exit=$?" ) > "$T/allbad.out"
expect_eq "handoff.sh exits 0 when every interpreter exits 1 (fail-open)" "exit=0" "$(tr -d '\r' < "$T/allbad.out")"

CHECKS="$(grep -c . "$LEDGER" || true)"
FAILED="$(grep -c . "$FAILS" || true)"
echo "handoff.test.sh: $CHECKS checks, $FAILED failed"
[ "$FAILED" -eq 0 ]
