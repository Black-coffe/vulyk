#!/usr/bin/env bash
# VULYK trace autopsy - the repo lines of a stack trace in a brief, with the last commits that touched each (no model).
#
#   Usage: bash scripts/trace-autopsy.sh <brief.md>
#          bash scripts/trace-autopsy.sh --help
#
# Reads the brief's `> ` lines only, resolves Python, Node, bash and plain `path:N` frames to tracked files (a
# deployment or Windows path matches by its tail), and writes `autopsy.md` beside the brief, at most 15 lines:
# HEAD, each frame's code line at HEAD and `git log -n 3 -L` under «last touched», then marks. A lead, not a verdict.
# No repo frame: one line on stdout, no file. Trace text never reaches a shell; only `git ls-files` paths reach git.
# Exit: 0 done (whatever the trace holds), 2 usage / no python / not in a git repo. Reports only, blocks nothing.
set -u

PY=""
for p in python3 python; do
  if command -v "$p" >/dev/null 2>&1 && "$p" -c 'import sys; sys.exit(sys.version_info[0] != 3)' >/dev/null 2>&1; then
    PY="$p"; break
  fi
done
[ -n "$PY" ] || { echo "trace-autopsy: python 3 not found on PATH (python3 or python)" >&2; exit 2; }

PYTHONIOENCODING=utf-8 exec "$PY" "$(dirname "$0")/trace-autopsy.py" "$@"
