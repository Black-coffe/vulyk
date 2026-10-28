#!/usr/bin/env bash
# VULYK prompt check - agent, command and template prose against the scripts and agents it names (no model).
#
#   Usage: bash scripts/prompt-check.sh [--touched <path>...]
#          bash scripts/prompt-check.sh --help
#
# Reads .claude/agents/*.md, .claude/commands/*.md and templates/*.md of the repo this script sits in. Checks agent
# frontmatter (name, model, maxTurns, tools; omitClaudeMd against docs/architecture.md), every backticked scripts/ path,
# `cycle.sh <verb>` and --flag (a flag counts only on a non-comment line of its script), every backticked agent name,
# and scripts/telemetry.sh AGENTS against the agent files (a hive's own agent is a warning).
# --touched: a finding involving none of the given paths (globs allowed) prints as a warning; close-story passes the
# story's ## Files. Exit: 0 clean (warnings allowed), 1 a blocking finding, 2 usage / no python.
set -u

PY=""
for p in python3 python; do
  if command -v "$p" >/dev/null 2>&1 && "$p" -c 'import sys; sys.exit(sys.version_info[0] != 3)' >/dev/null 2>&1; then
    PY="$p"; break
  fi
done
[ -n "$PY" ] || { echo "prompt-check: python 3 not found on PATH (python3 or python)" >&2; exit 2; }

PYTHONIOENCODING=utf-8 exec "$PY" "$(dirname "$0")/prompt-check.py" "$@"
