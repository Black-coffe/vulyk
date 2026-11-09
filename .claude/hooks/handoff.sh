#!/usr/bin/env bash
# Fail-open wrapper: run handoff.py under whatever Python 3 is on PATH.
# VULYK contract: a missing interpreter must never block the session.
# stdin (the hook JSON payload) passes straight through to the script.
# pwd -W yields a Windows-style path under Git Bash (native python.exe cannot
# open /tmp/... POSIX paths when MSYS path conversion is off); elsewhere it
# fails and plain pwd takes over.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && { pwd -W 2>/dev/null || pwd; })"
# A name that resolves is not yet a Python: the Windows Store alias answers every call with exit 49
# (9009 untruncated) and reads nothing. Each candidate runs the script itself, once (telemetry.sh's
# scan counts python starts through this hook, so no separate probe). handoff.py exits 0 on every path,
# errors included, so only 0 means Python ran it: an exit 1 is an interpreter that could not (a Python 2
# or a broken venv named python3, failing at import before reading stdin) and moves on to the next name,
# as does any other exit. stdin is not buffered: dump/status run from a shell, where a read would block.
# A preset $VULYK_PY (a path or a name) goes first, as in the defect hooks and lib.sh.
for PY in ${VULYK_PY:+"$VULYK_PY"} python3 python py; do
  command -v "$PY" >/dev/null 2>&1 || continue
  "$PY" "$DIR/handoff.py" "$@" && exit 0
done
exit 0
