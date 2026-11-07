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

CHECKS="$(grep -c . "$LEDGER" || true)"
FAILED="$(grep -c . "$FAILS" || true)"
echo "handoff.test.sh: $CHECKS checks, $FAILED failed"
[ "$FAILED" -eq 0 ]
