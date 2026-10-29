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
# scan counts python starts through this hook, so no separate probe): handoff.py exits 0, or 1 on an
# uncaught error, so only 0 or 1 means Python ran it (the defect-intake.sh form); any other exit moves
# on to the next name. stdin is not buffered: dump/status run from a shell, where a read would block.
for PY in python3 python py; do
  command -v "$PY" >/dev/null 2>&1 || continue
  "$PY" "$DIR/handoff.py" "$@"
  case $? in 0) exit 0 ;; 1) exit 1 ;; esac
done
exit 0
