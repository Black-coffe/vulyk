#!/usr/bin/env bash
# Fail-open wrapper: run handoff.py under whatever Python 3 is on PATH.
# VULYK contract: a missing interpreter must never block the session.
# stdin (the hook JSON payload) passes straight through to the script.
# pwd -W yields a Windows-style path under Git Bash (native python.exe cannot
# open /tmp/... POSIX paths when MSYS path conversion is off); elsewhere it
# fails and plain pwd takes over.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && { pwd -W 2>/dev/null || pwd; })"
for PY in python3 python py; do
  command -v "$PY" >/dev/null 2>&1 && exec "$PY" "$DIR/handoff.py" "$@"
done
exit 0
