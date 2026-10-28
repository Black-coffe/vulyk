#!/usr/bin/env bash
# Fail-open wrapper: run handoff.py under whatever Python 3 is on PATH.
# VULYK contract: a missing interpreter must never block the session.
# stdin (the hook JSON payload) passes straight through to the script.
# pwd -W yields a Windows-style path under Git Bash (native python.exe cannot
# open /tmp/... POSIX paths when MSYS path conversion is off); elsewhere it
# fails and plain pwd takes over.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && { pwd -W 2>/dev/null || pwd; })"
# A name that resolves is not yet a Python: the Windows Store alias answers every call with exit 49,
# so each candidate must run `-c ''` before it gets the payload.
for PY in python3 python py; do
  command -v "$PY" >/dev/null 2>&1 && "$PY" -c '' </dev/null >/dev/null 2>&1 && exec "$PY" "$DIR/handoff.py" "$@"
done
exit 0
