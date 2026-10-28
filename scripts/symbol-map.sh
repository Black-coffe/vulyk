#!/usr/bin/env bash
# VULYK symbol map - the repo paths linked to a file that lie outside the story's scope (no model, no cache).
#
#   Usage: bash scripts/symbol-map.sh [--exact] [--story <story.md>] [--scope <path>]... <file>...
#          bash scripts/symbol-map.sh --help
#
# One block per input: tests, importers, imported, guard tests, path mentions; each line `exact` or `textual`.
# --exact keeps the `exact` lines and folds each section's textual ones into a count (the planner hand-off).
# Python (ast) and bash (source/., a run .py) get importers/imported; other files get the language-independent sections
# and a `! imports not parsed` line. The whole stdout stays at or under 1536 bytes. Reports only, blocks nothing.
# Exit: 0 done, 1 an input is missing (every input is still reported), 2 usage / no python / not in a git repo.
set -u

# shellcheck source=scripts/lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
vulyk_python || { echo "symbol-map: python 3 not found on PATH (python3, python or py)" >&2; exit 2; }
PY="$VULYK_PY"

PYTHONIOENCODING=utf-8 exec "$PY" "$(dirname "$0")/symbol-map.py" "$@"
